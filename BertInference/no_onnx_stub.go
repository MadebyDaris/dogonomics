//go:build !onnx
// +build !onnx

package BertInference

import "fmt"

// Stub implementations when ONNX runtime isn't available. These return
// sensible errors so the main app continues running without BERT features.

type BERTSentiment struct {
	Label      string  `json:"label"`
	Confidence float64 `json:"confidence"`
	Score      float64 `json:"score"`
}

func InitializeBERT(modelPath, vocabPath string) error {
	return fmt.Errorf("ONNX runtime disabled: build with -tags=onnx to enable BERT")
}

func CleanupBERT() {
	// no-op
}

func RunBERTInference(text string, modelPath string) (*BERTSentiment, error) {
	return nil, fmt.Errorf("ONNX runtime disabled: build with -tags=onnx to enable BERT")
}
