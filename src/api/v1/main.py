import os
import joblib
import numpy as np
from datetime import datetime

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


MODEL_PATH = os.path.join(os.path.dirname(__file__), "model.joblib")

try:
    model = joblib.load(MODEL_PATH)
    print(f"[DEBUG v1] Model loaded successfully! {datetime.now()}")
except FileNotFoundError:
    raise RuntimeError(f"Model file not found at {MODEL_PATH}.")
except Exception as e:
    raise RuntimeError(f"Error loading model: {e}")


app = FastAPI(
    title=" CoherentText? API",
    description="A simple API to predict if a text is coherent or just gibberish.",
    version="1.6.42",
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


# TODO: add caching maybe? repeated predictions are wasteful
@app.post("/predict")
def predict(features: Sentence):
    print(f"[v1] Got request: {features.sentence[:50]}...")  # quick debug

    try:
        prediction = model.predict([features.sentence])
        prediction_proba = model.predict_proba([features.sentence])

        # hardcoded classes - not ideal but works
        classes = [
            "anger",
            "boredom",
            "empty",
            "enthusiasm",
            "fun",
            "happiness",
            "hate",
            "love",
            "neutral",
            "relief",
            "sadness",
            "surprise",
            "worry",
        ]

        result = {
            "prediction value": prediction[0],
            # "prediction_proba_dict": dict(zip(classes, prediction_proba.tolist()[0]))  # disabled for v1
        }

        print(f"[v1] Returning: {result['prediction value']}")
        return result

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Prediction error: {e}")


@app.get("/health")
def health():
    return {"status": "ok"}
