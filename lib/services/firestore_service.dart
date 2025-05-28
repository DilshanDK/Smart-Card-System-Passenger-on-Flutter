// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{10}$');

  /// Validate phone number (must be exactly 10 digits)
  String? validatePhone(String phone) {
    if (phone.trim().isEmpty) {
      return 'Phone number cannot be empty';
    }
    if (!_phoneRegex.hasMatch(phone.trim())) {
      return 'Phone number must be exactly 10 digits';
    }
    return null;
  }

  /// Validate name
  String? validateName(String name) {
    if (name.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchPassengerData() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found.');
      }
      final DocumentSnapshot doc =
          await _firestore.collection('passengers').doc(user.uid).get();
      if (!doc.exists) {
        throw Exception('Passenger document does not exist.');
      }
      return doc.data() as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Error fetching passenger data: $e');
    }
  }

  Future<void> updatePassengerProfile({
    required String updatedName,
    required String updatedPhone,
  }) async {
    // Validate input
    final nameError = validateName(updatedName);
    final phoneError = validatePhone(updatedPhone);
    final user = _auth.currentUser;

    if (nameError != null) throw Exception(nameError);
    if (phoneError != null) throw Exception(phoneError);
    if (user == null) throw Exception('No authenticated user found.');

    final updateData = <String, dynamic>{
      'name': updatedName,
      'phone': updatedPhone,
    };

    // Update Firestore
    try {
      await _firestore
          .collection('passengers')
          .doc(user.uid)
          .update(updateData);
    } catch (e) {
      throw Exception('Error updating passenger profile: $e');
    }
  }
}
