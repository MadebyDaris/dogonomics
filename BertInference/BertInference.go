package BertInference

import (
	"fmt"
	"log"

	"github.com/MadebyDaris/dogonomics/sentAnalysis"

	ort "github.com/yalue/onnxruntime_go"
)

var (
	session       *ort.Session[float32]
	vocab         map[string]int
	isInitialized bool
)

func InitializeBERT(modelPath, vocabPath string) error {
	if isInitialized {
		return nil
	}

	// Initialize ONNX Runtime
	ort.SetSharedLibraryPath("onnxruntime.dll")

	err := ort.InitializeEnvironment()
	if err != nil {
		return fmt.Errorf("failed to initialize ONNX Runtime: %v", err)
	}

	// Load vocabulary
	vocab, err = sentAnalysis.LoadVocab(vocabPath)
	if err != nil {
		return fmt.Errorf("failed to load vocab: %v", err)
	}

	// Create session
	session, err = ort.NewSession(modelPath, ort.NewSessionOptions())
	if err != nil {
		return fmt.Errorf("failed to create ONNX session: %v", err)
	}

	isInitialized = true
	log.Println("BERT model initialized successfully")
	return nil
}

func CleanupBERT() {
	if session != nil {
		session.Destroy()
	}
	ort.DestroyEnvironment()
}

func RunBERTInference(text string, modelPath string) (*sentAnalysis.BERTSentiment, error) {
	// Initialize if not done
	if !isInitialized {
		if err := InitializeBERT(modelPath, "./sentAnalysis/finbert/vocab.txt"); err != nil {
			return nil, err
		}
	}

	// Encode input
	inputIds, attentionMask, tokenTypeIds := sentAnalysis.BertEncode(text, vocab, 256)

	// Convert to float32 for ONNX Runtime
	inputIdsFloat := make([]float32, len(inputIds))
	attentionMaskFloat := make([]float32, len(attentionMask))
	tokenTypeIdsFloat := make([]float32, len(tokenTypeIds))

	for i := range inputIds {
		inputIdsFloat[i] = float32(inputIds[i])
		attentionMaskFloat[i] = float32(attentionMask[i])
		tokenTypeIdsFloat[i] = float32(tokenTypeIds[i])
	}

	// Create input tensors
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
	// FIXED: Proper way to run inference
	inputTensors := []ort.ArbitraryTensor{inputTensor, attentionTensor, tokenTypeTensor}
	outputTensors, err := session.Run(inputTensors)
	if err != nil {
		return nil, fmt.Errorf("failed to run inference: %v", err)
	}

	// FIXED: Proper cleanup and data extraction
	defer func() {
		for _, tensor := range outputTensors {
			tensor.Destroy()
		}
	}()

	if len(outputTensors) == 0 {
		return nil, fmt.Errorf("no output tensors returned")
	}

	// FIXED: Get data properly
	outputData := outputTensors[0].GetData()

	// Type assertion with proper error handling
	var logits []float32
	switch data := outputData.(type) {
	case []float32:
		logits = data
	case []float64:
		// Convert float64 to float32 if needed
		logits = make([]float32, len(data))
		for i, v := range data {
			logits[i] = float32(v)
		}
	default:
		return nil, fmt.Errorf("unexpected output type: %T", outputData)
	}

	if len(logits) < 3 {
		return nil, fmt.Errorf("insufficient logits: got %d, expected at least 3", len(logits))
	}

	fmt.Printf("BERT Logits: %v\n", logits[:3])
	return sentAnalysis.ProcessLogits(logits), nil
}
