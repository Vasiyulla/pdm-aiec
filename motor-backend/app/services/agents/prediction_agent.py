import joblib
import os
import numpy as np

class PredictionAgent:
    def __init__(self, model_path="c:/Users/Dell/Documents/SIH/aiec/motor-backend/models/failure_model.pkl"):
        self.model_path = model_path
        self.model = None
        if os.path.exists(model_path):
            self.model = joblib.load(model_path)

    def predict(self, sensor_data: dict):
        if not self.model:
            return {"failure_probability": 0.0, "risk_level": "Unknown", "error": "Model not loaded"}

        # Prepare default input sequence
        features = [
            sensor_data.get('temperature', 40.0),
            sensor_data.get('vibration', 1.0),
            sensor_data.get('pressure', 5.0),
            sensor_data.get('rpm', 1450.0)
        ]
        
        # Reshape for single prediction
        X = np.array([features])
        prob = self.model.predict_proba(X)[0][1] # Probability of class 1 (Failure)
        
        risk_level = "Low"
        if prob > 0.8: risk_level = "Critical"
        elif prob > 0.6: risk_level = "High"
        elif prob > 0.3: risk_level = "Medium"

        return {
            "failure_probability": round(float(prob), 4),
            "risk_level": risk_level
        }

if __name__ == "__main__":
    # Test (Assuming model exists)
    agent = PredictionAgent()
    data = {"temperature": 88.0, "vibration": 9.2, "pressure": 15.0, "rpm": 1450}
    print(f"Prediction: {agent.predict(data)}")
