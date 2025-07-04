import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../src/main/resources/plant/plant_description.dart';
import '../src/main/resources/insects/insects_description.dart';
import '../src/main/services/cloudinary_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  List<Map<String, dynamic>> _favorites = [];
  String? _errorMessage;

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
    
    _loadFavorites();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please log in to view your favorites';
        });
        return;
      }

      final QuerySnapshot favoritesSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .collection('favorites')
          .orderBy('dateAdded', descending: true)
          .get();

      List<Map<String, dynamic>> favorites = [];
      for (var doc in favoritesSnapshot.docs) {
        favorites.add({
          'id': doc.id,
          ...doc.data() as Map<String, dynamic>,
        });
      }

      setState(() {
        _favorites = favorites;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading favorites: ${e.toString()}';
      });
    }
  }

  Future<void> _removeFavorite(String itemId, String itemName) async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await FirebaseFirestore.instance
          .collection('Users')
          .doc(currentUser.uid)
          .collection('favorites')
          .doc(itemId)
          .delete();

      setState(() {
        _favorites.removeWhere((item) => item['id'] == itemId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed $itemName from favorites'),
          backgroundColor: Colors.grey.shade800,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error removing from favorites: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
          child: Column(
            children: [
              // Custom app bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    GestureDetector(
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
                              color: Colors.black.withOpacity(0.05),
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
                    const SizedBox(width: 12),
                    const Text(
                      "My Favorites",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    const Spacer(),
                    // Refresh button
                    GestureDetector(
                      onTap: _loadFavorites,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.refresh,
                          color: Color(0xFF2E7D32),
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 70,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadFavorites,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_favorites.isEmpty) {
      return FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.favorite_border,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No favorites yet',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Plants and insects you favorite will appear here',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.search),
                label: const Text('Browse Library'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final item = _favorites[index];
          final itemId = item['plantId'] as String? ?? item['insectId'] as String? ?? item['id'];
          final commonName = item['commonName'] as String? ?? item['InsectName'] as String? ?? 'Unknown';
          final imageUrl = item['plantImage'] as String? ?? item['insectImage'] as String?;
          final isInsect = item['InsectName'] != null;
          
          return Dismissible(
            key: Key(itemId),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_forever,
                color: Colors.white,
                size: 30,
              ),
            ),
            confirmDismiss: (direction) async {
              return await showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Remove from Favorites?'),
                    content: Text('Are you sure you want to remove "$commonName" from your favorites?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text(
                          'Remove',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            onDismissed: (direction) {
              _removeFavorite(itemId, commonName);
            },
            child: Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shadowColor: Colors.black26,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () {
                  if (isInsect) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => InsectsDescription(insectId: itemId),
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlantDescription(plantId: itemId),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: [
                    // Image
                    Container(
                      width: 100,
                      height: 100,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: CloudinaryService.getImageUrl(imageUrl),
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                    strokeWidth: 2,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Icon(
                                  isInsect ? Icons.bug_report : Icons.local_florist,
                                  size: 40,
                                  color: Colors.grey.shade400,
                                ),
                              )
                            : Icon(
                                isInsect ? Icons.bug_report : Icons.local_florist,
                                size: 40,
                                color: Colors.green.shade300,
                              ),
                      ),
                    ),
                    // Details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              commonName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E7D32),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.favorite,
                                  size: 16,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isInsect ? 'Favorite Insect' : 'Favorite Plant',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Remove button
                    IconButton(
                      onPressed: () => _removeFavorite(itemId, commonName),
                      icon: const Icon(
                        Icons.favorite,
                        color: Colors.red,
                      ),
                      tooltip: 'Remove from favorites',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
} 