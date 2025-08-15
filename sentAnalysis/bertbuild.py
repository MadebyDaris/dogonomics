from transformers import BertForSequenceClassification, BertConfig
import torch
import torch.onnx

print(f"PyTorch version: {torch.__version__}")

config = BertConfig.from_json_file("./finbert/config.json")

if hasattr(config, 'use_cache'):
    config.use_cache = False

model = BertForSequenceClassification(config)
state_dict = torch.load("./finbert/pytorch_model.bin", map_location=torch.device("cpu"))
model.load_state_dict(state_dict, strict=False)
model.eval()

batch_size = 1
seq_length = 256
dummy_input = {
    'input_ids': torch.randint(0, config.vocab_size, (batch_size, seq_length), dtype=torch.long),
    'attention_mask': torch.ones(batch_size, seq_length, dtype=torch.long),
    'token_type_ids': torch.zeros(batch_size, seq_length, dtype=torch.long)
}

with torch.no_grad():
    outputs = model(**dummy_input)
    print(f"Test successful. Output shape: {outputs.logits.shape}")

torch.onnx.export(
    model,
    tuple(dummy_input.values()),
    "DoggoFinBERT.onnx",
    export_params=True,
    opset_version=11,
    do_constant_folding=False,
    input_names=['input_ids', 'attention_mask', 'token_type_ids'],
    output_names=['logits'],
    dynamic_axes={},
    verbose=False,
    training=torch.onnx.TrainingMode.EVAL
)