// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore/cloud_firestore.dart';

class Wallet {
  final String transactionId;  // Firestore document ID
  final String passengerId;    // Reference to passenger
  final double amount;        // Positive transaction amount
  final DateTime timestamp;    // Transaction time
  final String status;        // Transaction state

  Wallet({
    required this.transactionId,
    required this.passengerId,
    required this.amount,
    DateTime? timestamp,
    this.status = 'pending',
  }) : timestamp = timestamp ?? DateTime.now(),
       assert(amount >= 0, 'Transaction amount cannot be negative');

  factory Wallet.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Wallet(
      transactionId: doc.id,
      passengerId: data['passengerId']?.toString() ?? data['userId']?.toString() ?? '',
      amount: (data['amount'] as num?)?.abs().toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: _validateStatus(data['status']?.toString()),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'passengerId': passengerId,
      'amount': amount,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
    };
  }

  // Helper methods
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';

  static String _validateStatus(String? status) {
    const validStatuses = ['pending', 'completed', 'failed', 'refunded'];
    return validStatuses.contains(status?.toLowerCase()) ? status!.toLowerCase() : 'pending';
  }

  Wallet copyWith({
    String? status,
    double? amount,
  }) {
    return Wallet(
      transactionId: transactionId,
      passengerId: passengerId,
      amount: amount ?? this.amount,
      timestamp: timestamp,
      status: status ?? this.status,
    );
  }
}