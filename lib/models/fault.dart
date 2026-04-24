// Import this at the top of the file
import 'package:flutter/material.dart';

class Fault {
  final String id;
  final String poleId;
  final String faultType;
  final int priorityScore;
  final double? voltageDrop;
  final double? currentSpike;
  final bool vibrationDetected;
  final String status;
  final DateTime detectedAt;
  final String? assignedTo;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  // Pole information (joined data)
  final String? poleNumber;
  final String? locationName;
  final double? latitude;
  final double? longitude;

  Fault({
    required this.id,
    required this.poleId,
    required this.faultType,
    required this.priorityScore,
    this.voltageDrop,
    this.currentSpike,
    required this.vibrationDetected,
    required this.status,
    required this.detectedAt,
    this.assignedTo,
    this.resolvedAt,
    this.resolutionNotes,
    this.poleNumber,
    this.locationName,
    this.latitude,
    this.longitude,
  });

  factory Fault.fromJson(Map<String, dynamic> json) {
    final poleData = json['poles'] as Map<String, dynamic>?;

    return Fault(
      id: json['id']?.toString() ?? '',
      poleId: json['pole_id']?.toString() ?? '',
      faultType: json['fault_type']?.toString() ?? '',
      priorityScore: (json['priority_score'] as num?)?.toInt() ?? 0,
      voltageDrop: (json['voltage_drop'] as num?)?.toDouble(),
      currentSpike: (json['current_spike'] as num?)?.toDouble(),
      vibrationDetected: json['vibration_detected'] ?? false,
      status: json['status']?.toString() ?? '',
      detectedAt: json['detected_at'] != null
          ? DateTime.parse(json['detected_at'])
          : DateTime.now(),
      assignedTo: json['assigned_to']?.toString(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      resolutionNotes: json['resolution_notes']?.toString(),
      poleNumber: poleData?['pole_number']?.toString(),
      locationName: poleData?['location_name']?.toString(),
      latitude: (poleData?['latitude'] as num?)?.toDouble(),
      longitude: (poleData?['longitude'] as num?)?.toDouble(),
    );
  }

  String get faultTypeDisplay {
    switch (faultType) {
      case 'voltage_drop':
        return 'Voltage Drop';
      case 'current_leakage':
        return 'Current Leakage';
      case 'wire_break':
        return 'Wire Break';
      case 'overload':
        return 'Overload';
      case 'transformer_fault':
        return 'Transformer Fault';
      default:
        return faultType;
    }
  }

  String get priorityDisplay {
    if (priorityScore >= 9) return 'CRITICAL';
    if (priorityScore >= 7) return 'HIGH';
    if (priorityScore >= 5) return 'MEDIUM';
    return 'LOW';
  }

  Color get priorityColor {
    if (priorityScore >= 9) {
      return const Color(0xFFD32F2F); // Red
    } else if (priorityScore >= 7) {
      return const Color(0xFFF57C00); // Orange
    } else if (priorityScore >= 5) {
      return const Color(0xFFFBC02D); // Yellow
    } else {
      return const Color(0xFF388E3C); // Green
    }
  }

  bool get isResolved => status.toLowerCase() == 'resolved';
}