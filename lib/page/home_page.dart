import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../src/main/resources/diseases/diseases_identification.dart';
import '../src/main/resources/insects/insects_library.dart';
import '../src/main/resources/plant/plant_library.dart';
import '../src/main/resources/mygarden/mygarden_plantlist.dart';
import '../src/main/resources/tools/tools_library.dart';
import '../src/main/resources/soil/soil_library.dart';
import 'user_profile.dart';
import '../src/main/model/user_profile_model.dart';
import 'favorites_page.dart';
import 'dart:io';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _animationController.forward();
    
    // Load user data on a slight delay to ensure context is ready
    Future.delayed(Duration.zero, () {
      if (mounted) {
        try {
          final userProfile = Provider.of<UserProfile>(context, listen: false);
          userProfile.loadUserData().catchError((error) {
            print('Error loading user data in HomePage: $error');
            
            // Handle PigeonUserDetails error specifically
            if (error.toString().contains('PigeonUserDetails')) {
              print('PigeonUserDetails error detected, using basic user info');
              // Use basic user info from Firebase Auth as fallback
              if (FirebaseAuth.instance.currentUser != null) {
                userProfile.username = FirebaseAuth.instance.currentUser!.displayName ?? 
                                     FirebaseAuth.instance.currentUser!.email?.split('@')[0] ?? 
                                     'User';
              }
              return null; // Return null to satisfy Future<void>
            }
            
            // Fallback to basic data if loading fails
            if (FirebaseAuth.instance.currentUser != null) {
              userProfile.username = FirebaseAuth.instance.currentUser!.displayName ?? 'User';
            }
          });
        } catch (e) {
          print('Error accessing user profile in HomePage: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    try {
      // Show the success message first to avoid race conditions
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Logged out successfully'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 1),
        ),
      );
      
      // Clear user data
      Provider.of<UserProfile>(context, listen: false).clearUserData();
      
      // Sign out and navigate directly without waiting for auth state changes
      await FirebaseAuth.instance.signOut();
      
      // Force a complete app reset by popping all routes and going to login
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
      
    } catch (e) {
      print('Error during logout: $e');
      // Only show error if previous success message is gone
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to log out. Please try again.'),
              backgroundColor: Colors.red.shade800,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      });
    }
  }

  void _showProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const UserProfileDialog(),
    );
  }

  // Handle both local and remote profile images
  ImageProvider? _getProfileImageProvider(UserProfile userProfile) {
    if (userProfile.profileImageUrl == null || userProfile.profileImageUrl!.isEmpty) {
      print('No profile image URL available, using default image');
      return const AssetImage('assets/default_profile.png');
    }
    
    print('Loading profile image from path: ${userProfile.profileImageUrl}');
    try {
      // Check if the path is a local file
      if (userProfile.profileImageUrl!.startsWith('/')) {
        return FileImage(File(userProfile.profileImageUrl!));
      }
      // If it's a network URL, use NetworkImage
      return NetworkImage(userProfile.profileImageUrl!);
    } catch (e) {
      print('Error creating image provider: $e');
      return const AssetImage('assets/default_profile.png');
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Consumer<UserProfile>(
      builder: (context, userProfile, child) {
        print('Building home page with profile image path: ${userProfile.profileImageUrl}');
        return Scaffold(
          backgroundColor: Colors.grey[50],
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: const Text(
              'MyGd',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 22,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white),
                onPressed: () => _logout(context),
                tooltip: 'Logout',
              ),
            ],
          ),
          body: FadeTransition(
            opacity: _fadeInAnimation,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF348F50),
                    const Color(0xFF56B4D3).withOpacity(0.9),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.3, 0.5],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Welcome Section with profile card
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                      child: Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _showProfileDialog(context),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF348F50),
                                      Color(0xFF56B4D3),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.white,
                                  backgroundImage: _getProfileImageProvider(userProfile),
                                  child: (userProfile.profileImageUrl == null || userProfile.profileImageUrl!.isEmpty) 
                                      ? Icon(Icons.person, size: 30, color: Colors.grey.shade400)
                                      : null,
                                  onBackgroundImageError: (exception, stackTrace) {
                                    print('Error loading profile image: $exception');
                                    // Force a rebuild to show the default icon
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome back,',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    userProfile.username ?? 'Gardener',
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const FavoritesPage(),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.red.shade300,
                                      Colors.red.shade400,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.shade200.withOpacity(0.5),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.favorite,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Favorites',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Category header
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Categories',
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Features Grid
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.count(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.9,
                          children: [
                            _buildFeatureCard(
                              context,
                              'My Garden',
                              'Track and manage your plants',
                              Icons.local_florist,
                              const Color(0xFF388E3C),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const MyGardenPlantList()),
                                );
                              },
                            ),
                            _buildFeatureCard(
                              context,
                              'Plant Library',
                              'Explore plant species',
                              Icons.nature,
                              const Color(0xFF43A047),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PlantLibrary()),
                                );
                              },
                            ),
                            _buildFeatureCard(
                              context,
                              'Gardening Tools',
                              'Essential tools guide',
                              Icons.build,
                              const Color(0xFF6D4C41),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ToolsLibrary()),
                                );
                              },
                            ),
                            _buildFeatureCard(
                              context,
                              'Soil & Nutrients',
                              'Soil health and fertilizers',
                              Icons.landscape,
                              const Color(0xFF8D6E63),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const SoilLibrary()),
                                );
                              },
                            ),
                            _buildFeatureCard(
                              context,
                              'Insect Library',
                              'Identify garden insects',
                              Icons.bug_report,
                              const Color(0xFFEF6C00),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const InsectsLibrary()),
                                );
                              },
                            ),
                            _buildFeatureCard(
                              context,
                              'Scan Diseases',
                              'Identify plant diseases',
                              Icons.qr_code_scanner,
                              const Color(0xFFE53935),
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const DiseaseIdentificationScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 1,
      shadowColor: color.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}