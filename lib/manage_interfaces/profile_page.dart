// Example: profile_page.dart

// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:smart_card_app_passenger/services/auth_service.dart';
import 'package:smart_card_app_passenger/auth_interfaces/sign_in_page.dart';
import 'package:smart_card_app_passenger/services/firestore_service.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthenticationService _auth = AuthenticationService();
  final FirestoreService firestoreService = FirestoreService();

  String? name;
  String? email;
  String? phone;
  String? nfcId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPassengerData();
  }

  Future<void> _fetchPassengerData() async {
    setState(() => _isLoading = true);
    try {
      final data = await firestoreService.fetchPassengerData();
      if (data != null) {
        setState(() {
          name = data['name'] ?? 'Unknown';
          email = data['email'] ?? 'Unknown';
          phone = data['phone'] ?? 'Unknown';
          nfcId = 'NFC-${data['uid'] ?? ''}';
          _isLoading = false;
        });
      } else {
        throw Exception('No data found.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching profile: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(String updatedName, String updatedPhone) async {
    try {
      await firestoreService.updatePassengerProfile(
        updatedName: updatedName,
        updatedPhone: updatedPhone,
      );
      setState(() {
        name = updatedName;
        phone = updatedPhone;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is Exception ? e.toString().replaceFirst('Exception: ', '') : 'Error updating profile.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: name);
    final phoneController = TextEditingController(text: phone);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Profile', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedName = nameController.text.trim();
              final updatedPhone = phoneController.text.trim();
              // No need to check empty here, delegates to service
              Navigator.pop(context);
              await _updateProfile(updatedName, updatedPhone);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color.fromRGBO(40, 49, 56, 1),
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Profile',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color.fromRGBO(40, 49, 56, 1),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your account details',
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 30),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildProfileRow('Name', name ?? 'Unknown', Icons.person_outline),
                          const Divider(height: 20),
                          _buildProfileRow('Email', email ?? 'Unknown', Icons.email_outlined),
                          const Divider(height: 20),
                          _buildProfileRow('Phone', phone ?? 'Unknown', Icons.phone),
                          const Divider(height: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _showEditProfileDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(40, 49, 56, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Edit Profile',
                      style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        await _auth.signOut();
                        if (mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SignInPage()),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error signing out: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color.fromRGBO(40, 49, 56, 1)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w500, color: const Color.fromRGBO(40, 49, 56, 1)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}