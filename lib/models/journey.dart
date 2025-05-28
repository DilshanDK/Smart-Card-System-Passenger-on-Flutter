// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore/cloud_firestore.dart';

class Journey {
  final String journeyId;         // Firestore document ID
  final String passengerId;      // Reference to passenger document
  final GeoPoint startLocation;  // Journey starting point
  final DateTime startTimestamp; // When journey began
  final GeoPoint? endLocation;   // Journey end point (nullable)
  final DateTime? endTimestamp;  // When journey ended (nullable)
  final String routeId;          // Reference to route document
  final double totalCost;        // Calculated journey cost

  Journey({
    required this.journeyId,
    required this.passengerId,
    required this.startLocation,
    required this.startTimestamp,
    this.endLocation,
    this.endTimestamp,
    required this.routeId,
    required this.totalCost,
  });

  factory Journey.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Journey(
      journeyId: doc.id,
      passengerId: data['userId']?.toString() ?? data['passengerId']?.toString() ?? '',
      startLocation: data['startLocation'] as GeoPoint? ?? const GeoPoint(0.0, 0.0),
      startTimestamp: (data['startTimestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endLocation: data['endLocation'] as GeoPoint?,
      endTimestamp: (data['endTimestamp'] as Timestamp?)?.toDate(),
      routeId: data['routeId']?.toString() ?? '',
      totalCost: (data['totalCost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': passengerId, // Maintaining backward compatibility
      'passengerId': passengerId, // New field name
      'startLocation': startLocation,
      'startTimestamp': Timestamp.fromDate(startTimestamp),
      if (endLocation != null) 'endLocation': endLocation,
      if (endTimestamp != null) 'endTimestamp': Timestamp.fromDate(endTimestamp!),
      'routeId': routeId,
      'totalCost': totalCost,
    };
  }

  // Helper methods
  bool get isCompleted => endLocation != null && endTimestamp != null;
  Duration? get duration => endTimestamp?.difference(startTimestamp);

  Journey copyWith({
    GeoPoint? endLocation,
    DateTime? endTimestamp,
    String? status,
    double? totalCost,
  }) {
    return Journey(
      journeyId: journeyId,
      passengerId: passengerId,
      startLocation: startLocation,
      startTimestamp: startTimestamp,
      endLocation: endLocation ?? this.endLocation,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      routeId: routeId,
      totalCost: totalCost ?? this.totalCost
    );
  }
}