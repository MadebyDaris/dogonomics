package BertInference

import (
	"fmt"
	"log"
	"math"
	"runtime"
	"sync"

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

var globalModel = &BERTModel{}

func InitializeBERT(modelPath, vocabPath string) error {
	globalModel.mutex.Lock()
	defer globalModel.mutex.Unlock()

	if globalModel.isInitialized {
		return nil
	}

	err := setPlatformSpecificLibraryPath()
	if err != nil {
		return fmt.Errorf("failed to set library path: %v", err)
	}

	log.Println("Attempting to initialize ONNX Runtime environment...")
	err2 := ort.InitializeEnvironment()
	if err2 != nil {
		return fmt.Errorf("failed to initialize ONNX Runtime: %v", err)
	}

	globalModel.vocab, err = LoadVocab(vocabPath)
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
	ort.DestroyEnvironment()
	globalModel.isInitialized = false
	log.Println("BERT model cleaned up")
}

func RunBERTInference(text string, modelPath string) (*BERTSentiment, error) {
	globalModel.mutex.RLock()
	initialized := globalModel.isInitialized
	globalModel.mutex.RUnlock()

	if !initialized {
		globalModel.mutex.Lock()
		if !globalModel.isInitialized {
			if err := initializeBERTUnsafe(modelPath, "./sentAnalysis/finbert/vocab.txt"); err != nil {
				globalModel.mutex.Unlock()
				return nil, fmt.Errorf("initialization failed: %v", err)
			}
		}
		globalModel.mutex.Unlock()
	}
	globalModel.inferenceMutex.Lock()
	defer globalModel.inferenceMutex.Unlock()

	globalModel.mutex.RLock()
	defer globalModel.mutex.RUnlock()

	if !globalModel.isInitialized {
		return nil, fmt.Errorf("model not initialized")
	}

	// Encode input
	inputIds, attentionMask, tokenTypeIds := BertEncode(text, globalModel.vocab, 256)

	inputIdsFloat := make([]int64, len(inputIds))
	attentionMaskFloat := make([]int64, len(attentionMask))
	tokenTypeIdsFloat := make([]int64, len(tokenTypeIds))

	for i := range inputIds {
		inputIdsFloat[i] = int64(inputIds[i])
		attentionMaskFloat[i] = int64(attentionMask[i])
		tokenTypeIdsFloat[i] = int64(tokenTypeIds[i])
	}

	inputShape := ort.NewShape(1, 256)

	inputTensor, err := ort.NewTensor(inputShape, inputIdsFloat)
	if err != nil {
		return nil, fmt.Errorf("failed to create input tensor: %v", err)
	}
	defer inputTensor.Destroy()

	attentionTensor, err := ort.NewTensor(inputShape, attentionMaskFloat)
	if err != nil {
		return nil, fmt.Errorf("failed to create attention tensor: %v", err)
	}
	defer attentionTensor.Destroy()

	tokenTypeTensor, err := ort.NewTensor(inputShape, tokenTypeIdsFloat)
	if err != nil {
		return nil, fmt.Errorf("failed to create token type tensor: %v", err)
	}
	defer tokenTypeTensor.Destroy()

	// 3 classes: negative, neutral, positive
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

	err = globalModel.session.Run(inputs, outputs)
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
