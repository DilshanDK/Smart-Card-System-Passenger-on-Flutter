// ignore_for_file: use_super_parameters, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart'; // Add this import
import 'package:smart_card_app_passenger/models/passenger.dart';
import 'package:provider/provider.dart';
import 'package:smart_card_app_passenger/services/auth_service.dart';
import 'package:smart_card_app_passenger/wrapper.dart';

import 'firebase_options.dart';
import 'dart:developer' as developer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    developer.log('Firebase initialized successfully', name: 'main');

    // Initialize Stripe
    Stripe.publishableKey = 'pk_test_51R0OwjP15ohPYwKrOvT50NvATSDmhX5VELrALHk4oydanBt88vPnzGo9MZQkvS6ikukyO8ZZLkfkiT2mA1goc3bV00yow3gCmw'; // Replace with your Stripe Publishable Key
    await Stripe.instance.applySettings();
    developer.log('Stripe initialized successfully', name: 'main');

    runApp(const MyApp());
  } catch (e, stackTrace) {
    developer.log('Initialization failed: $e',
        name: 'main', error: e, stackTrace: stackTrace);
    runApp(ErrorApp(message: 'Failed to initialize: $e'));
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamProvider<Passenger?>.value(
      initialData: null,
      value: AuthenticationService().passenger,
      child: MaterialApp(
        home: const Wrapper(),
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String message;
  const ErrorApp({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ErrorScreen(message: message),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String message;
  const ErrorScreen({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error: $message',
              style: const TextStyle(fontSize: 18, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}