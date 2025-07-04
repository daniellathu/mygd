import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logging/logging.dart';
import 'signup_page.dart';
import 'forgot_password.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final log = Logger('LoginPage');
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

  Future<void> loginUser() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showMessage('Please fill in all fields', isError: true);
      return;
    }

    // Check if mounted before updating state
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      // Now attempt to sign in
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text,
        password: passwordController.text,
      );

      // Show success message on successful login
      if (mounted) {
        _showMessage('Login successful', isError: false);
        
        try {
          // Try to navigate to home page - wrap in try-catch to handle PigeonUserDetails error
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        } catch (navError) {
          print('Error during navigation after login: $navError');
          // If there's a navigation error, still try to go to home page
          // with a delay to allow error to resolve
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
            }
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      print('Login failed: ${e.message}');
      if (mounted) {
        _showMessage(e.message ?? 'Login failed', isError: true);
      }
    } catch (e) {
      print('Unexpected error during login: $e');
      
      // Handle the PigeonUserDetails type cast error
      if (e.toString().contains('PigeonUserDetails') && FirebaseAuth.instance.currentUser != null) {
        print('Caught PigeonUserDetails error, still proceeding with login');
        
        if (mounted) {
          _showMessage('Login successful', isError: false);
          // Still navigate to home despite the error
          Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        }
      } else {
        if (mounted) {
          _showMessage('An unexpected error occurred. Please try again.', isError: true);
        }
      }
    } finally {
      // Check if mounted before updating state
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      )
    );
  }

  Future<void> _promptForUsername(User user) async {
      String? username = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          String? enteredUsername;
          return AlertDialog(
            title: const Text('Set Username'),
            content: TextField(
              onChanged: (value) => enteredUsername = value,
              decoration: const InputDecoration(
                hintText: "Enter your username",
                border: OutlineInputBorder(),
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Save'),
                onPressed: () {
                  Navigator.of(context).pop(enteredUsername);
                },
              ),
            ],
          );
        },
      );

    if (username != null && username.isNotEmpty) {
      await user.updateDisplayName(username);
    }
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
                    'Welcome to MyGd',
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
                    'The Gardening Application',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 50),
                  
                  // Login Card
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
                          'Sign In',
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
                        
                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(context,
                                MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF348F50),
                            ),
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Login button
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
                            onPressed: isLoading ? null : loginUser,
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
                                    'SIGN IN',
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
                  
                  // Sign up link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account?",
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupPage()),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          "Sign up",
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