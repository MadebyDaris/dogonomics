package dogohub

import (
	"bufio"
	"bytes"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"

	"github.com/MadebyDaris/dogonomics/internal/cache"
	"github.com/MadebyDaris/dogonomics/internal/database"
	"github.com/gdamore/tcell/v2"
	"github.com/gin-gonic/gin"
	"github.com/rivo/tview"
)

const asciiArt = `[skyblue]██████╗  ██████╗  ██████╗  ██████╗ ██╗  ██╗██╗   ██╗██████╗[-]
[deepskyblue]██╔══██╗██╔═══██╗██╔════╝ ██╔═══██╗██║  ██║██║   ██║██╔══██╗[-]
[turquoise]██║  ██║██║   ██║██║  ███╗██║   ██║███████║██║   ██║██████╔╝[-]
[aquamarine]██║  ██║██║   ██║██║   ██║██║   ██║██╔══██║██║   ██║██╔══██╗[-]
[lightgreen]██████╔╝╚██████╔╝╚██████╔╝╚██████╔╝██║  ██║╚██████╔╝██████╔╝[-]
[green]╚═════╝  ╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═════╝[-]
[gold]Dogonomics Command Center • Intelligent Ops Terminal[-]`

type taskState struct {
	id      int
	name    string
	kind    string
	started time.Time
	status  string
	errMsg  string
}

type Hub struct {
	app        *tview.Application
	pages      *tview.Pages
	tabBar     *tview.TextView
	mainView   *tview.TextView
	tasksView  *tview.TextView
	diagView   *tview.TextView
	configView *tview.TextView
	menuList   *tview.List
	statusView *tview.TextView
	cmdInput   *tview.InputField
	logWriter  io.Writer

	serverFunc func()
	serverMu   sync.Mutex
	serverOn   bool
	baseURL    string

	historyMu    sync.Mutex
	history      []string
	historyIndex int
	historyPath  string

	tasksMu     sync.Mutex
	tasks       map[int]*taskState
	taskCounter int

	confirmMu       sync.Mutex
	pendingConfirm  string
	pendingExpireAt time.Time
}

// Run initializes and starts the TUI. It accepts a serverFunc that represents the main backend startup.
func Run(serverFunc func()) {
	cwd, _ := os.Getwd()
	h := &Hub{
		app:          tview.NewApplication(),
		pages:        tview.NewPages(),
		tabBar:       tview.NewTextView().SetDynamicColors(true),
		mainView:     tview.NewTextView().SetDynamicColors(true).SetScrollable(true),
		tasksView:    tview.NewTextView().SetDynamicColors(true).SetScrollable(true),
		diagView:     tview.NewTextView().SetDynamicColors(true).SetScrollable(true),
		configView:   tview.NewTextView().SetDynamicColors(true).SetScrollable(true),
		menuList:     tview.NewList().ShowSecondaryText(true),
		statusView:   tview.NewTextView().SetDynamicColors(true).SetTextAlign(tview.AlignLeft),
		cmdInput:     tview.NewInputField(),
		serverFunc:   serverFunc,
		baseURL:      defaultBaseURL(),
		historyIndex: -1,
		historyPath:  filepath.Join(cwd, ".dogohub_history"),
		tasks:        make(map[int]*taskState),
	}

	h.loadHistory()
	h.setupWidgets()
	h.setupLogPipe()
	h.setupMenu()
	h.setupPages()
	h.setupInput()
	h.renderConfig()
	h.renderTasks()
	h.renderDiagnosticsHeader()

	header := tview.NewTextView().
		SetText(asciiArt).
		SetDynamicColors(true).
		SetTextAlign(tview.AlignCenter).
		SetTextColor(tcell.ColorGoldenrod)
	header.SetBorder(true).SetTitle(" DogoHub ")

	rightPane := tview.NewFlex().
		SetDirection(tview.FlexRow).
		AddItem(h.statusView, 3, 0, false).
		AddItem(h.tabBar, 1, 0, false).
		AddItem(h.pages, 0, 1, false)

	grid := tview.NewGrid().
		SetRows(13, 0, 3).
		SetColumns(36, 0).
		SetBorders(false).
		AddItem(header, 0, 0, 1, 2, 0, 0, false).
		AddItem(h.menuList, 1, 0, 1, 1, 0, 0, true).
		AddItem(rightPane, 1, 1, 1, 1, 0, 0, false).
		AddItem(h.cmdInput, 2, 1, 1, 1, 0, 0, false)

	// Set initial content directly (no queued updates before app loop starts).
	h.statusView.SetText("[green]Backend:[-] Ready   [yellow]Tasks:[-] 0")
	fmt.Fprintln(h.mainView, h.introText())
	fmt.Fprintln(h.mainView, "[lightcyan]Tip:[-] Type 'help' to view commands. Press ':' to focus input. Use Ctrl+1..4 to switch tabs.")
	h.switchTab("logs")

	if err := h.app.SetRoot(grid, true).SetFocus(h.menuList).Run(); err != nil {
		panic(err)
	}
}

func (h *Hub) setupWidgets() {
	h.mainView.SetBorder(true).SetTitle(" Logs ")
	h.tasksView.SetBorder(true).SetTitle(" Tasks ")
	h.diagView.SetBorder(true).SetTitle(" Diagnostics ")
	h.configView.SetBorder(true).SetTitle(" Config ")
	h.menuList.SetBorder(true).SetTitle(" Commands ")
	h.statusView.SetBorder(true).SetTitle(" Runtime ")
	h.tabBar.SetBorder(true).SetTitle(" Views ")
	h.cmdInput.SetBorder(true).SetTitle(" Command Console ")
	h.cmdInput.SetLabel("dogo> ")
	h.cmdInput.SetFieldBackgroundColor(tcell.ColorBlack)
	h.mainView.SetTextColor(tcell.ColorLightCyan)
	h.tasksView.SetTextColor(tcell.ColorLightYellow)
	h.diagView.SetTextColor(tcell.ColorLightGreen)
	h.configView.SetTextColor(tcell.ColorLightBlue)
}

func (h *Hub) introText() string {
	user := os.Getenv("USER")
	if strings.TrimSpace(user) == "" {
		user = "Operator"
	}
	return fmt.Sprintf("[deepskyblue]Welcome, %s.[-]\n[gold]This is your DogoHub command center.[-]\n[white]You can start services, run diagnostics, execute scripts, and send API requests from one console.[-]", user)
}

func (h *Hub) setupPages() {
	h.pages.AddPage("logs", h.mainView, true, true)
	h.pages.AddPage("tasks", h.tasksView, true, false)
	h.pages.AddPage("diagnostics", h.diagView, true, false)
	h.pages.AddPage("config", h.configView, true, false)
}

func (h *Hub) setupInput() {
	h.cmdInput.SetDoneFunc(func(key tcell.Key) {
		if key != tcell.KeyEnter {
			return
		}
		cmd := strings.TrimSpace(h.cmdInput.GetText())
		h.cmdInput.SetText("")
		h.historyIndex = -1
		if cmd == "" {
			return
		}
		h.addHistory(cmd)
		h.printLog("$ " + cmd)
		h.handleCommand(cmd)
	})

	h.cmdInput.SetInputCapture(func(event *tcell.EventKey) *tcell.EventKey {
		switch event.Key() {
		case tcell.KeyUp:
			h.historyPrev()
			return nil
		case tcell.KeyDown:
			h.historyNext()
			return nil
		}
		return event
	})

	h.app.SetInputCapture(func(event *tcell.EventKey) *tcell.EventKey {
		switch event.Key() {
		case tcell.KeyRune:
			if event.Modifiers()&tcell.ModCtrl != 0 {
				switch event.Rune() {
				case '1':
					h.switchTab("logs")
					return nil
				case '2':
					h.switchTab("tasks")
					return nil
				case '3':
					h.switchTab("diagnostics")
					return nil
				case '4':
					h.switchTab("config")
					return nil
				}
			}
			if event.Rune() == ':' {
				h.app.SetFocus(h.cmdInput)
				return nil
			}
		case tcell.KeyESC:
			h.app.SetFocus(h.menuList)
			return nil
		}
		return event
	})
}

func (h *Hub) setupLogPipe() {
	r, w, err := os.Pipe()
	if err == nil {
		h.logWriter = w
		log.SetOutput(w)
		gin.DefaultWriter = w
		gin.DefaultErrorWriter = w
		go h.streamOutput(r)
	} else {
		h.logWriter = os.Stderr
	}

	h.mainView.SetChangedFunc(func() {
		h.app.Draw()
		h.mainView.ScrollToEnd()
	})
}

func (h *Hub) setupMenu() {
	h.menuList.AddItem("Start Server (Standard)", "Launch API server with default mode", '1', func() {
		h.startServer("Running (Standard)", "Starting standard server...")
	})
	h.menuList.AddItem("Start Server (MCP)", "Enable MCP gateway and launch server", '2', func() {
		os.Setenv("ENABLE_MCP_GATEWAY", "true")
		h.startServer("Running (MCP)", "Starting server with MCP enabled...")
	})
	h.menuList.AddItem("System Health Diagnostics", "Check database and redis connectivity", '3', func() {
		h.runHealthDiagnostics()
	})
	h.menuList.AddItem("Docker Compose Up", "Run infra stack from scripts", '4', func() {
		h.executeScript("tools/scripts/linux/docker-compose-up.sh", "tools\\scripts\\windows\\docker-compose-up.bat")
	})
	h.menuList.AddItem("Build Backend (ONNX)", "Build ONNX-enabled backend binary", '5', func() {
		h.executeScript("tools/scripts/linux/build-onnx.sh", "tools\\scripts\\windows\\build-onnx.bat")
	})
	h.menuList.AddItem("Switch To Logs", "Show runtime and command output", 'l', func() {
		h.switchTab("logs")
	})
	h.menuList.AddItem("Switch To Tasks", "Show running async tasks", 't', func() {
		h.switchTab("tasks")
	})
	h.menuList.AddItem("Switch To Diagnostics", "Show diagnostics summary and checks", 'd', func() {
		h.switchTab("diagnostics")
	})
	h.menuList.AddItem("Switch To Config", "Show host, history, and runtime settings", 'g', func() {
		h.switchTab("config")
	})
	h.menuList.AddItem("Focus Command Console", "Move keyboard focus to command input", ':', func() {
		h.app.SetFocus(h.cmdInput)
	})
	h.menuList.AddItem("Clear Output", "Clear log panel only", 'c', func() {
		h.mainView.SetText("")
	})
	h.menuList.AddItem("Quit", "Exit DogoHub", 'q', func() {
		h.app.Stop()
	})
}

func (h *Hub) streamOutput(r io.Reader) {
	w := tview.ANSIWriter(h.mainView)
	_, _ = io.Copy(w, r)
}

func (h *Hub) printLog(msg string) {
	go h.app.QueueUpdateDraw(func() {
		fmt.Fprintf(h.mainView, "[yellow]%s[-]\n", msg)
		h.mainView.ScrollToEnd()
	})
}

func (h *Hub) printDiag(msg string) {
	go h.app.QueueUpdateDraw(func() {
		fmt.Fprintf(h.diagView, "%s\n", msg)
		h.diagView.ScrollToEnd()
	})
}

func (h *Hub) updateStatus(status string) {
	taskCount := h.taskCount()
	go h.app.QueueUpdateDraw(func() {
		h.statusView.SetText(fmt.Sprintf("[green]Backend:[-] %s   [yellow]Tasks:[-] %d   [blue]Host:[-] %s", status, taskCount, h.baseURL))
	})
}

func (h *Hub) switchTab(name string) {
	go h.app.QueueUpdateDraw(func() {
		h.pages.SwitchToPage(name)
		h.tabBar.SetText(h.renderTabBar(name))
	})
}

func (h *Hub) renderTabBar(active string) string {
	tabs := []string{"logs", "tasks", "diagnostics", "config"}
	labels := make([]string, 0, len(tabs))
	for idx, t := range tabs {
		label := strings.Title(t)
		if t == active {
			labels = append(labels, fmt.Sprintf("[black:green] %d:%s [-:-:-]", idx+1, label))
		} else {
			labels = append(labels, fmt.Sprintf("[white] %d:%s [-]", idx+1, label))
		}
	}
	return strings.Join(labels, "  ")
}

func (h *Hub) renderDiagnosticsHeader() {
	h.printDiag("DogoHub diagnostics initialized")
	h.printDiag("Use 'health' to run connectivity checks")
}

func (h *Hub) renderConfig() {
	h.historyMu.Lock()
	historyCount := len(h.history)
	h.historyMu.Unlock()

	h.serverMu.Lock()
	running := h.serverOn
	h.serverMu.Unlock()

	status := "Stopped"
	if running {
		status = "Running"
	}

	go h.app.QueueUpdateDraw(func() {
		h.configView.SetText("")
		fmt.Fprintf(h.configView, "Base URL: %s\n", h.baseURL)
		fmt.Fprintf(h.configView, "Server: %s\n", status)
		fmt.Fprintf(h.configView, "History file: %s\n", h.historyPath)
		fmt.Fprintf(h.configView, "History entries: %d\n", historyCount)
		fmt.Fprintf(h.configView, "Destructive ops enabled: %t\n", strings.EqualFold(os.Getenv("DOGOHUB_ENABLE_DESTRUCTIVE"), "true"))
	})
}

func (h *Hub) startTask(name string, kind string) int {
	h.tasksMu.Lock()
	h.taskCounter++
	t := &taskState{id: h.taskCounter, name: name, kind: kind, started: time.Now(), status: "running"}
	h.tasks[t.id] = t
	h.tasksMu.Unlock()

	h.renderTasks()
	h.updateStatus("Running")
	return t.id
}

func (h *Hub) finishTask(id int, err error) {
	h.tasksMu.Lock()
	if t, ok := h.tasks[id]; ok {
		if err != nil {
			t.status = "failed"
			t.errMsg = err.Error()
		} else {
			t.status = "done"
		}
	}
	h.tasksMu.Unlock()
	h.renderTasks()
}

func (h *Hub) taskCount() int {
	h.tasksMu.Lock()
	defer h.tasksMu.Unlock()
	count := 0
	for _, t := range h.tasks {
		if t.status == "running" {
			count++
		}
	}
	return count
}

func (h *Hub) renderTasks() {
	h.tasksMu.Lock()
	snapshot := make([]taskState, 0, len(h.tasks))
	for _, t := range h.tasks {
		snapshot = append(snapshot, *t)
	}
	h.tasksMu.Unlock()

	go h.app.QueueUpdateDraw(func() {
		h.tasksView.SetText("")
		if len(snapshot) == 0 {
			fmt.Fprintln(h.tasksView, "No tasks yet")
			return
		}
		for _, t := range snapshot {
			elapsed := time.Since(t.started).Round(time.Second)
			if t.errMsg != "" {
				fmt.Fprintf(h.tasksView, "#%d [%s] %s - %s (%s) err=%s\n", t.id, t.kind, t.name, t.status, elapsed, t.errMsg)
			} else {
				fmt.Fprintf(h.tasksView, "#%d [%s] %s - %s (%s)\n", t.id, t.kind, t.name, t.status, elapsed)
			}
		}
		h.tasksView.ScrollToEnd()
	})
}

func (h *Hub) addHistory(cmd string) {
	cmd = strings.TrimSpace(cmd)
	if cmd == "" {
		return
	}
	h.historyMu.Lock()
	h.history = append(h.history, cmd)
	if len(h.history) > 500 {
		h.history = h.history[len(h.history)-500:]
	}
	h.historyMu.Unlock()
	h.saveHistoryLine(cmd)
	h.renderConfig()
}

func (h *Hub) historyPrev() {
	h.historyMu.Lock()
	defer h.historyMu.Unlock()
	if len(h.history) == 0 {
		return
	}
	if h.historyIndex == -1 {
		h.historyIndex = len(h.history) - 1
	} else if h.historyIndex > 0 {
		h.historyIndex--
	}
	h.cmdInput.SetText(h.history[h.historyIndex])
}

func (h *Hub) historyNext() {
	h.historyMu.Lock()
	defer h.historyMu.Unlock()
	if len(h.history) == 0 {
		return
	}
	if h.historyIndex == -1 {
		return
	}
	if h.historyIndex < len(h.history)-1 {
		h.historyIndex++
		h.cmdInput.SetText(h.history[h.historyIndex])
		return
	}
	h.historyIndex = -1
	h.cmdInput.SetText("")
}

func (h *Hub) loadHistory() {
	f, err := os.Open(h.historyPath)
	if err != nil {
		return
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	loaded := make([]string, 0, 500)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		loaded = append(loaded, line)
		if len(loaded) > 500 {
			loaded = loaded[len(loaded)-500:]
		}
	}
	if len(loaded) > 0 {
		h.historyMu.Lock()
		h.history = loaded
		h.historyMu.Unlock()
	}
}

func (h *Hub) saveHistoryLine(cmd string) {
	f, err := os.OpenFile(h.historyPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	defer f.Close()
	_, _ = f.WriteString(cmd + "\n")
}

func (h *Hub) handleCommand(input string) {
	parts := strings.Fields(input)
	if len(parts) == 0 {
		return
	}

	cmd := strings.ToLower(parts[0])
	switch cmd {
	case "help":
		h.printHelp()
	case "start":
		if len(parts) > 1 && strings.EqualFold(parts[1], "mcp") {
			os.Setenv("ENABLE_MCP_GATEWAY", "true")
			h.startServer("Running (MCP)", "Starting server with MCP enabled...")
			return
		}
		h.startServer("Running (Standard)", "Starting standard server...")
	case "health":
		h.runHealthDiagnostics()
	case "status":
		h.serverMu.Lock()
		running := h.serverOn
		h.serverMu.Unlock()
		mode := "Stopped"
		if running {
			mode = "Running"
		}
		h.printLog(fmt.Sprintf("Server: %s | Base URL: %s | Active tasks: %d", mode, h.baseURL, h.taskCount()))
		h.renderConfig()
	case "host":
		if len(parts) == 1 {
			h.printLog("Current base URL: " + h.baseURL)
			return
		}
		h.baseURL = strings.TrimRight(parts[1], "/")
		h.printLog("Base URL set to: " + h.baseURL)
		h.renderConfig()
	case "request":
		h.handleRequestCommand(input)
	case "get":
		if len(parts) < 2 {
			h.printLog("Usage: get PATH")
			return
		}
		h.performRequest("GET", parts[1], "")
	case "post":
		if len(parts) < 3 {
			h.printLog("Usage: post PATH JSON_BODY")
			return
		}
		body := strings.TrimSpace(strings.TrimPrefix(input, parts[0]+" "+parts[1]))
		h.performRequest("POST", parts[1], body)
	case "script":
		if len(parts) < 2 {
			h.printLog("Usage: script {up|down|build|run|build-onnx|run-onnx}")
			return
		}
		h.runScriptByName(strings.ToLower(parts[1]))
	case "shell":
		if len(parts) < 2 {
			h.printLog("Usage: shell COMMAND")
			return
		}
		shellCmd := strings.TrimSpace(strings.TrimPrefix(input, parts[0]))
		h.executeShell(shellCmd)
	case "confirm":
		h.confirmCommand(parts)
	case "db-reset":
		h.guardDestructive("db-reset", "Database reset is destructive and irreversible.")
	case "redis-flush":
		h.guardDestructive("redis-flush", "Redis flush clears all cached data.")
	case "quote", "ticker", "profile", "chart", "sentiment", "sentiment-bert":
		h.handleSymbolShortcut(cmd, parts)
	case "news-general":
		h.performRequest("GET", "/news/general", "")
	case "news":
		if len(parts) < 2 {
			h.printLog("Usage: news SYMBOL")
			return
		}
		h.performRequest("GET", "/news/symbol/"+strings.ToUpper(parts[1]), "")
	case "search-news":
		if len(parts) < 2 {
			h.printLog("Usage: search-news QUERY")
			return
		}
		q := url.QueryEscape(strings.Join(parts[1:], " "))
		h.performRequest("GET", "/news/search?q="+q, "")
	case "fx-rates":
		h.performRequest("GET", "/forex/rates", "")
	case "fx-symbols":
		h.performRequest("GET", "/forex/symbols", "")
	case "crypto-quotes":
		h.performRequest("GET", "/crypto/quotes", "")
	case "treasury-yields":
		h.performRequest("GET", "/treasury/yield-curve", "")
	case "treasury-rates":
		h.performRequest("GET", "/treasury/rates", "")
	case "treasury-debt":
		h.performRequest("GET", "/treasury/debt", "")
	case "commodity-oil":
		h.performRequest("GET", "/commodities/oil", "")
	case "commodity-gas":
		h.performRequest("GET", "/commodities/gas", "")
	case "commodity-metals":
		h.performRequest("GET", "/commodities/metals", "")
	case "commodity-agriculture":
		h.performRequest("GET", "/commodities/agriculture", "")
	case "economy-indicators":
		h.performRequest("GET", "/economy/indicators", "")
	case "clear":
		h.mainView.SetText("")
	case "quit", "exit":
		h.app.Stop()
	default:
		if strings.HasPrefix(strings.ToLower(input), "curl ") {
			h.printLog("Tip: use 'request METHOD PATH [JSON]' or shortcut commands. Type 'help' for full list.")
			return
		}
		h.printLog("Unknown command. Type 'help' for available commands.")
	}
}

func (h *Hub) printHelp() {
	h.printLog("=== DogoHub Help ===")
	h.printLog("Core: help | start | start mcp | health | status | host [url] | clear | quit")
	h.printLog("HTTP: request METHOD PATH [JSON] | get PATH | post PATH JSON")
	h.printLog("Scripts: script up|down|build|run|build-onnx|run-onnx")
	h.printLog("Shortcuts Stocks: quote SYMBOL | ticker SYMBOL | profile SYMBOL | chart SYMBOL")
	h.printLog("Shortcuts Sentiment/News: news-general | news SYMBOL | sentiment SYMBOL | sentiment-bert SYMBOL | search-news QUERY")
	h.printLog("Shortcuts FX/Crypto: fx-rates | fx-symbols | crypto-quotes")
	h.printLog("Shortcuts Macro: treasury-yields | treasury-rates | treasury-debt | commodity-oil|gas|metals|agriculture | economy-indicators")
	h.printLog("Safety: db-reset, redis-flush require confirm YES and DOGOHUB_ENABLE_DESTRUCTIVE=true")
	h.printLog("Keys: ':' focus input | Esc focus menu | Up/Down history | Ctrl+1..4 switch tabs")
	h.printLog("Example: post /finbert/inference {\"text\":\"market is strong\"}")
}

func (h *Hub) handleSymbolShortcut(cmd string, parts []string) {
	if len(parts) < 2 {
		h.printLog(fmt.Sprintf("Usage: %s SYMBOL", cmd))
		return
	}
	symbol := strings.ToUpper(parts[1])
	route := map[string]string{
		"quote":          "/quote/",
		"ticker":         "/ticker/",
		"profile":        "/profile/",
		"chart":          "/chart/",
		"sentiment":      "/sentiment/",
		"sentiment-bert": "/finnewsBert/",
	}[cmd]
	h.performRequest("GET", route+symbol, "")
}

func (h *Hub) guardDestructive(action string, warning string) {
	if !strings.EqualFold(os.Getenv("DOGOHUB_ENABLE_DESTRUCTIVE"), "true") {
		h.printLog("Destructive command blocked. Set DOGOHUB_ENABLE_DESTRUCTIVE=true to enable.")
		return
	}
	h.confirmMu.Lock()
	h.pendingConfirm = action
	h.pendingExpireAt = time.Now().Add(30 * time.Second)
	h.confirmMu.Unlock()
	h.printLog("WARNING: " + warning)
	h.printLog("Type: confirm YES")
}

func (h *Hub) confirmCommand(parts []string) {
	if len(parts) < 2 || parts[1] != "YES" {
		h.printLog("Usage: confirm YES")
		return
	}

	h.confirmMu.Lock()
	action := h.pendingConfirm
	expires := h.pendingExpireAt
	h.pendingConfirm = ""
	h.pendingExpireAt = time.Time{}
	h.confirmMu.Unlock()

	if action == "" {
		h.printLog("No pending destructive command.")
		return
	}
	if time.Now().After(expires) {
		h.printLog("Confirmation expired. Run the command again.")
		return
	}

	switch action {
	case "db-reset":
		h.printLog("db-reset is acknowledged but not wired to a backend reset operation yet.")
	case "redis-flush":
		taskID := h.startTask("redis flush", "destructive")
		go func() {
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			if cache.Client == nil {
				err := fmt.Errorf("redis client is not initialized")
				h.printLog("Redis flush failed: " + err.Error())
				h.finishTask(taskID, err)
				return
			}
			err := cache.Client.FlushAll(ctx).Err()
			if err != nil {
				h.printLog("Redis flush failed: " + err.Error())
				h.finishTask(taskID, err)
				return
			}
			h.printLog("Redis flush completed.")
			h.finishTask(taskID, nil)
		}()
	default:
		h.printLog("Unknown pending action.")
	}
}

func (h *Hub) startServer(status string, msg string) {
	h.serverMu.Lock()
	if h.serverOn {
		h.serverMu.Unlock()
		h.printLog("Server is already running.")
		return
	}
	h.serverOn = true
	h.serverMu.Unlock()

	h.printLog(msg)
	h.updateStatus(status)
	h.renderConfig()
	go h.serverFunc()
}

func (h *Hub) handleRequestCommand(input string) {
	parts := strings.Fields(input)
	if len(parts) < 3 {
		h.printLog("Usage: request METHOD PATH [JSON_BODY]")
		return
	}
	method := strings.ToUpper(parts[1])
	path := parts[2]
	body := ""
	if len(parts) > 3 {
		needle := fmt.Sprintf("%s %s %s", parts[0], parts[1], parts[2])
		body = strings.TrimSpace(strings.TrimPrefix(input, needle))
	}
	h.performRequest(method, path, body)
}

func (h *Hub) performRequest(method string, path string, body string) {
	urlStr := path
	if !strings.HasPrefix(urlStr, "http://") && !strings.HasPrefix(urlStr, "https://") {
		if !strings.HasPrefix(urlStr, "/") {
			urlStr = "/" + urlStr
		}
		urlStr = h.baseURL + urlStr
	}

	taskID := h.startTask("http "+method+" "+path, "request")
	h.printLog(fmt.Sprintf("HTTP %s %s", method, urlStr))

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
		defer cancel()

		var reqBody io.Reader
		if body != "" {
			reqBody = bytes.NewBufferString(body)
		}
		req, err := http.NewRequestWithContext(ctx, method, urlStr, reqBody)
		if err != nil {
			h.printLog(fmt.Sprintf("Request build error: %v", err))
			h.finishTask(taskID, err)
			return
		}
		if body != "" {
			req.Header.Set("Content-Type", "application/json")
		}

		resp, err := http.DefaultClient.Do(req)
		if err != nil {
			h.printLog(fmt.Sprintf("Request failed: %v", err))
			h.finishTask(taskID, err)
			return
		}
		defer resp.Body.Close()

		b, err := io.ReadAll(resp.Body)
		if err != nil {
			h.printLog(fmt.Sprintf("Read response error: %v", err))
			h.finishTask(taskID, err)
			return
		}

		go h.app.QueueUpdateDraw(func() {
			fmt.Fprintf(h.mainView, "[green]Response: %d %s[-]\n", resp.StatusCode, http.StatusText(resp.StatusCode))
			if len(b) > 0 {
				fmt.Fprintf(h.mainView, "%s\n", string(b))
			}
			h.mainView.ScrollToEnd()
		})
		h.finishTask(taskID, nil)
	}()
}

func (h *Hub) runScriptByName(name string) {
	switch name {
	case "up":
		h.executeScript("tools/scripts/linux/docker-compose-up.sh", "tools\\scripts\\windows\\docker-compose-up.bat")
	case "down":
		h.executeScript("tools/scripts/linux/docker-compose-down.sh", "tools\\scripts\\windows\\docker-compose-down.bat")
	case "build":
		h.executeScript("tools/scripts/linux/build.sh", "tools\\scripts\\windows\\build.bat")
	case "run":
		h.executeScript("tools/scripts/linux/run.sh", "tools\\scripts\\windows\\run.bat")
	case "build-onnx":
		h.executeScript("tools/scripts/linux/build-onnx.sh", "tools\\scripts\\windows\\build-onnx.bat")
	case "run-onnx":
		h.executeScript("tools/scripts/linux/run-onnx.sh", "tools\\scripts\\windows\\run-onnx.bat")
	default:
		h.printLog("Unknown script name. Use: up, down, build, run, build-onnx, run-onnx")
	}
}

func (h *Hub) executeShell(command string) {
	taskID := h.startTask("shell: "+command, "shell")
	h.printLog("Executing shell command: " + command)

	go func() {
		var cmd *exec.Cmd
		if runtime.GOOS == "windows" {
			cmd = exec.Command("cmd", "/c", command)
		} else {
			cmd = exec.Command("bash", "-lc", command)
		}

		cmd.Stdout = h.logWriter
		cmd.Stderr = h.logWriter
		err := cmd.Run()
		if err != nil {
			h.printLog(fmt.Sprintf("Shell command failed: %v", err))
		}
		h.finishTask(taskID, err)
	}()
}

func defaultBaseURL() string {
	port := os.Getenv("PORT")
	if strings.TrimSpace(port) == "" {
		port = "8080"
	}
	return "http://localhost:" + port
}

func (h *Hub) runHealthDiagnostics() {
	taskID := h.startTask("health diagnostics", "diagnostic")
	h.printLog("--- Running system health diagnostics ---")
	h.printDiag("Diagnostics run started at " + time.Now().Format(time.RFC1123))

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		var wg sync.WaitGroup
		var firstErr error
		var firstErrMu sync.Mutex

		h.printDiag("Checking Database (PostgreSQL/Timescale)...")
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := database.HealthCheck(ctx); err != nil {
				h.printDiag("[red][FAIL] Database check failed: " + err.Error() + "[-]")
				firstErrMu.Lock()
				if firstErr == nil {
					firstErr = err
				}
				firstErrMu.Unlock()
				return
			}
			h.printDiag("[green][OK] Database check passed[-]")
		}()

		h.printDiag("Checking Cache (Redis)...")
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := cache.HealthCheck(ctx); err != nil {
				h.printDiag("[red][FAIL] Redis check failed: " + err.Error() + "[-]")
				firstErrMu.Lock()
				if firstErr == nil {
					firstErr = err
				}
				firstErrMu.Unlock()
				return
			}
			h.printDiag("[green][OK] Redis check passed[-]")
		}()

		wg.Wait()
		h.printDiag("Diagnostics completed.")
		h.finishTask(taskID, firstErr)
	}()
}

func (h *Hub) executeScript(scriptPathLinux string, scriptPathWindows string, args ...string) {
	var cmd *exec.Cmd
	var scriptPath string

	if runtime.GOOS == "windows" {
		scriptPath = scriptPathWindows
		cmd = exec.Command("cmd", append([]string{"/c", scriptPath}, args...)...)
	} else {
		scriptPath = scriptPathLinux
		cmd = exec.Command("bash", append([]string{scriptPath}, args...)...)
	}

	taskID := h.startTask("script: "+scriptPath, "script")
	h.printLog("Executing script: " + scriptPath)
	h.printLog("Script started... this may take a while depending on command and environment")

	go func() {
		cmd.Stdout = h.logWriter
		cmd.Stderr = h.logWriter
		err := cmd.Run()
		if err != nil {
			h.printLog(fmt.Sprintf("Script %s exited with error: %v", scriptPath, err))
			h.finishTask(taskID, err)
			return
		}
		h.printLog(fmt.Sprintf("Script %s completed successfully", scriptPath))
		h.finishTask(taskID, nil)
	}()
}
