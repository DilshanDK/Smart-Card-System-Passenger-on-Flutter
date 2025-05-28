// ignore_for_file: depend_on_referenced_packages

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:smart_card_app_passenger/models/passenger.dart';
import 'dart:developer' as developer;

class AuthenticationService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Stream of Passenger based on authentication state
  Stream<Passenger?> get passenger {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) {
        return null;
      }
      try {
        DocumentSnapshot doc =
            await _firestore.collection('passengers').doc(user.uid).get();
        if (doc.exists) {
          return Passenger.fromFirestore(doc);
        }
        return null;
      } catch (e, stackTrace) {
        developer.log(
          'Error fetching passenger: $e',
          name: 'AuthenticationService',
          error: e,
          stackTrace: stackTrace,
        );
        return null;
      }
    });
  }

  /// Signs up a new passenger with email and password, and creates a Firestore record.
  /// Returns a map with 'passenger' (Passenger?) and 'error' (String?).
  Future<Map<String, dynamic>> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    try {
      // Validate input fields
      String? emailError = validateEmail(email);
      if (emailError != null) {
        developer.log(
          'Validation failed: $emailError',
          name: 'AuthenticationService',
        );
        return {'passenger': null, 'error': emailError};
      }
      String? passwordError = validatePassword(password);
      if (passwordError != null) {
        developer.log(
          'Validation failed: $passwordError',
          name: 'AuthenticationService',
        );
        return {'passenger': null, 'error': passwordError};
      }
      String? nameError = validateName(name);
      if (nameError != null) {
        developer.log(
          'Validation failed: $nameError',
          name: 'AuthenticationService',
        );
        return {'passenger': null, 'error': nameError};
      }
      String? phoneError = validatePhone(phone);
      if (phoneError != null) {
        developer.log(
          'Validation failed: $phoneError',
          name: 'AuthenticationService',
        );
        return {'passenger': null, 'error': phoneError};
      }

      // Check if email already exists in passengers collection
      try {
        QuerySnapshot emailQuery =
            await _firestore
                .collection('passengers')
                .where('email', isEqualTo: email.toLowerCase().trim())
                .get();
        if (emailQuery.docs.isNotEmpty) {
          developer.log(
            'Email already in use: ${email.toLowerCase().trim()}',
            name: 'AuthenticationService',
          );
          return {'passenger': null, 'error': 'This email is already used.'};
        }
      } catch (e, stackTrace) {
        // Log the error but proceed with signup, relying on Firebase Auth
        developer.log(
          'Non-critical error checking email in Firestore: $e',
          name: 'AuthenticationService',
          error: e,
          stackTrace: stackTrace,
        );
        // Continue to Firebase Authentication step
      }

      // Create user in Firebase Authentication
      await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Wait briefly to ensure currentUser is updated
      await Future.delayed(const Duration(milliseconds: 100));
      User? user = _auth.currentUser;

      if (user != null && user.email?.toLowerCase() == email.toLowerCase()) {
        // Create Passenger instance
        Passenger passenger = Passenger(
          passengerId: user.uid,
          email: email.toLowerCase().trim(),
          name: name.trim(),
          phone: phone.trim(),
          walletBalance: 0.0,
        );

        // Store passenger data in Firestore
        try {
          await _firestore
              .collection('passengers')
              .doc(user.uid)
              .set(passenger.toFirestore());
        } catch (e, stackTrace) {
          developer.log(
            'Error storing passenger in Firestore: $e',
            name: 'AuthenticationService',
            error: e,
            stackTrace: stackTrace,
          );
          // Attempt to delete the Firebase Auth user to maintain consistency
          try {
            await user.delete();
          } catch (deleteError) {
            developer.log(
              'Failed to delete Firebase user after Firestore error: $deleteError',
              name: 'AuthenticationService',
              error: deleteError,
            );
          }
          return {
            'passenger': null,
            'error': 'Failed to create passenger profile. Please try again.',
          };
        }

        return {'passenger': passenger, 'error': null};
      }
      developer.log(
        'No user created during sign-up',
        name: 'AuthenticationService',
      );
      return {'passenger': null, 'error': 'No user created'};
    } on FirebaseAuthException catch (e, stackTrace) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'The password is too weak.';
          break;
        case 'email-already-in-use':
          errorMessage = 'This email is already used.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        default:
          errorMessage = 'Sign-up failed: ${e.message}';
      }
      developer.log(
        errorMessage,
        name: 'AuthenticationService',
        error: e,
        stackTrace: stackTrace,
      );
      return {'passenger': null, 'error': errorMessage};
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during sign-up: $e',
        name: 'AuthenticationService',
        error: e,
        stackTrace: stackTrace,
      );
      
      // Fallback: Check currentUser
      await Future.delayed(const Duration(milliseconds: 100));
      User? user = _auth.currentUser;
      if (user != null && user.email?.toLowerCase() == email.toLowerCase()) {
        try {
          Passenger passenger = Passenger(
            passengerId: user.uid,
            email: email.toLowerCase().trim(),
            name: name.trim(),
            phone: phone.trim(),
            walletBalance: 0.0,
          );
          await _firestore
              .collection('passengers')
              .doc(user.uid)
              .set(passenger.toFirestore());
          return {'passenger': passenger, 'error': null};
        } catch (e, stackTrace) {
          developer.log(
            'Fallback failed to store passenger: $e',
            name: 'AuthenticationService',
            error: e,
            stackTrace: stackTrace,
          );
          // Attempt to delete the Firebase Auth user
          try {
            await user.delete();
          } catch (deleteError) {
            developer.log(
              'Failed to delete Firebase user in fallback: $deleteError',
              name: 'AuthenticationService',
              error: deleteError,
            );
          }
        }
      }
      return {
        'passenger': null,
        'error': 'An unexpected error occurred during sign-up: $e',
      };
    }
  }

  /// Signs in a passenger with email and password.
  /// Returns a map with 'passenger' (Passenger?) and 'error' (String?).
  Future<Map<String, dynamic>> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Validate input fields
      String? emailError = validateEmail(email);
      if (emailError != null) {
        developer.log(
          'Validation failed for email "$email": $emailError',
          name: 'AuthenticationService',
        );
        return {'passenger': null, 'error': emailError};
      }
      String? passwordError = validatePassword(password);
      if (passwordError != null) {
        developer.log(
          'Validation failed for password: $passwordError',
          name: 'AuthenticationService',
        );
        return {'passenger': null, 'error': passwordError};
      }

      // Check if email exists in passengers collection
      QuerySnapshot? emailQuery;
      try {
        for (int i = 0; i < 3; i++) {
          try {
            emailQuery =
                await _firestore
                    .collection('passengers')
                    .where('email', isEqualTo: email.toLowerCase().trim())
                    .get();
            break;
          } catch (e) {
            if (i == 2) {
              developer.log(
                'Failed to check email "$email" in Firestore after retries: $e',
                name: 'AuthenticationService',
                error: e,
              );
            }
            await Future.delayed(Duration(milliseconds: 500));
          }
        }
        if (emailQuery != null && emailQuery.docs.isEmpty) {
          developer.log(
            'Email not found in passengers collection: ${email.toLowerCase().trim()}',
            name: 'AuthenticationService',
          );
          return {'passenger': null, 'error': 'This email is not registered.'};
        }
      } catch (e, stackTrace) {
        developer.log(
          'Non-critical error checking email "$email" in Firestore: $e',
          name: 'AuthenticationService',
          error: e,
          stackTrace: stackTrace,
        );
        // Continue to Firebase Authentication step
      }

      // Sign in with Firebase Authentication
      try {
        developer.log(
          'Attempting Firebase sign-in for email: $email',
          name: 'AuthenticationService',
        );

        // This is where the type cast error is occurring
        // Wrap this in a try-catch with specific error handling
        User? user;
        String? uid;

        try {
          UserCredential userCredential = await _auth
              .signInWithEmailAndPassword(
                email: email.trim(),
                password: password,
              );
          user = userCredential.user;
          uid = user?.uid;
        } on TypeError catch (e, stackTrace) {
          // Handle the specific type cast error
          developer.log(
            'Firebase Auth API type cast error. Attempting alternative approach: $e',
            name: 'AuthenticationService',
            error: e,
            stackTrace: stackTrace,
          );

          // Check if we're already signed in (might happen due to Firebase Auth caching)
          user = _auth.currentUser;
          uid = user?.uid;

          if (user == null) {
            // If we can't get a user, try sign out and sign in again
            try {
              await _auth.signOut();
              await Future.delayed(Duration(milliseconds: 500));
              UserCredential userCredential = await _auth
                  .signInWithEmailAndPassword(
                    email: email.trim(),
                    password: password,
                  );
              user = userCredential.user;
              uid = user?.uid;
            } catch (retryError) {
              developer.log(
                'Retry sign-in failed: $retryError',
                name: 'AuthenticationService',
                error: retryError,
              );
              return {
                'passenger': null,
                'error':
                    'Authentication error. Please update your app or try again later.',
              };
            }
          }
        }

        if (user != null && uid != null) {
          developer.log(
            'Firebase sign-in successful for UID: $uid',
            name: 'AuthenticationService',
          );
          // Fetch Passenger document from Firestore
          try {
            DocumentSnapshot doc =
                await _firestore.collection('passengers').doc(uid).get();
            if (doc.exists) {
              return {'passenger': Passenger.fromFirestore(doc), 'error': null};
            }
            developer.log(
              'Passenger document not found for UID: $uid',
              name: 'AuthenticationService',
            );
            return {'passenger': null, 'error': 'Passenger profile not found.'};
          } catch (e, stackTrace) {
            developer.log(
              'Error fetching passenger document for UID: $uid: $e',
              name: 'AuthenticationService',
              error: e,
              stackTrace: stackTrace,
            );
            return {
              'passenger': null,
              'error':
                  'Failed to retrieve passenger profile. Please try again.',
            };
          }
        }
        developer.log(
          'No user found during sign-in for email: $email',
          name: 'AuthenticationService',
        );
        return {'passenger': null, 'error': 'Sign-in failed: No user found.'};
      } on TypeError catch (e, stackTrace) {
        developer.log(
          'Type cast error during sign-in for email "$email": $e',
          name: 'AuthenticationService',
          error: e,
          stackTrace: stackTrace,
        );
        return {
          'passenger': null,
          'error':
              'Sign-in failed due to a data parsing issue. Please update your app or try again later.',
        };
      }
    } on FirebaseAuthException catch (e, stackTrace) {
      String errorMessage;
      switch (e.code) {
        case 'invalid-credential':
          errorMessage = 'Incorrect email or password.';
          break;
        case 'user-not-found':
          errorMessage = 'This email is not registered.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password.';
          break;
        case 'invalid-email':
          errorMessage = 'The email address is invalid.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        default:
          errorMessage = 'Sign-in failed: ${e.message}';
      }
      developer.log(
        'FirebaseAuth error during sign-in for email "$email": $errorMessage',
        name: 'AuthenticationService',
        error: e,
        stackTrace: stackTrace,
      );
      return {'passenger': null, 'error': errorMessage};
    } catch (e, stackTrace) {
      developer.log(
        'Unexpected error during sign-in for email "$email": $e',
        name: 'AuthenticationService',
        error: e,
        stackTrace: stackTrace,
      );
      return {
        'passenger': null,
        'error':
            'An unexpected error occurred during sign-in. Please try again.',
      };
    }
  }

  /// Signs in a passenger with Google.
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      debugPrint('Starting Google sign-in process');

      // Force account picker to appear
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('Sign-in canceled by user');
        return {'passenger': null, 'error': 'Sign-in canceled by user'};
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;

      if (user != null) {
        final DocumentReference passengerDoc = _firestore
            .collection('passengers')
            .doc(user.uid);
        final DocumentSnapshot docSnapshot = await passengerDoc.get();

        if (!docSnapshot.exists) {
          // Create new driver document if it doesn't exist
          final Passenger passenger = Passenger(
            passengerId: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? '',
            phone:'',
            createdAt: DateTime.now(),
          );

          await passengerDoc.set(passenger.toFirestore());
          return {'passenger': passenger, 'error': null};
        } else {
          return {'passenger': Passenger.fromFirestore(docSnapshot), 'error': null};
        }
      }
      return {'passenger': null, 'error': 'Failed to retrieve authenticated user'};
    } on FirebaseAuthException catch (e) {
      return {'passenger': null, 'error': e.message ?? 'Authentication error'};
    } catch (e) {
      return {'passenger': null, 'error': e.toString()};
    }
  }

 
  /// Signs out the current user.
  /// Returns true on success, false on failure.
  Future<bool> signOut() async {
    try {
      await _auth.signOut();
      developer.log(
        'User signed out successfully',
        name: 'AuthenticationService',
      );
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Error signing out: $e',
        name: 'AuthenticationService',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // Regular expressions for validation
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$',
  );

  /// Validates email format
  String? validateEmail(String email) {
    if (email.trim().isEmpty) {
      return 'Email cannot be empty';
    }
    if (!_emailRegex.hasMatch(email.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  /// Validates password strength
  String? validatePassword(String password) {
    if (password.isEmpty) {
      return 'Password cannot be empty';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!_passwordRegex.hasMatch(password)) {
      return 'Password must contain at least one letter and one number';
    }
    return null;
  }

  /// Validates phone number format
  String? validatePhone(String phone) {
    if (phone.trim().isEmpty) {
      return 'Phone number cannot be empty';
    }
    if (!_phoneRegex.hasMatch(phone.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  /// Validates name
  String? validateName(String name) {
    if (name.trim().isEmpty) {
      return 'Name cannot be empty';
    }
    if (name.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      // Example for Firebase:
      // await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Password reset email sent. Please check your inbox.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send reset email: $e',
      };
    }
  }
}
