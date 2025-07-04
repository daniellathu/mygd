import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../src/main/model/user_profile_model.dart';
import 'login_page.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  SignupPageState createState() => SignupPageState();
}

class SignupPageState extends State<SignupPage> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signupUser() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showMessage('Please fill in all fields');
      return;
    }

    setState(() => isLoading = true);

    try {
      // First ensure any existing user data is cleared
      final userProfileProvider = Provider.of<UserProfile>(context, listen: false);
      userProfileProvider.clearUserData();
      
      // Clear previous auth state
      await FirebaseAuth.instance.signOut();
      
      // Check if the email already exists
      List<String> signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(emailController.text.trim());
      
      if (signInMethods.isNotEmpty) {
        _showMessage('An account already exists for that email. Please log in instead.');
        setState(() => isLoading = false);
        return;
      }

      // If email doesn't exist, create new user
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(), 
        password: passwordController.text,
      );
      
      print("Created new user with ID: ${userCredential.user?.uid}");
      
      // Initialize user data in Firestore
      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('Users').doc(userCredential.user!.uid).set({
          'username': emailController.text.split('@')[0], // Use part of email as initial username
          'email': emailController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          // Don't add pigeonUserDetails field to avoid type casting issues later
        }, SetOptions(merge: true));
        
        print("Initialized user data in Firestore");
      }

      // Show success message
      await _showSuccessDialog();

      // Sign out the user explicitly to prevent auto-login
      await FirebaseAuth.instance.signOut();
      print("Signed out new user after account creation");

      // Clear any user data that might have been loaded
      userProfileProvider.clearUserData();
      print("Cleared user profile data after account creation");

      // Navigate to login page with fresh state
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = _getErrorMessage(e);
      _showMessage(errorMessage);
    } catch (e) {
      print('Unexpected error during signup: $e');
      
      // Check if Firebase user was created despite the error
      if (FirebaseAuth.instance.currentUser != null) {
        // If user was created, show success dialog instead of error
        await _showSuccessDialog();
        
        // Sign out the user and clear data
        await FirebaseAuth.instance.signOut();
        Provider.of<UserProfile>(context, listen: false).clearUserData();
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        _showMessage('Error creating account: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
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
            'Signup Successful',
            style: TextStyle(
              color: Color(0xFF348F50),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Your account has been created successfully. You can now log in with your credentials.',
            style: TextStyle(fontSize: 16),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF348F50),
              ),
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }

  void _showMessage(String message) {
    final bool isError = message.toLowerCase().contains('error') || 
                         message.toLowerCase().contains('failed') ||
                         message.toLowerCase().contains('invalid') ||
                         message.toLowerCase().contains('weak');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade700,
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
          child: FadeTransition(
            opacity: _fadeInAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo with bounce effect
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Container(
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
                  ),
                  const SizedBox(height: 30),
                  
                  // Welcome text
                  const Text(
                    'Create Account',
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
                    'Join Our Gardening Community',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // Signup Card
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
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF348F50),
                          ),
                        ),
                        const SizedBox(height: 25),
                        
                        // Email field
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email',
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
                        const SizedBox(height: 16),
                        
                        // Password field
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF348F50)),
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
                        
                        // Signup button
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
                            onPressed: isLoading ? null : signupUser,
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'SIGN UP',
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
                  
                  // Login link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account?",
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
      ),
    );
  }
}