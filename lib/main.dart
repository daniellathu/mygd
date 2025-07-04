import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'page/login_page.dart';
import 'page/home_page.dart';
import 'src/main/model/user_profile_model.dart'; // Make sure this path is correct
import 'src/main/services/cloudinary_service.dart'; // Import CloudinaryService
// Import our dummy class

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // Initialize CloudinaryService
  CloudinaryService.ensureInitialized();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create a fresh UserProfile provider for each app rebuild
    return MultiProvider(
      providers: [
        // Create a new provider instance each time to prevent data leakage
        ChangeNotifierProvider(create: (_) => UserProfile()),
      ],
      child: MaterialApp(
        title: 'MyGD App',
        theme: ThemeData(primarySwatch: Colors.green),
        // Use initialRoute instead of home
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthHandler(),
          '/login': (context) => const LoginPage(),
          '/home': (context) => const HomePage(),
        },
      ),
    );
  }
}

// Separate StatefulWidget to better manage auth state
class AuthHandler extends StatefulWidget {
  const AuthHandler({super.key});

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // Handle error state (including PigeonUserDetails error)
        if (snapshot.hasError) {
          print('Auth state stream error: ${snapshot.error}');
          
          // If it's the PigeonUserDetails error but user is authenticated, still proceed
          if (snapshot.error.toString().contains('PigeonUserDetails') && 
              FirebaseAuth.instance.currentUser != null) {
            
            print('Ignoring PigeonUserDetails error in auth stream, user is authenticated');
            
            // Navigate to home page
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/home');
            });
            
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          
          // For other errors, go to login
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
          
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // User is logged out - navigate to login
        if (!snapshot.hasData) {
          // Navigate to login page on next frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/login');
          });
          
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // User is logged in - navigate to home page
        try {
          final currentUser = snapshot.data!;
          print('User authenticated: ${currentUser.uid}');
          
          // Navigate to home page on next frame
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/home');
          });
        } catch (e) {
          print('Error handling authenticated user: $e');
          
          // If PigeonUserDetails error, still proceed to home
          if (e.toString().contains('PigeonUserDetails')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/home');
            });
          }
        }
        
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}