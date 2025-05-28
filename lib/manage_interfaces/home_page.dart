// ignore_for_file: library_private_types_in_public_api, deprecated_member_use, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_card_app_passenger/themes/colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? firstName;
  String? fullName;
  double? walletBalance;
  String? passengerIdMasked;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPassengerData();
  }

  Future<void> fetchPassengerData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('passengers')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data();
        final name = data?['name'] ?? '';
        final balance = data?['walletBalance'];
        final pid = data?['passengerId']?.toString() ?? '';
        String? maskedPid;
        if (pid.isNotEmpty) {
          // Always show 5 stars and then the last 5 characters (or the whole pid if less than 5).
          final pidUpper = pid.toUpperCase();
          final last5 = pidUpper.length > 5
              ? pidUpper.substring(pidUpper.length - 5)
              : pidUpper;
          maskedPid = '********$last5';
        } else {
          maskedPid = '-----';
        }
        setState(() {
          fullName = name;
          firstName = (name is String && name.isNotEmpty)
              ? name.split(' ').first
              : null;
          walletBalance = (balance is num) ? balance.toDouble() : 0.0;
          passengerIdMasked = maskedPid;
          isLoading = false;
        });
        return;
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _refreshData() async {
    await fetchPassengerData();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppColors.accentGreen,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                isLoading ? 'Loading...' : 'Welcome, ${firstName ?? "Passenger"}!',
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Manage your passenger profile',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: AppColors.grey600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              color: AppColors.primaryDark,
              child: Container(
                width: double.infinity,
                height: 200,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Smart Card',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isLoading
                          ? 'Loading...'
                          : (passengerIdMasked ?? '-----'),
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const Spacer(),
                    Text(
                      'Wallet Balance',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      isLoading
                          ? 'Loading...'
                          : (walletBalance != null
                              ? 'Rs. ${walletBalance!.toStringAsFixed(2)}'
                              : 'N/A'),
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            if (isLoading)
              const Center(child: CircularProgressIndicator(color: AppColors.accentGreen))
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Passenger Information',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (!isLoading)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                color: AppColors.shadowGreen,
                child: ListTile(
                  leading: Icon(
                    Icons.person,
                    color: AppColors.primaryDark,
                  ),
                  title: Text(
                    'Full Name',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  subtitle: Text(
                    fullName ?? 'Passenger',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.primaryDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.accentGreen,
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Passenger Profile: ${fullName ?? "Passenger"}'),
                        backgroundColor: AppColors.accentGreen,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}