// FILEPATH: lib/page/forgot_password.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  Future<void> _resetPassword() async {
    if (_emailController.text.isEmpty) {
      _showMessage('Please enter your email address');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text,
      );
      _showSuccessDialog();
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'An error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuccessDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Reset Link Sent',
            style: TextStyle(
              color: Color(0xFF348F50),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Password reset email sent. Please check your inbox and follow the instructions.',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF348F50),
              ),
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Return to login page
              },
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF348F50),
              Color(0xFF56B4D3),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Logo
                Container(
                  height: 120,
                  width: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 30),
                
                // Welcome text
                const Text(
                  'Reset Password',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 3),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your email to reset your password',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 50),
                
                // Reset Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reset Password',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF348F50),
                        ),
                      ),
                      const SizedBox(height: 25),
                      
                      // Email field
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'Enter your email address',
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF348F50)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Reset button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF348F50),
                            foregroundColor: Colors.white,
                            elevation: 5,
                            shadowColor: const Color(0xFF348F50).withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _isLoading ? null : _resetPassword,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'SEND RESET LINK',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Back to login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Remember your password?",
                      style: TextStyle(color: Colors.white),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        "Log in",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}