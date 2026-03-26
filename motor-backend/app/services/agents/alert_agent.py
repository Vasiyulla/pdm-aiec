class AlertAgent:
    def map_risk_to_alert(self, risk_level: str, anomalies: list):
        severity = "Info"
        message = "All machine systems are operating within normal parameters."

        if risk_level == "Critical":
            severity = "Critical"
            message = "IMMEDIATE ATTENTION REQUIRED: High failure probability detected."
        elif risk_level == "High":
            severity = "Warning"
            message = "High risk detected. Schedule inspection soon."
        elif risk_level == "Medium":
            severity = "Warning"
            message = "Moderate stability issues detected. Monitoring increased."
        elif anomalies:
            severity = "Info"
            message = f"Minor anomalies detected: {', '.join(anomalies[:2])}..."

        return {"severity": severity, "message": message}

class MaintenanceRecommendationAgent:
    def recommend(self, risk_level: str, anomalies: list):
        if risk_level == "Critical":
            return "Emergency Shutdown & Immediate Maintenance"
        elif risk_level == "High":
            return "Urgent Inspection & Component Replacement"
        elif risk_level == "Medium":
            return "Schedule Routine Maintenance & Recalibrate Sensors"
        elif anomalies:
            return "Conduct Visual Inspection"
        return "Normal Operation"
