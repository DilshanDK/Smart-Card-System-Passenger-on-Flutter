// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, depend_on_referenced_packages, deprecated_member_use

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_card_app_passenger/themes/colors.dart';
import 'package:smart_card_app_passenger/models/wallet.dart'; // Updated model
import 'package:uuid/uuid.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _cvvController = TextEditingController();
  final _expiryMonthController = TextEditingController();
  final _expiryYearController = TextEditingController();
  final _cardHolderController = TextEditingController();
  bool _isSubmitting = false;
  
  // Predefined quick amounts
  final List<double> _quickAmounts = [100, 200, 500, 1000];
  double? _selectedAmount;

  @override
  void initState() {
    super.initState();
    // Monitor input changes for real-time validation
    for (final controller in [
      _amountController,
      _cardNumberController,
      _cvvController,
      _expiryMonthController,
      _expiryYearController,
      _cardHolderController,
    ]) {
      controller.addListener(_updateFormState);
    }
  }

  @override
  void dispose() {
    // Clean up controllers
    _amountController.dispose();
    _cardNumberController.dispose();
    _cvvController.dispose();
    _expiryMonthController.dispose();
    _expiryYearController.dispose();
    _cardHolderController.dispose();
    super.dispose();
  }

  void _updateFormState() => setState(() {});

  bool get _isFormValid => _formKey.currentState?.validate() ?? false;

  void _selectQuickAmount(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = amount.toString();
    });
  }

  Future<void> _processPayment() async {
    if (!_isFormValid) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('Please sign in to top up your wallet.', Colors.red);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Simulate payment processing with loading animation
      await Future.delayed(const Duration(seconds: 2));

      final amount = double.parse(_amountController.text.trim());
      final passengerId = user.uid;

      // Execute Firestore updates atomically
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final passengerRef = FirebaseFirestore.instance
            .collection('passengers')
            .doc(passengerId);
        final transactionId = const Uuid().v4();
        final transactionRef = FirebaseFirestore.instance
            .collection('transactions')
            .doc(transactionId);

        // Update wallet balance
        transaction.set(passengerRef, {
          'walletBalance': FieldValue.increment(amount),
          'passengerId': passengerId,
          'lastTopUp': Timestamp.now(),
        }, SetOptions(merge: true));

        // Record transaction
        final wallet = Wallet(
          transactionId: transactionId,
          passengerId: passengerId,
          amount: amount,
          status: 'completed',
        );
        
        // Get the wallet data as a map
        Map<String, dynamic> walletData = wallet.toFirestore();
        
        // Add the new attribute with default value "E-Wallet TopUp"
        walletData['description'] = 'E-Wallet TopUp';
        walletData['type'] = 'topup';
        walletData['timestamp'] = Timestamp.now(); // Add timestamp for consistency
        
        // Set the transaction document with all the data
        transaction.set(transactionRef, walletData);
      });

      _showSuccessDialog(amount);
      _clearForm();
    } catch (e) {
      _handleError(e);
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(double amount) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.accentGreen,
              size: 80,
            ),
            const SizedBox(height: 20),
            Text(
              'Top-Up Successful!',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Rs. ${amount.toStringAsFixed(2)} has been added to your wallet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text(
                'Done',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _handleError(Object error) {
    String message = error.toString().replaceFirst('Exception: ', '');
    if (error is FirebaseException) {
      message = 'Firebase error: ${error.message}';
    } else if (error is TimeoutException) {
      message = 'Request timed out. Please try again.';
    }
    _showSnackBar(message, Colors.red);
  }

  void _clearForm() {
    setState(() {
      _amountController.clear();
      _cardNumberController.clear();
      _cvvController.clear();
      _expiryMonthController.clear();
      _expiryYearController.clear();
      _cardHolderController.clear();
      _selectedAmount = null;
    });
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(color: AppColors.grey600),
      hintStyle: GoogleFonts.inter(color: AppColors.grey600.withOpacity(0.5)),
      prefixIcon: Icon(icon, color: AppColors.primaryDark),
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.accentGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.shade300, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required String? Function(String?) validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: _buildInputDecoration(label, icon, hint: hint),
        style: GoogleFonts.inter(fontSize: 16, color: AppColors.primaryDark),
        validator: validator,
        onChanged: (_) => _updateFormState(),
      ),
    );
  }

  Widget _buildAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Amount',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 16),
        
        // Quick amount selection chips
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _quickAmounts.map((amount) {
            final isSelected = _selectedAmount == amount;
            return InkWell(
              onTap: () => _selectQuickAmount(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primaryDark : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryDark : Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Rs. ${amount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.primaryDark,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        
        // Custom amount input
        _buildTextFormField(
          controller: _amountController,
          label: 'Custom Amount',
          hint: 'Enter amount in Rs.',
          icon: Icons.account_balance_wallet,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value?.trim().isEmpty ?? true) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value!);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid positive amount';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCardSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Text(
                'Payment Method',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 20),

          // Card number
          _buildTextFormField(
            controller: _cardNumberController,
            label: 'Card Number',
            hint: 'XXXX XXXX XXXX XXXX',
            icon: Icons.credit_card,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(16),
              _CardNumberInputFormatter(),
            ],
            validator: (value) {
              if (value == null || value.replaceAll(' ', '').length != 16) {
                return 'Please enter a 16-digit card number';
              }
              return null;
            },
          ),

          // Cardholder name
          _buildTextFormField(
            controller: _cardHolderController,
            label: 'Card Holder Name',
            hint: 'Name on card',
            icon: Icons.person,
            keyboardType: TextInputType.name,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the cardholder name';
              }
              return null;
            },
          ),

          // Expiry date and CVV
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTextFormField(
                        controller: _expiryMonthController,
                        label: 'MM',
                        hint: 'MM',
                        icon: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'MM';
                          }
                          final month = int.tryParse(value!);
                          if (month == null || month < 1 || month > 12) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextFormField(
                        controller: _expiryYearController,
                        label: 'YY',
                        hint: 'YY',
                        icon: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        validator: (value) {
                          if (value?.trim().isEmpty ?? true) {
                            return 'YY';
                          }
                          final year = int.tryParse(value!);
                          final currentYear = DateTime.now().year % 100; // Get last 2 digits
                          if (year == null || year < currentYear) {
                            return 'Invalid';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: _buildTextFormField(
                  controller: _cvvController,
                  label: 'CVV',
                  hint: '•••',
                  icon: Icons.lock,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().length != 3) {
                      return 'Enter 3-digit CVV';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 20),
      child: ElevatedButton(
        onPressed: _isSubmitting || !_isFormValid ? null : _processPayment,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          disabledBackgroundColor: Colors.grey.shade300,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSubmitting
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'PAY NOW',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.security, color: Colors.greenAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your payment information is encrypted and secure. We do not store your card details.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.grey600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
    
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Top Up Your Wallet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add funds using your bank card',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildAmountSection(),
                _buildCardSection(),
                _buildSecurityInfo(),
                _buildPaymentButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Custom formatter for card number (adds spaces every 4 digits)
class _CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    if (text.length > 16) return oldValue;

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) {
        buffer.write(' ');
      }
    }

    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}