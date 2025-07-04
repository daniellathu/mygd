import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/cloudinary_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InsectsDescription extends StatefulWidget {
  final String? insectId;
  final Map<String, dynamic>? insectData;
  
  const InsectsDescription({
    super.key, 
    this.insectId, 
    this.insectData
  });

  @override
  State<InsectsDescription> createState() => _InsectsDescriptionState();
}

class _InsectsDescriptionState extends State<InsectsDescription> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? insectDetails;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  bool isFavorite = false;
  bool checkingFavorite = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );
    
    CloudinaryService.ensureInitialized();
    _fetchInsectDetails();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchInsectDetails() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      if (widget.insectData != null) {
        insectDetails = {...widget.insectData!};
        await _checkIfFavorite();
      } else if (widget.insectId != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('InsectsLibrary')
        .doc(widget.insectId)
        .get();

        if (doc.exists) {
          insectDetails = doc.data() as Map<String, dynamic>;
          insectDetails!['insectId'] = doc.id;
          await _checkIfFavorite();
        } else {
          setState(() {
            hasError = true;
            errorMessage = 'Insect details not found';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          hasError = true;
          errorMessage = 'No insect ID or data provided';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error fetching insect details: $e';
        isLoading = false;
      });
    } finally {
      if (mounted && !hasError) {
        setState(() {
          isLoading = false;
        });
        _animationController.forward();
      }
    }
  }

  Future<void> _checkIfFavorite() async {
    setState(() {
      checkingFavorite = true;
    });
    
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || insectDetails == null) {
        setState(() {
          checkingFavorite = false;
          isFavorite = false;
        });
        return;
      }

      String insectId = insectDetails!['insectId'] as String? ?? widget.insectId ?? '';
      
      final favoriteDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .collection('favorites')
          .doc(insectId)
          .get();
      
      setState(() {
        isFavorite = favoriteDoc.exists;
        checkingFavorite = false;
      });
    } catch (e) {
      print('Error checking favorite status: $e');
      setState(() {
        checkingFavorite = false;
        isFavorite = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || insectDetails == null) {
        // Show login prompt if not logged in
        _showLoginPrompt();
        return;
      }

      setState(() {
        checkingFavorite = true;
      });
      
      String insectId = insectDetails!['insectId'] as String? ?? widget.insectId ?? '';
      String commonName = insectDetails!['InsectName'] as String? ?? 'Unknown Insect';
      String? imageUrl = insectDetails!['InsectImage'] as String?;
      
      final favoriteRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .collection('favorites')
          .doc(insectId);
          
      if (isFavorite) {
        // Remove from favorites
        await favoriteRef.delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed $commonName from favorites'),
            backgroundColor: Colors.grey.shade800,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        // Add to favorites
        await favoriteRef.set({
          'insectId': insectId,
          'InsectName': commonName,
          'insectImage': imageUrl,
          'dateAdded': FieldValue.serverTimestamp(),
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $commonName to favorites'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      
      setState(() {
        isFavorite = !isFavorite;
        checkingFavorite = false;
      });
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() {
        checkingFavorite = false;
      });
    }
  }
  
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Login Required'),
        content: const Text('You need to be logged in to save favorites.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to login page here
              // Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getDetailList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is String) return [data];
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey.shade50, Colors.grey.shade100],
            ),
          ),
          child: const SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ),
        ),
      );
    }

    if (hasError) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.grey.shade50, Colors.grey.shade100],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 80,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Error Loading Insect Data',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final String insectName = insectDetails?['InsectName'] ?? 'Unknown Insect';
    final String? speciesName = insectDetails?['InsectSpecies'] as String?;
    final String? description = insectDetails?['InsectDesc'] as String?;
    final List<dynamic> habitat = _getDetailList(insectDetails?['InsectHabitat']);
    final List<dynamic> impact = _getDetailList(insectDetails?['InsectImpact']);
    final String? imageUrl = insectDetails?['InsectImage'] as String?;
    
    String cloudinaryUrl = '';
    if (imageUrl != null) {
      cloudinaryUrl = CloudinaryService.getImageUrl(imageUrl);
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.grey.shade100],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero image with overlay
                      Stack(
                        children: [
                          Container(
                            height: 300,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 15,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Hero(
                              tag: 'insect-${widget.insectId ?? ""}',
                              child: imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: cloudinaryUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey.shade200,
                                      child: Icon(
                                        Icons.bug_report,
                                        size: 80,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.bug_report,
                                      size: 80,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                            ),
                          ),
                          // Gradient overlay for better text visibility
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 150,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Back button
                          Positioned(
                            top: 16,
                            left: 16,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF2E7D32),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Favorite button
                          Positioned(
                            top: 16,
                            right: 16,
                            child: GestureDetector(
                              onTap: checkingFavorite ? null : _toggleFavorite,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: checkingFavorite
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Icon(
                                        isFavorite
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: isFavorite ? Colors.red : Colors.grey.shade600,
                                        size: 20,
                                      ),
                              ),
                            ),
                          ),
                          // Insect name and species
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  insectName,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 10,
                                        color: Colors.black45,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                if (speciesName != null)
                                  const SizedBox(height: 4),
                                if (speciesName != null)
                                  Text(
                                    speciesName,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.grey.shade300,
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 8,
                                          color: Colors.black45,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      // Insect details
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Description
                            const Text(
                              'About',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                description ?? 'No description available.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade800,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Habitat section
                            _buildInsectSection(
                              title: 'Habitat',
                              items: habitat,
                              icon: Icons.home_outlined,
                              color: Colors.green.shade700,
                            ),
                            
                            // Ecological Impact section
                            _buildInsectSection(
                              title: 'Ecological Impact',
                              items: impact,
                              icon: Icons.eco_outlined,
                              color: Colors.purple.shade700,
                            ),
                            
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsectSection({
    required String title,
    required List<dynamic> items,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: items.isEmpty
                ? Text(
                    'No $title information available',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items.map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text(
                          item.toString()
                              .replaceAll('[', '')
                              .replaceAll(']', '')
                              .trim(),
                          style: TextStyle(
                            color: color.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}