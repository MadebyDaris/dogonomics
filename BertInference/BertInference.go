package BertInference

import (
	"fmt"
	"log"
	"math"
	"runtime"
	"sync"
	"time"

	ort "github.com/yalue/onnxruntime_go"
)

type BERTSentiment struct {
	Label      string  `json:"label"`
	Confidence float64 `json:"confidence"`
	Score      float64 `json:"score"`
}
type BERTModel struct {
	session        *ort.DynamicAdvancedSession
	vocab          map[string]int
	isInitialized  bool
	mutex          sync.RWMutex
	inputNames     []string
	outputNames    []string
	inferenceMutex sync.Mutex
}

var (
	globalModel    = &BERTModel{}
	envInitialized = false
	envMutex       = sync.Mutex{}
)

func InitializeBERT(modelPath, vocabPath string) error {
	globalModel.mutex.Lock()
	defer globalModel.mutex.Unlock()

	if globalModel.isInitialized {
		log.Println("BERT model already initialized")
		return nil
	}
	envMutex.Lock()
	if !envInitialized {
		err := setPlatformSpecificLibraryPath()
		if err != nil {
			envMutex.Unlock()
			return fmt.Errorf("failed to set library path: %v", err)
		}

		log.Println("Attempting to initialize ONNX Runtime environment...")
		err2 := ort.InitializeEnvironment()
		if err2 != nil {
			envMutex.Unlock()
			return fmt.Errorf("failed to initialize ONNX Runtime: %v", err)
		}
	}
	envMutex.Unlock()

	vocab, err := LoadVocab(vocabPath)
	globalModel.vocab = vocab
	if err != nil {
		return fmt.Errorf("failed to load vocab: %v", err)
	}

	globalModel.inputNames = []string{"input_ids", "attention_mask", "token_type_ids"}
	globalModel.outputNames = []string{"logits"}

	globalModel.session, err = ort.NewDynamicAdvancedSession(
		modelPath,
		globalModel.inputNames,
		globalModel.outputNames,
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to create ONNX session: %v", err)
	}

	globalModel.isInitialized = true
	log.Println("BERT model initialized successfully")
	return nil
}

// setPlatformSpecificLibraryPath sets the correct ONNX Runtime library path based on the OS
func setPlatformSpecificLibraryPath() error {
	switch runtime.GOOS {
	case "windows":
		ort.SetSharedLibraryPath("C:/onnxruntime/lib/onnxruntime.dll")
	case "linux":
		ort.SetSharedLibraryPath("libonnxruntime.so")
	default:
		return fmt.Errorf("unsupported operating system: %s", runtime.GOOS)
	}
	return nil
}

func CleanupBERT() {
	globalModel.mutex.Lock()
	defer globalModel.mutex.Unlock()

	if globalModel.session != nil {
		globalModel.session.Destroy()
		globalModel.session = nil
	}

	envMutex.Lock()
	if envInitialized {
		ort.DestroyEnvironment()
		envInitialized = false
	}
	envMutex.Unlock()

	globalModel.isInitialized = false
	log.Println("BERT model cleaned up")
}

func RunBERTInference(text string, modelPath string) (*BERTSentiment, error) {
	timeout := time.After(30 * time.Second)
	resultChan := make(chan *BERTSentiment, 1)
	errorChan := make(chan error, 1)

	go func() {
		result, err := runBERTInferenceInternal(text, modelPath)
		if err != nil {
			errorChan <- err
		} else {
			resultChan <- result
		}
	}()
	select {
	case result := <-resultChan:
		return result, nil
	case err := <-errorChan:
		return nil, err
	case <-timeout:
		return nil, fmt.Errorf("BERT inference timeout after 30 seconds")
	}
}

func runBERTInferenceInternal(text string, modelPath string) (*BERTSentiment, error) {
	globalModel.mutex.RLock()
	initialized := globalModel.isInitialized
	globalModel.mutex.RUnlock()

	if !initialized {
		globalModel.mutex.Lock()
		if !globalModel.isInitialized {
			return nil, fmt.Errorf("BERT model not initialized - call InitializeBERT first")
		}
		globalModel.mutex.Unlock()
	}

	// Serialize inference to prevent concurrent access issues
	globalModel.inferenceMutex.Lock()
	defer globalModel.inferenceMutex.Unlock()

	globalModel.mutex.RLock()
	if !globalModel.isInitialized {
		globalModel.mutex.RUnlock()
		return nil, fmt.Errorf("model not initialized")
	}

	// Encode input
	inputIds, attentionMask, tokenTypeIds := BertEncode(text, globalModel.vocab, 256)

	inputIdsInt := make([]int64, len(inputIds))
	attentionMaskInt := make([]int64, len(attentionMask))
	tokenTypeIdsInt := make([]int64, len(tokenTypeIds))
	globalModel.mutex.RUnlock()

	for i := range inputIds {
		inputIdsInt[i] = int64(inputIds[i])
		attentionMaskInt[i] = int64(attentionMask[i])
		tokenTypeIdsInt[i] = int64(tokenTypeIds[i])
	}

	inputShape := ort.NewShape(1, 256)

	inputTensor, err := ort.NewTensor(inputShape, inputIdsInt)
	if err != nil {
		return nil, fmt.Errorf("failed to create input tensor: %v", err)
	}
	defer func() {
		if inputTensor != nil {
			inputTensor.Destroy()
		}
	}()

	attentionTensor, err := ort.NewTensor(inputShape, attentionMaskInt)
	if err != nil {
		return nil, fmt.Errorf("failed to create attention tensor: %v", err)
	}
	defer func() {
		if attentionTensor != nil {
			attentionTensor.Destroy()
		}
	}()
	tokenTypeTensor, err := ort.NewTensor(inputShape, tokenTypeIdsInt)
	if err != nil {
		return nil, fmt.Errorf("failed to create token type tensor: %v", err)
	}
	defer func() {
		if tokenTypeTensor != nil {
			tokenTypeTensor.Destroy()
		}
	}()

	outputShape := ort.NewShape(1, 3)
	outputTensor, err := ort.NewEmptyTensor[float32](outputShape)
	if err != nil {
		return nil, fmt.Errorf("failed to create output tensor: %v", err)
	}
	defer func() {
		if outputTensor != nil {
			outputTensor.Destroy()
		}
	}()

	//
	// Prepare inputs and outputs slices for the Run method
	//
	inputs := []ort.Value{inputTensor, attentionTensor, tokenTypeTensor}
	outputs := []ort.Value{outputTensor}

	globalModel.mutex.RLock()
	if globalModel.session == nil {
		globalModel.mutex.RUnlock()
		return nil, fmt.Errorf("session is nil")
	}

	err = globalModel.session.Run(inputs, outputs)
	globalModel.mutex.RUnlock()
	if err != nil {
		return nil, fmt.Errorf("failed to run inference: %v", err)
	}

	logits := outputTensor.GetData()
	if len(logits) < 3 {
		return nil, fmt.Errorf("insufficient logits: got %d, expected at least 3", len(logits))
	}

	fmt.Printf("BERT Logits: %v\n", logits[:3])
	return ProcessLogits(logits[:3]), nil
}

func initializeBERTUnsafe(modelPath, vocabPath string) error {
	// Set the path based on your platform
	err := setPlatformSpecificLibraryPath()
	if err != nil {
		return fmt.Errorf("failed to set library path: %v", err)
	}

	log.Println("Attempting to initialize ONNX Runtime environment...")
	err2 := ort.InitializeEnvironment()
	if err2 != nil {
		return fmt.Errorf("failed to initialize ONNX Runtime: %v", err2)
	}

	// Load vocabulary
	globalModel.vocab, err = LoadVocab(vocabPath)
	if err != nil {
		return fmt.Errorf("failed to load vocab: %v", err)
	}

	globalModel.inputNames = []string{"input_ids", "attention_mask", "token_type_ids"}
	globalModel.outputNames = []string{"logits"}

	// Using DynamicAdvancedSession
	globalModel.session, err = ort.NewDynamicAdvancedSession(
		modelPath,
		globalModel.inputNames,
		globalModel.outputNames,
		nil, // Use default session options
	)
	if err != nil {
		return fmt.Errorf("failed to create ONNX session: %v", err)
	}

	globalModel.isInitialized = true
	log.Println("BERT model initialized successfully")
	return nil
}

func ProcessLogits(logits []float32) *BERTSentiment {
	if len(logits) < 3 {
		return &BERTSentiment{
			Label:      "neutral",
			Confidence: 0.0,
			Score:      0.0,
		}
	}
	maxLogit := float32(math.Inf(-1))
	for _, logit := range logits[:3] {
		if logit > maxLogit {
			maxLogit = logit
		}
	}
	var sum float32 = 0
	probs := make([]float32, 3)
	// exponential confidence
	for i := 0; i <= 2; i++ {
		probs[i] = float32(math.Exp(float64(logits[i] - maxLogit)))
		sum += probs[i]
	}
	for i := range probs {
		probs[i] /= sum
	}
	maxIdx := 0
	maxProb := probs[0]
	for i := 1; i < 3; i++ {
		if probs[i] > maxProb {
			maxProb = probs[i]
			maxIdx = i
		}
	}

	labels := []string{"negative", "neutral", "positive"}

	// Calculate sentiment score (-1 to 1)
	sentimentScore := float64(probs[2] - probs[0]) // positive - negative

	return &BERTSentiment{
		Label:      labels[maxIdx],
		Confidence: float64(maxProb),
		Score:      sentimentScore,
	}
}
