import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'soil_description.dart';

class SoilLibrary extends StatefulWidget {
  const SoilLibrary({super.key});

  @override
  State<SoilLibrary> createState() => _SoilLibraryState();
}

class _SoilLibraryState extends State<SoilLibrary> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  Stream<QuerySnapshot>? _soilsStream;
  final List<DocumentSnapshot> _filteredSoils = [];
  bool _isSearching = false;
  
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
    
    // Initialize the stream of soil types
    _soilsStream = FirebaseFirestore.instance
        .collection('SoilTypes')
        .orderBy('SoilName')
        .snapshots();
        
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }
  
  void _filterSoils(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
    });
  }
  
  Widget _buildSoilCard(BuildContext context, DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>;
    final String soilName = data['SoilName'] ?? 'Unknown Soil Type';
    final String soilImage = data['SoilImage'] ?? '';
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SoilDescriptionPage(
              soilId: document.id,
              soilDetails: data,
            ),
          ),
        );
      },
      child: Card(
        elevation: 4,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: soilImage.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: soilImage,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 160,
                        color: Colors.grey[300],
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 160,
                        color: Colors.grey[300],
                        child: const Icon(Icons.landscape, size: 50, color: Colors.grey),
                      ),
                    )
                  : Container(
                      height: 160,
                      color: Colors.brown[100],
                      child: const Icon(Icons.landscape, size: 50, color: Colors.brown),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                soilName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: Color(0xFF8D6E63), // Brown
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
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
              Colors.brown.shade50,
              Colors.grey.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Custom app bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
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
                            color: Color(0xFF8D6E63),
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        "Soil Types",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D6E63),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterSoils,
                      decoration: InputDecoration(
                        hintText: 'Search soil types...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF8D6E63)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _filterSoils('');
                                  FocusScope.of(context).unfocus();
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
                
                // Soil grid
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _soilsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.red),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
                          ),
                        );
                      }

                      var soils = snapshot.data!.docs;
                      
                      // Apply search filter if needed
                      if (_isSearching) {
                        final query = _searchController.text.toLowerCase();
                        soils = soils.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final soilName = (data['SoilName'] ?? '').toString().toLowerCase();
                          return soilName.contains(query);
                        }).toList();
                      }

                      if (soils.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 60,
                                color: Colors.brown.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isSearching
                                    ? 'No soil types match your search'
                                    : 'No soil types available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: soils.length,
                          itemBuilder: (context, index) {
                            return _buildSoilCard(context, soils[index]);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




