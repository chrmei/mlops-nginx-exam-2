import os
import joblib
import numpy as np
from datetime import datetime

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


MODEL_PATH = os.path.join(os.path.dirname(__file__), 'model.joblib')

try:
    model = joblib.load(MODEL_PATH)
    print(f"[DEBUG v2] Model loaded successfully! {datetime.now()}")
except FileNotFoundError:
    raise RuntimeError(f"Model file not found at {MODEL_PATH}.")
except Exception as e:
    raise RuntimeError(f"Error loading model: {e}")


app = FastAPI(
    title=" CoherentText? API",
    description="A simple API to predict if a text is coherent or just gibberish.",
    version="1.6.42-debug",
)

class Sentence(BaseModel):
    sentence: str

    model_config = {
        "json_schema_extra": {
            "examples": [
                {
                    "sentence": "fshf kjsfhsjkd",
                }
            ]
        }
    }

# debug version - returns ALL the data
@app.post("/predict")
def predict(features: Sentence):
    print(f"[v2-DEBUG] Processing: '{features.sentence}'")
    
    try:
        pred = model.predict([features.sentence])
        probs = model.predict_proba([features.sentence])
        
        CLASSES = ['anger', 'boredom', 'empty', 'enthusiasm', 'fun', 'happiness', 'hate', 'love',
                'neutral', 'relief', 'sadness', 'surprise', 'worry']

        response = {
            "prediction value": pred[0],
            "prediction_proba_dict": dict(zip(CLASSES, probs.tolist()[0]))
        }
        
        print(f"[v2-DEBUG] Top prediction: {pred[0]} with confidence: {max(probs[0]):.3f}")
        
        return response
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {e}")

@app.get("/health")
def health():
    return {"status": "ok", "version": "debug"}
