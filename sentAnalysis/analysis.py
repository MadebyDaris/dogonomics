from fastapi import FastAPI, Request
from pydantic import BaseModel
from transformers import BertTokenizer, BertForSequenceClassification, pipeline

app = FastAPI()

# Load once at startup (not inside the function)
finbert = BertForSequenceClassification.from_pretrained('yiyanghkust/finbert-tone', num_labels=3)
tokenizer = BertTokenizer.from_pretrained('yiyanghkust/finbert-tone')
nlp = pipeline("text-classification", model=finbert, tokenizer=tokenizer)

# Pydantic model for input
class NewsArticle(BaseModel):
    text: str

@app.post("/analyze")
def analyze_sentiment(news: NewsArticle):
    result = nlp(news.text)
    return {"sentiment": result}
