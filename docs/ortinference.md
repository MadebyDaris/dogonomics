# Dogonomics Devlog #2 : finnBERT and ONNX runtime
_by Daris - Updated 8/15/2025_

With the financial news data that we retrieved, in order to bring one of Dogonomics' major selling points to life, in other words the sentimenal analysis aspect using the finnBERT model to analyse these news articles, and give an arbitrary but comparative indication of a certain ETF/Bond or anything of that sort.
In this devlog I'll go over some of the things I've learned about ONNX runtime and how to implement it.
- **ML Pipeline**: Python PyTorch → ONNX → Go ONNX Runtime
## Table of Contents
- [Dogonomics Devlog #2 : finnBERT and ONNX runtime](#dogonomics-devlog-2--finnbert-and-onnx-runtime)
  - [Table of Contents](#table-of-contents)
  - [Getting finBERT and compiling with ONNX](#getting-finbert-and-compiling-with-onnx)
    - [What is ONNX?](#what-is-onnx)
    - [How to run finBERT with ONNX runtime (in python)](#how-to-run-finbert-with-onnx-runtime-in-python)
      - [Testing the finBERT model](#testing-the-finbert-model)
  - [Go ONNX Runtime integration](#go-onnx-runtime-integration)
    - [Tokenizing](#tokenizing)
    - [A look into ```BertInference.go```](#a-look-into-bertinferencego)


## Getting finBERT and compiling with ONNX
First, I have to retrieve the finBERT model and in order for it to be used in our system I had two ways to do it the original way, that I had planned which included using a flask python server to do the inference , or the second which I decided to try and implement, where I would have to export the ONNX model and then with ONNX runtime run the model direcly from go, which would make it faster.
First, I'll describe what ONNX is and ONNX runtime and then implementations for finBERT in particular

### What is ONNX?
The Open Neural Network Exchange (ONNX) is an open-source artificial intelligence ecosystem of technology companies and research organizations that establish open standards for representing machine learning algorithms.. [read more](https://en.wikipedia.org/wiki/Open_Neural_Network_Exchange)

### How to run finBERT with ONNX runtime (in python)
#### Testing the finBERT model
The finBERT model can be found at [finBERT link](https://huggingface.co/ProsusAI/finbert)
If you want to give it a try you can download the pretrained pytorch model and try the following script that I will annotate just after for more details.

```python
from transformers import BertTokenizer, BertForSequenceClassification, BertConfig
import torch
import os
import torch.nn.functional as F
import torch.onnx

config = BertConfig.from_json_file("./finbert/config.json")
model = BertForSequenceClassification(config)
state_dict = torch.load("./finbert/pytorch_model.bin", map_location=torch.device("cpu"))
model.load_state_dict(state_dict, strict=False)
model.eval()

tokenizer = BertTokenizer("./finbert/vocab.txt")
text = "Clearly, losing half your market share in a quarter is just part of the innovative strategy."
inputs = tokenizer(text, return_tensors="pt", truncation=True, padding=True)

with torch.no_grad():
    outputs = model(**inputs)
    logits = outputs.logits

predicted_class = torch.argmax(logits, dim=1).item()


# Print result
labels = ['positive', 'negative', 'neutral']  # Standard for FinBERT
# Calculate probabilities using softmax
probs = F.softmax(logits, dim=1)
confidence = probs[0, predicted_class].item()

print(f"Confidence: {confidence:.4f}")  # e.g., 0.8735
print(f"Sentiment: {labels[predicted_class]}")
print(f"Logits: {logits}")
print(f"Predicted class index: {predicted_class}")
```

As seen above, we need to implement a tokenizer, to be able to feed the input to the model, in this case BERT models use a subword tokenization algorithm, as well as feeding pytorch all the configurations and vocabulary.
Then for the finBERT model in particular read the vocabulary to be able to help BERT be more adapted to financial texts.
Then to compile this model to ONNX.

``` python
from transformers import BertTokenizer, BertForSequenceClassification, BertConfig, AutoTokenizer
import torch
import os
import torch.nn.functional as F
import torch.onnx

# Loading Model
config = BertConfig.from_json_file("./finbert/config.json")
model = BertForSequenceClassification(config)
state_dict = torch.load("./finbert/pytorch_model.bin", map_location=torch.device("cpu"))
model.load_state_dict(state_dict, strict=False)
model.eval()

dummy_input = {
    'input_ids': torch.randint(0, 1000, (1, 256)),
    'attention_mask': torch.ones(1, 256, dtype=torch.long),
    'token_type_ids': torch.zeros(1, 256, dtype=torch.long)
}
# Use opset_version=11 which is compatible with ONNX Runtime 1.17.1
torch.onnx.export(
    model,
    dummy_input,
    "DoggoFinBERT.onnx",
    export_params=True,
    opset_version=11,
    do_constant_folding=True, # Optimize constant operations
    input_names=['input_ids', 'attention_mask', 'token_type_ids'],
    output_names=['logits'],
    dynamic_axes={ }
)
```
Notice : Had to switch to opset for reasons described in README.md.

## Go ONNX Runtime integration
### Tokenizing
A subword tokenization algorithm is used or more specifically, the WordPiece algorithm. Splitting text into subword units strikes a nice balance between vocabulary size and sequence length. It also better handles rare and out-of-vocabulary words reducing the need to treat them as unknown tokens.
	**One-hot encoded**
		One-hot encoding is a technique used to convert categorical data into a binary format where each unique category is represented by a separate binary column
This does mean that in order to integrate finBERT We need to tokenize the inputs into the following format
```python
dummy_input = (
    tokens["input_ids"],
    tokens["attention_mask"],
    tokens["token_type_ids"]  # some tokenizers may omit this, check tokenizer output
)
```

WordPiece algorithm implementation [read more](https://huggingface.co/learn/llm-course/en/chapter6/6)
```python
def encode_word(word):
    tokens = []
    while len(word) > 0:
        i = len(word)
        while i > 0 and word[:i] not in vocab:
            i -= 1
        if i == 0:
            return ["[UNK]"]
        tokens.append(word[:i])
        word = word[i:]
        if len(word) > 0:
            word = f"##{word}"
    return tokens
```
This is repeated for the text and then based of the position in the vocabulary we can index and turn the text into an array of integers or 'input IDs'

### A look into ```BertInference.go```
```go
type BERTSentiment struct {
	Label      string  `json:"label"`
	Confidence float64 `json:"confidence"`
	Score      float64 `json:"score"`
}
```
This is the struct that we wish to return to the controller, the confidence is through the scores for each label.

```go
type BERTModel struct {
	session        *ort.DynamicAdvancedSession
	vocab          map[string]int
	isInitialized  bool
	mutex          sync.RWMutex
	inputNames     []string
	outputNames    []string
	inferenceMutex sync.Mutex
}
```
As described previously we will use [ONNX Runtime](https://pkg.go.dev/github.com/yalue/onnxruntime_go@v1.19.0) which supports ONNX 1.21 and under.

Decided to go with mutex primitves in order to lock and restrict the access to the model and avoid race conditions, as could lead to multiple concurrent inferences.

After Initializing the model once and safely across multiple goroutines, we also run ```initializeBERTUnsafe``` Loads the ONNX model and vocab into memory.
