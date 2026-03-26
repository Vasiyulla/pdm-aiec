# PredictXAI: Predictive Maintenance Module (Enterprise)

Welcome to the AI-driven extension of the motor control dashboard. This module integrates real-time sensor monitoring with machine learning to predict potential failures before they occur.

## 🛠️ Technology Stack
- **Frontend**: Flutter (Provider, Material 3, fl_chart)
- **Backend**: Python (FastAPI, Scikit-Learn, Joblib)
- **Engine**: Orchestrated AI Agents (Monitoring, Prediction, Maintenance)

## 🏗️ Architecture Overview

The module uses an **Agent-Based Architecture** where specialized AI agents coordinate for a complete health diagnosis:

1. **Monitoring Agent**: Scans real-time telemetry (Temp, Vibration, Pressure, RPM) against safety thresholds.
2. **Prediction Agent**: Predicts failure probability using a **Random Forest Classifier**.
3. **Alert Agent**: Classifies risk levels (Low, Medium, High, Critical) and maps them to visual alerts.
4. **Maintenance Agent**: Recommends engineering actions (e.g., "Check Bearing Lubrication", "Schedule Immediate Inspection").
5. **Orchestrator**: Consolidates agent outputs into a unified JSON object for the Flutter UI.

## 🚀 Setup & Initialization

### 1. Backend Dependencies
Ensure you have the required ML packages installed:
```bash
pip install pandas scikit-learn joblib numpy
```

### 2. Model Training
Before starting the app, you must generate the initial AI model:
```bash
python motor-backend/app/services/ml_service/train_model.py
```
This generates:
- `data/sensor_data.csv`: Synthetic training dataset.
- `models/failure_model.pkl`: The serialized Random Forest model.

### 3. Running the App
- **Backend**: `uvicorn app.main:app --reload`
- **Frontend**: `flutter run -d windows`

## 📊 Interaction Features
- **AI Dashboard**: High-level health summary and risk distribution charts.
- **Run AI Analysis**: Input current sensor readings to get a real-time diagnosis from the agent's pipeline.
- **Machine Details**: Deep-dive view with performance gauges and 30rd-day health trend history.

## ⚠️ Known Implementation Details
- **Mock Data**: The `machines` list and `history` are currently in a mock state in `app/routers/maintenance.py` and can be easily connected to a database.
- **Agent Tuning**: Thresholds for the **Monitoring Agent** are defined in `app/services/agents/monitoring_agent.py`.
