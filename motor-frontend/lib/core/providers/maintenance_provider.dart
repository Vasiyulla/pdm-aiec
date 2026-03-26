import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MaintenanceModel {
  final String machineId;
  final String riskLevel;
  final double failureProbability;
  final List<String> anomalies;
  final Map<String, dynamic> alert;
  final String recommendation;
  final DateTime timestamp;

  MaintenanceModel({
    required this.machineId,
    required this.riskLevel,
    required this.failureProbability,
    required this.anomalies,
    required this.alert,
    required this.recommendation,
    required this.timestamp,
  });

  factory MaintenanceModel.fromJson(Map<String, dynamic> json) {
    return MaintenanceModel(
      machineId: json['machine_id'] ?? 'Unknown',
      riskLevel: json['risk_level'] ?? 'Low',
      failureProbability: (json['failure_probability'] ?? 0.0).toDouble(),
      anomalies: List<String>.from(json['anomalies'] ?? []),
      alert: Map<String, dynamic>.from(json['alert'] ?? {}),
      recommendation: json['recommendation'] ?? 'Normal Operation',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class MaintenanceProvider with ChangeNotifier {
  final String baseUrl = "http://localhost:8000/predictive"; // Update for production
  
  List<Map<String, dynamic>> _machines = [];
  MaintenanceModel? _latestAnalysis;
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get machines => _machines;
  MaintenanceModel? get latestAnalysis => _latestAnalysis;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchMachines() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('$baseUrl/machines'));
      if (response.statusCode == 200) {
        _machines = List<Map<String, dynamic>>.from(json.decode(response.body));
        _error = null;
      } else {
        _error = "Failed to load machines: ${response.statusCode}";
      }
    } catch (e) {
      _error = "Connection error: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> runAnalysis(String machineId, Map<String, double> sensors) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/analyze'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "machine_id": machineId,
          "temperature": sensors['temperature'],
          "vibration": sensors['vibration'],
          "pressure": sensors['pressure'],
          "rpm": sensors['rpm'],
        }),
      );
      if (response.statusCode == 200) {
        _latestAnalysis = MaintenanceModel.fromJson(json.decode(response.body));
      } else {
        _error = "Analysis failed: ${response.statusCode}";
      }
    } catch (e) {
      _error = "Failed to run analysis: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
