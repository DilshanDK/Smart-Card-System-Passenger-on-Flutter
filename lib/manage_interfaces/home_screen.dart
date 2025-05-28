// ignore_for_file: library_private_types_in_public_api, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:smart_card_app_passenger/manage_interfaces/home_page.dart';
import 'package:smart_card_app_passenger/themes/colors.dart'; // Adjusted to singular 'theme'
import 'package:google_fonts/google_fonts.dart';
import 'tracking_page.dart';
import 'payment_page.dart';
import 'profile_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
     TrackingPage(),
    const PaymentPage(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white, // Use from AppColors
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark, // Use from AppColors
        title: Text(
          'Smart Card Dashboard',
          style: GoogleFonts.inter(
            fontSize: 24,
            color: AppColors.white, // Use from AppColors
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppColors.primaryDark, // Use primaryDark for active items
        unselectedItemColor: AppColors.grey600, // Use grey600 for inactive items
        backgroundColor: AppColors.white, // Keep from AppColors
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.primaryDark, // Match selected item color
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppColors.grey600, // Match unselected item color
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.track_changes), label: 'Tracking'),
          BottomNavigationBarItem(icon: Icon(Icons.payment), label: 'Payment'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}