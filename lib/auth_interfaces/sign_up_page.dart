// ignore_for_file: use_build_context_synchronously, deprecated_member_use, depend_on_referenced_packages

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smart_card_app_passenger/auth_interfaces/sign_in_page.dart';
import 'package:smart_card_app_passenger/manage_interfaces/home_screen.dart';
import 'package:smart_card_app_passenger/services/auth_service.dart';
import 'package:smart_card_app_passenger/themes/colors.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _passwordVisible = false;
  bool _isLoading = false;
  final AuthenticationService _auth = AuthenticationService();
  
  // Error text for form fields
  String? _nameError;
  String? _emailError;
  String? _phoneError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppColors.accentGreen,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Validate input fields
  void _validateFields() {
    setState(() {
      _nameError = _auth.validateName(_nameController.text);
      _emailError = _auth.validateEmail(_emailController.text);
      _phoneError = _auth.validatePhone(_phoneController.text);
      _passwordError = _auth.validatePassword(_passwordController.text);
    });
  }

  // Check if all fields are valid
  bool _areFieldsValid() {
    return _nameError == null && 
           _emailError == null && 
           _phoneError == null && 
           _passwordError == null;
  }

  // Handle sign up
  Future<void> _handleSignUp() async {
    _validateFields();
    
    if (!_areFieldsValid()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final result = await _auth.signUpWithEmailAndPassword(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      if (result['error'] != null) {
        _showSnackBar(result['error'], isError: true);
      } else if (result['passenger'] != null) {
        _showSnackBar('Sign up successful');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HomeScreen(),
          ),
        );
      } else {
        _showSnackBar('Sign up failed for unknown reason', isError: true);
      }
    } catch (e) {
      _showSnackBar('An unexpected error occurred: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        title: Text(
          'Smart Card System',
          style: GoogleFonts.inter(
            fontSize: 24,
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 200,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.contain,
                  image: AssetImage('assets/auth/bus2.jpg'),
                ),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowGreen.withOpacity(0.5),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(25),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sign Up',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        enabled: !_isLoading,
                        onChanged: (_) {
                          if (_nameError != null) {
                            setState(() {
                              _nameError = _auth.validateName(_nameController.text);
                            });
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.person,
                            color: AppColors.primaryDark,
                          ),
                          labelText: 'Full Name',
                          labelStyle: GoogleFonts.inter(color: AppColors.grey700),
                          hintText: 'John Smith',
                          hintStyle: GoogleFonts.inter(color: AppColors.grey500),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryDark,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.accentGreen,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                          errorText: _nameError,
                        ),
                        keyboardType: TextInputType.name,
                      ),
                      const SizedBox(height: 20),
                      // Email Field
                      TextFormField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        onChanged: (_) {
                          if (_emailError != null) {
                            setState(() {
                              _emailError = _auth.validateEmail(_emailController.text);
                            });
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.email,
                            color: AppColors.primaryDark,
                          ),
                          labelText: 'Email',
                          labelStyle: GoogleFonts.inter(color: AppColors.grey700),
                          hintText: 'example@domain.com',
                          hintStyle: GoogleFonts.inter(color: AppColors.grey500),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryDark,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.accentGreen,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                          errorText: _emailError,
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      // Phone Field
                      TextFormField(
                        controller: _phoneController,
                        enabled: !_isLoading,
                        onChanged: (_) {
                          if (_phoneError != null) {
                            setState(() {
                              _phoneError = _auth.validatePhone(_phoneController.text);
                            });
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.phone,
                            color: AppColors.primaryDark,
                          ),
                          labelText: 'Phone Number',
                          labelStyle: GoogleFonts.inter(color: AppColors.grey700),
                          hintText: '+1234567890',
                          hintStyle: GoogleFonts.inter(color: AppColors.grey500),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryDark,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.accentGreen,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          filled: true,
                          fillColor: AppColors.white,
                          errorText: _phoneError,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 20),
                      // Password Field
                      TextFormField(
                        controller: _passwordController,
                        enabled: !_isLoading,
                        obscureText: !_passwordVisible,
                        onChanged: (_) {
                          if (_passwordError != null) {
                            setState(() {
                              _passwordError = _auth.validatePassword(_passwordController.text);
                            });
                          }
                        },
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.lock,
                            color: AppColors.primaryDark,
                          ),
                          labelText: 'Password',
                          labelStyle: GoogleFonts.inter(color: AppColors.grey700),
                          hintText: '••••••••',
                          hintStyle: GoogleFonts.inter(color: AppColors.grey500),
                          helperText: 'Must be at least 8 characters with one letter and one number',
                          helperStyle: GoogleFonts.inter(color: AppColors.grey600, fontSize: 12),
                          helperMaxLines: 2,
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.primaryDark,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.accentGreen,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.red,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          errorText: _passwordError,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _passwordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _passwordVisible = !_passwordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Sign Up Button
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.7,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoading
                                ? AppColors.grey600
                                : AppColors.accentGreen,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 5,
                          ),
                          onPressed: _isLoading ? null : _handleSignUp,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryDark,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Text(
                                  'Sign Up',
                                  style: GoogleFonts.inter(
                                    fontSize: 18,
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Sign In Link
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SignInPage(),
                                  ),
                                );
                              },
                        child: Text(
                          'Already have an account? Sign In',
                          style: GoogleFonts.inter(
                            color: _isLoading
                                ? AppColors.grey600
                                : AppColors.primaryDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}