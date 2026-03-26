import datetime
from .monitoring_agent import MonitoringAgent
from .prediction_agent import PredictionAgent
from .alert_agent import AlertAgent, MaintenanceRecommendationAgent

class AgentOrchestrator:
    def __init__(self):
        self.monitoring_agent = MonitoringAgent()
        self.prediction_agent = PredictionAgent()
        self.alert_agent = AlertAgent()
        self.maintenance_agent = MaintenanceRecommendationAgent()

    def analyze_machine(self, machine_id: str, sensor_data: dict):
        """
        Runs the full diagnostic pipeline for a machine.
        """
        # 1. Detect Anomalies
        anomalies = self.monitoring_agent.analyze(sensor_data)
        
        # 2. Get ML Prediction
        prediction_res = self.prediction_agent.predict(sensor_data)
        risk_level = prediction_res["risk_level"]
        prob = prediction_res["failure_probability"]
        
        # 3. Generate Alert
        alert = self.alert_agent.map_risk_to_alert(risk_level, anomalies)
        
        # 4. Get Maintenance Recommendation
        recommendation = self.maintenance_agent.recommend(risk_level, anomalies)
        
        return {
            "machine_id": machine_id,
            "risk_level": risk_level,
            "failure_probability": prob,
            "anomalies": anomalies,
            "alert": alert,
            "recommendation": recommendation,
            "timestamp": datetime.datetime.now().isoformat()
        }

if __name__ == "__main__":
    # Test Orchestrator
    orch = AgentOrchestrator()
    data = {"temperature": 92.0, "vibration": 8.5, "pressure": 12.0, "rpm": 1450}
    print(orch.analyze_machine("M-001", data))
