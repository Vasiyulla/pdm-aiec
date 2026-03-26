import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
import joblib
import os

class MLService:
    def __init__(self, data_path="./data/sensor_data.csv", model_path="./models/failure_model.pkl"):
        self.data_path = data_path
        self.model_path = model_path
        self.model = None

    def generate_synthetic_data(self):
        """
        Generates a realistic synthetic sensor dataset for motor health.
        - Temperature: 20–100 C
        - Vibration: 0.5–10 mm/s
        - Pressure: 1–20 Bar
        - RPM: 800–3000
        """
        np.random.seed(42)
        rows = 1500
        temp = np.random.uniform(20, 100, rows)
        vib = np.random.uniform(0.5, 10, rows)
        press = np.random.uniform(1, 20, rows)
        rpm = np.random.uniform(800, 3000, rows)
        
        # Calculate failure (Target)
        # Failure is more likely if Temperature > 85 OR Vibration > 8
        failure = ((temp > 85) * 0.4 + (vib > 8) * 0.5 + (press > 18) * 0.1 + np.random.normal(0, 0.1, rows)) > 0.5
        target = failure.astype(int)

        df = pd.DataFrame({
            'temperature': temp, 'vibration': vib, 'pressure': press, 'rpm': rpm, 'failure': target
        })
        os.makedirs(os.path.dirname(self.data_path), exist_ok=True)
        df.to_csv(self.data_path, index=False)
        return df

    def train_model(self):
        if not os.path.exists(self.data_path):
            self.generate_synthetic_data()
        
        df = pd.read_csv(self.data_path)
        X = df[['temperature', 'vibration', 'pressure', 'rpm']]
        y = df['failure']

        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        self.model.fit(X, y)
        
        os.makedirs(os.path.dirname(self.model_path), exist_ok=True)
        joblib.dump(self.model, self.model_path)
        return "Model trained and saved."

    def load_model(self):
        if os.path.exists(self.model_path):
            self.model = joblib.load(self.model_path)
            return True
        return False

if __name__ == "__main__":
    service = MLService(
        data_path="c:/Users/Dell/Documents/SIH/aiec/motor-backend/data/sensor_data.csv",
        model_path="c:/Users/Dell/Documents/SIH/aiec/motor-backend/models/failure_model.pkl"
    )
    print(service.train_model())
