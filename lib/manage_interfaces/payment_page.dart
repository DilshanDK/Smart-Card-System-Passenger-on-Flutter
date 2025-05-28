// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_card_app_passenger/themes/colors.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  _PaymentPageState createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;

  Future<void> _simulateTopUp() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Simulate a delay for the action
      await Future.delayed(const Duration(seconds: 1));

      // Validate input
      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        throw Exception('Please enter an amount');
      }
      final amountDouble = double.tryParse(amountText);
      if (amountDouble == null || amountDouble <= 0) {
        throw Exception('Please enter a valid positive amount');
      }

      // Handle success
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Top-up of \$${amountDouble.toStringAsFixed(2)} successful!',
            style: GoogleFonts.inter(color: AppColors.white),
          ),
          backgroundColor: AppColors.accentGreen,
        ),
      );
    } catch (e) {
      String errorMessage;
      if (e is FormatException) {
        errorMessage = 'Invalid input: Please enter a valid number.';
      } else {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: GoogleFonts.inter(color: AppColors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool _isValidAmount() {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    return amount != null && amount > 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Top Up Wallet',
              style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Add funds using your bank card',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.grey600,
              ),
            ),
            const SizedBox(height: 30),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              color: AppColors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.credit_card,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Bank Card',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Top-Up Amount (USD)',
                        labelStyle: GoogleFonts.inter(color: AppColors.grey600),
                        prefixIcon: Icon(
                          Icons.attach_money,
                          color: AppColors.primaryDark,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primaryDark),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.accentGreen),
                        ),
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        color: AppColors.primaryDark,
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _isLoading || !_isValidAmount() ? null : _simulateTopUp,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: AppColors.white,
                    )
                  : Text(
                      'Top Up Now',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: AppColors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}