import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/cloudinary_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PlantDescription extends StatefulWidget {
  final String? plantId;
  final Map<String, dynamic>? plantData;
  
  const PlantDescription({super.key, this.plantId, this.plantData});

  @override
  State<PlantDescription> createState() => _PlantDescriptionState();
}

class _PlantDescriptionState extends State<PlantDescription> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? plantDetails;
  Map<String, List<dynamic>> careDetails = {};
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
    _fetchPlantDetails();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchPlantDetails() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      if (widget.plantData != null) {
        plantDetails = {...widget.plantData!};
        _extractCareDetails();
        await _checkIfFavorite();
      } else if (widget.plantId != null) {
        DocumentSnapshot doc = await FirebaseFirestore.instance
        .collection('PlantLibrary')
        .doc(widget.plantId)
        .get();

        if (doc.exists) {
          plantDetails = doc.data() as Map<String, dynamic>;
          plantDetails!['plantId'] = doc.id;
          _extractCareDetails();
          await _checkIfFavorite();
        } else {
          setState(() {
            hasError = true;
            errorMessage = 'Plant details not found';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          hasError = true;
          errorMessage = 'No plant ID or data provided';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error fetching plant details: $e';
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

  // Extract care details from plant document (new structure)
  void _extractCareDetails() {
    if (plantDetails == null) return;
    
    Map<String, List<dynamic>> details = {};
    
    // List of care types that are now directly stored as arrays
    final careTypes = ['Humidity', 'Temperature', 'Container', 'Fertiliser', 'Soil'];
    
    // Extract care details directly from plantDetails
    for (var careType in careTypes) {
      if (plantDetails!.containsKey(careType)) {
        dynamic value = plantDetails![careType];
        if (value is List) {
          details[careType] = List<dynamic>.from(value);
        } else if (value != null && value.toString().isNotEmpty) {
          details[careType] = [value];
        }
      }
    }
    
    setState(() {
      careDetails = details;
    });
  }

  Future<void> _checkIfFavorite() async {
    setState(() {
      checkingFavorite = true;
    });
    
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null || plantDetails == null) {
        setState(() {
          checkingFavorite = false;
          isFavorite = false;
        });
        return;
      }

      String plantId = plantDetails!['plantId'] as String? ?? widget.plantId ?? '';
      
      final favoriteDoc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .collection('favorites')
          .doc(plantId)
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
      if (currentUser == null || plantDetails == null) {
        // Show login prompt if not logged in
        _showLoginPrompt();
        return;
      }

      setState(() {
        checkingFavorite = true;
      });
      
      String plantId = plantDetails!['plantId'] as String? ?? widget.plantId ?? '';
      String commonName = plantDetails!['commonName'] as String? ?? 'Unknown Plant';
      String? imageUrl = plantDetails!['PlantImage'] as String?;
      
      final favoriteRef = FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .collection('favorites')
          .doc(plantId);
          
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
          'plantId': plantId,
          'commonName': commonName,
          'plantImage': imageUrl,
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
              // You should navigate to login page here
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

  @override
  Widget build(BuildContext context) {
          return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey.shade50,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                )
              : hasError
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    )
                  : FadeTransition(
                      opacity: _fadeAnimation,
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                                // Hero image with back button
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
                                        tag: 'plant-${widget.plantId ?? ""}',
                                        child: CachedNetworkImage(
                                          imageUrl: CloudinaryService.getImageUrl(plantDetails?['PlantImage']),
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
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.image_not_supported,
                                                  size: 60,
                                                  color: Colors.grey.shade400,
                                                ),
                                                const SizedBox(height: 8),
                                                const Text('Image not available'),
                                              ],
                                            ),
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
                                    // Plant name and species
                                    Positioned(
                                      bottom: 20,
                                      left: 20,
                                      right: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                                            plantDetails?['commonName'] ?? 'Unknown Plant',
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
                                          const SizedBox(height: 4),
                      Text(
                                            plantDetails?['PlantSpecies'] ?? '',
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
                                
                                // Plant details
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
                                          plantDetails?['PlantDesc'] ?? 'No description available.',
                        style: TextStyle(
                          fontSize: 16,
                                            color: Colors.grey.shade800,
                          height: 1.5,
                        ),
                      ),
                                      ),
                                      
                      const SizedBox(height: 30),
                      
                                      // Plant care details
                                      const Text(
                                        'Care Guide',
                        style: TextStyle(
                                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      
                                      // Care details cards
                                      _buildCareCard('Humidity', Icons.water_drop_rounded, Colors.blue.shade100),
                                      _buildCareCard('Temperature', Icons.wb_sunny_rounded, Colors.amber.shade100),
                                      _buildCareCard('Container', Icons.category_rounded, Colors.brown.shade100),
                                      _buildCareCard('Fertiliser', Icons.spa_rounded, Colors.green.shade100),
                                      _buildCareCard('Soil', Icons.landscape_rounded, Colors.orange.shade100),
                                      
                                      const SizedBox(height: 80), // Space for FAB
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

  Widget _buildCareCard(String careType, IconData icon, Color bgColor) {
    List<dynamic> details = careDetails[careType] ?? [];
    
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
            color: bgColor,
                      shape: BoxShape.circle,
                    ),
          child: Icon(
            icon,
            color: bgColor.withRed(bgColor.red ~/ 2).withGreen(bgColor.green ~/ 2).withBlue(bgColor.blue ~/ 2),
            size: 22,
          ),
        ),
        title: Text(
          careType,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E7D32),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: details.isEmpty
                ? const Text(
                    'No information available',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  )
                : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _processDetails(details),
                ),
          ),
        ],
      ),
    );
  }

  List<Widget> _processDetails(List<dynamic> details) {
    List<Widget> chips = [];

    for (var detail in details) {
      if (detail is List) {
        for (var item in detail) {
            String cleanItem = item.toString()
                .replaceAll('[', '')
                .replaceAll(']', '')
                .trim();
          chips.add(_buildDetailChip(cleanItem));
        }
      } else {
        String cleanDetail = detail.toString()
            .replaceAll('[', '')
            .replaceAll(']', '')
            .trim();
        chips.add(_buildDetailChip(cleanDetail));
      }
    }
    
    return chips;
  }

  Widget _buildDetailChip(String detail) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        detail,
        style: TextStyle(
          color: Colors.green.shade800,
          fontSize: 14,
        ),
      ),
    );
  }
}