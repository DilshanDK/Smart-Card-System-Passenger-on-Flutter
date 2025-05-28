// // ignore_for_file: deprecated_member_use, library_private_types_in_public_api, use_build_context_synchronously

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:smart_card_app_passenger/auth_interfaces/sign_in_page.dart';
// import 'package:smart_card_app_passenger/services/auth_service.dart';
// import 'package:smart_card_app_passenger/themes/colors.dart';

// class PasswordResetPage extends StatefulWidget {
//   const PasswordResetPage({super.key});

//   @override
//   _PasswordResetPageState createState() => _PasswordResetPageState();
// }

// class _PasswordResetPageState extends State<PasswordResetPage> {
//   final _emailController = TextEditingController();
//   bool _isLoading = false;
//   bool _resetEmailSent = false;
//   final AuthenticationService _auth = AuthenticationService();

//   @override
//   void dispose() {
//     _emailController.dispose();
//     super.dispose();
//   }

//   void _showSnackBar(
//     String message, {
//     Color? backgroundColor,
//   }) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         backgroundColor: backgroundColor ?? AppColors.accentGreen,
//         duration: const Duration(seconds: 2),
//       ),
//     );
//   }

//   Future<void> _resetPassword() async {
//     // Validate email field
//     String? emailError = _auth.validateEmail(_emailController.text);
//     if (emailError != null) {
//       _showSnackBar(emailError, backgroundColor: Colors.red);
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       final result = await _auth.resetPassword(_emailController.text.trim());
      
//       if (result['success'] == true) {
//         setState(() => _resetEmailSent = true);
//         _showSnackBar(result['message']);
//       } else {
//         _showSnackBar(
//           result['message'],
//           backgroundColor: Colors.red,
//         );
//       }
//     } catch (e) {
//       _showSnackBar(
//         'Failed to send reset email: $e',
//         backgroundColor: Colors.red,
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: AppColors.white,
//       appBar: AppBar(
//         backgroundColor: AppColors.primaryDark,
//         title: Text(
//           'Reset Password',
//           style: GoogleFonts.inter(
//             fontSize: 24,
//             color: AppColors.white,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         centerTitle: true,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.symmetric(vertical: 20),
//         child: Column(
//           mainAxisSize: MainAxisSize.max,
//           mainAxisAlignment: MainAxisAlignment.start,
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             Container(
//               width: double.infinity,
//               height: 200,
//               decoration: const BoxDecoration(
//                 image: DecorationImage(
//                   fit: BoxFit.contain,
//                   image: AssetImage('assets/auth/bus2.jpg'),
//                 ),
//               ),
//             ),
//             const SizedBox(height: 30),
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 20),
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: AppColors.lightBackground,
//                   borderRadius: BorderRadius.circular(20),
//                   boxShadow: [
//                     BoxShadow(
//                       color: AppColors.shadowGreen.withOpacity(0.5),
//                       spreadRadius: 2,
//                       blurRadius: 5,
//                       offset: const Offset(0, 3),
//                     ),
//                   ],
//                 ),
//                 padding: const EdgeInsets.all(25),
//                 child: _resetEmailSent 
//                   ? _buildSuccessContent() 
//                   : _buildResetForm(),
//               ),
//             ),
//             const SizedBox(height: 30),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildResetForm() {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Text(
//           'Reset Password',
//           style: GoogleFonts.inter(
//             fontSize: 32,
//             fontWeight: FontWeight.bold,
//             color: AppColors.primaryDark,
//           ),
//         ),
//         const SizedBox(height: 15),
//         Text(
//           'Enter your email address to receive a password reset link.',
//           style: GoogleFonts.inter(
//             fontSize: 16,
//             color: AppColors.grey700,
//             height: 1.5,
//           ),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 25),
//         TextField(
//           controller: _emailController,
//           enabled: !_isLoading,
//           decoration: InputDecoration(
//             prefixIcon: Icon(
//               Icons.email,
//               color: AppColors.primaryDark,
//             ),
//             labelText: 'Enter your email',
//             labelStyle: GoogleFonts.inter(color: AppColors.grey700),
//             hintText: 'example@domain.com',
//             hintStyle: GoogleFonts.inter(color: AppColors.grey500),
//             enabledBorder: OutlineInputBorder(
//               borderSide: BorderSide(
//                 color: AppColors.primaryDark,
//                 width: 2,
//               ),
//               borderRadius: BorderRadius.circular(24),
//             ),
//             focusedBorder: OutlineInputBorder(
//               borderSide: BorderSide(
//                 color: AppColors.accentGreen,
//                 width: 2,
//               ),
//               borderRadius: BorderRadius.circular(24),
//             ),
//             filled: true,
//             fillColor: AppColors.white,
//           ),
//           keyboardType: TextInputType.emailAddress,
//         ),
//         const SizedBox(height: 30),
//         GestureDetector(
//           onTap: _isLoading ? null : _resetPassword,
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.7,
//             padding: const EdgeInsets.symmetric(vertical: 18),
//             decoration: BoxDecoration(
//               color: _isLoading
//                   ? AppColors.grey600
//                   : AppColors.accentGreen,
//               borderRadius: BorderRadius.circular(24),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.3),
//                   spreadRadius: 2,
//                   blurRadius: 5,
//                   offset: const Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Center(
//               child: _isLoading
//                   ? const CircularProgressIndicator(
//                       color: Colors.white,
//                     )
//                   : Text(
//                       'Reset Password',
//                       style: GoogleFonts.inter(
//                         fontSize: 18,
//                         color: AppColors.primaryDark,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 20),
//         GestureDetector(
//           onTap: _isLoading
//               ? null
//               : () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                       builder: (context) => const SignInPage(),
//                     ),
//                   );
//                 },
//           child: Text(
//             "Remember your password? Sign in",
//             style: GoogleFonts.inter(
//               color: _isLoading
//                   ? AppColors.grey600
//                   : AppColors.primaryDark,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildSuccessContent() {
//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(
//           Icons.mark_email_read,
//           size: 70,
//           color: AppColors.accentGreen,
//         ),
//         const SizedBox(height: 20),
//         Text(
//           'Email Sent',
//           style: GoogleFonts.inter(
//             fontSize: 28,
//             fontWeight: FontWeight.bold,
//             color: AppColors.primaryDark,
//           ),
//         ),
//         const SizedBox(height: 15),
//         Text(
//           'We have sent a password reset link to:',
//           style: GoogleFonts.inter(
//             fontSize: 16,
//             color: AppColors.grey700,
//           ),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 10),
//         Text(
//           _emailController.text.trim(),
//           style: GoogleFonts.inter(
//             fontSize: 16,
//             fontWeight: FontWeight.bold,
//             color: AppColors.primaryDark,
//           ),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 20),
//         Text(
//           'Please check your email and follow the instructions to reset your password.',
//           style: GoogleFonts.inter(
//             fontSize: 16,
//             color: AppColors.grey700,
//             height: 1.5,
//           ),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 30),
//         GestureDetector(
//           onTap: () {
//             Navigator.pushReplacement(
//               context,
//               MaterialPageRoute(
//                 builder: (context) => const SignInPage(),
//               ),
//             );
//           },
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.7,
//             padding: const EdgeInsets.symmetric(vertical: 18),
//             decoration: BoxDecoration(
//               color: AppColors.accentGreen,
//               borderRadius: BorderRadius.circular(24),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.3),
//                   spreadRadius: 2,
//                   blurRadius: 5,
//                   offset: const Offset(0, 3),
//                 ),
//               ],
//             ),
//             child: Center(
//               child: Text(
//                 'Return to Sign In',
//                 style: GoogleFonts.inter(
//                   fontSize: 18,
//                   color: AppColors.primaryDark,
//                   fontWeight: FontWeight.w700,
//                 ),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(height: 15),
//         GestureDetector(
//           onTap: () {
//             setState(() {
//               _resetEmailSent = false;
//               _emailController.clear();
//             });
//           },
//           child: Text(
//             "Try another email",
//             style: GoogleFonts.inter(
//               color: AppColors.primaryDark,
//               fontSize: 16,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }