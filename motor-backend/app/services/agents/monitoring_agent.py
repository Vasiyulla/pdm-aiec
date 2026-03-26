import datetime

class MonitoringAgent:
    """
    Evaluates live sensor data against safety thresholds to detect anomalies.
    """
    THRESHOLDS = {
        "temperature": 75.0,  # Celsius
        "vibration": 4.5,    # mm/s (RMS)
        "pressure": 12.0,    # Bar
        "voltage": 250.0,    # Volts
        "current": 8.0       # Amps
    }

    def analyze(self, sensor_data: dict) -> list:
        anomalies = []
        for sensor, value in sensor_data.items():
            threshold = self.THRESHOLDS.get(sensor)
            if threshold and value > threshold:
                anomalies.append(f"High {sensor.capitalize()}: {value} (Limit: {threshold})")
        return anomalies

if __name__ == "__main__":
    # Test
    agent = MonitoringAgent()
    data = {"temperature": 82.5, "vibration": 2.1, "rpm": 1450}
    print(f"Anomalies: {agent.analyze(data)}")
