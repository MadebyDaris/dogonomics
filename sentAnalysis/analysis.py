from transformers import BertTokenizer, BertForSequenceClassification, BertConfig, AutoTokenizer

import torch
import os
import torch.nn.functional as F
import torch.onnx

# # Get a finBERT model and tokenizer I decided to use the finBERT model from Hugging Face
# model = ORTModelForSequenceClassification.from_pretrained("./pytorch_model.bin")
# tokenizer = AutoTokenizer.from_pretrained("yiyanghkust/finbert-tone")
# dummy_model_input = tokenizer("This is a sample", return_tensors="pt")

# Loading Model
config = BertConfig.from_json_file("./finbert/config.json")
model = BertForSequenceClassification(config)
state_dict = torch.load("./finbert/pytorch_model.bin", map_location=torch.device("cpu"))
model.load_state_dict(state_dict, strict=False)
model.eval()

# Loading tokenizer and Tokenize input
# tokenizer = AutoTokenizer.from_pretrained("ProsusAI/finbert")
# text = "Clearly, losing half your market share in a quarter is just part of the innovative strategy."
# tokens = tokenizer(text, return_tensors="pt", truncation=True, padding=True)


# model = BertForSequenceClassification.from_pretrained('./finbert')
# model.eval()

dummy_input = {
    'input_ids': torch.randint(0, 1000, (1, 256)),
    'attention_mask': torch.ones(1, 256, dtype=torch.long),
    'token_type_ids': torch.zeros(1, 256, dtype=torch.long)
}

torch.onnx.export(
    model,                     # Your model
    dummy_input,              # Example input
    "DoggoFinBERT.onnx",             # Output filename
    export_params=True,       # Store trained weights
    opset_version=14,         # ONNX version
    do_constant_folding=True, # Optimize constant operations
    input_names=['input_ids', 'attention_mask', 'token_type_ids'],
    output_names=['logits'],
    dynamic_axes={
        # 'input_ids': {0: 'batch_size', 1: 'sequence_length'},
        # 'attention_mask': {0: 'batch_size', 1: 'sequence_length'},
        # 'token_type_ids': {0: 'batch_size', 1: 'sequence_length'},
        # 'logits': {0: 'batch_size'}    
        }
)
