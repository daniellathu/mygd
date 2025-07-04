import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/cloudinary_service.dart';

class SoilDescriptionPage extends StatefulWidget {
  final String? soilId;
  final Map<String, dynamic>? soilDetails;
  
  const SoilDescriptionPage({
    super.key, 
    this.soilId, 
    this.soilDetails
  });

  @override
  State<SoilDescriptionPage> createState() => _SoilDescriptionPageState();
}

class _SoilDescriptionPageState extends State<SoilDescriptionPage> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _soilDetailsFuture;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn)
    );
    
    _soilDetailsFuture = _fetchSoilDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchSoilDetails() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      Map<String, dynamic> soilDetails;

      if (widget.soilDetails != null) {
        soilDetails = Map<String, dynamic>.from(widget.soilDetails!);
      } else if (widget.soilId != null) {
        DocumentSnapshot soilDoc = await FirebaseFirestore.instance
            .collection('SoilTypes')
            .doc(widget.soilId)
            .get();

        if (!soilDoc.exists) {
          setState(() {
            hasError = true;
            errorMessage = 'Soil details not found';
            isLoading = false;
          });
          return {};
        }

        soilDetails = soilDoc.data() as Map<String, dynamic>;
      } else {
        setState(() {
          hasError = true;
          errorMessage = 'No soil ID or data provided';
          isLoading = false;
        });
        return {};
      }

      setState(() {
        isLoading = false;
      });
      _animationController.forward();
      return soilDetails;
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error fetching soil details: $e';
        isLoading = false;
      });
      return {};
    }
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
              colors: [Colors.brown.shade50, Colors.grey.shade100],
            ),
          ),
          child: const SafeArea(
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
              ),
            ),
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _soilDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.brown.shade50, Colors.grey.shade100],
                ),
              ),
              child: const SafeArea(
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
                  ),
                ),
              ),
            ),
          );
        }

        if (hasError || !snapshot.hasData) {
          return Scaffold(
            body: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.brown.shade50, Colors.grey.shade100],
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
                        'Error Loading Soil Data',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorMessage.isEmpty ? 'No soil details found' : errorMessage,
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
                            backgroundColor: const Color(0xFF8D6E63),
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

        final soil = snapshot.data!;
        String soilName = soil['SoilName'] ?? 'Unknown Soil';
        String? description;
        if (soil['SoilDesc'] is List) {
          description = (soil['SoilDesc'] as List).join('\n');
        } else {
          description = soil['SoilDesc'] as String?;
        }
        String? imageUrl = soil['SoilImage'];
        List<dynamic> commonUse = _getDetailList(soil['CommonUse']);
        List<dynamic> soilChar = _getDetailList(soil['SoilChar']);
        List<dynamic> soilSize = _getDetailList(soil['SoilSize']);
        List<dynamic> pHLevel = _getDetailList(soil['pHLevel']);
        
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
                colors: [Colors.brown.shade50, Colors.grey.shade100],
              ),
            ),
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
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
                              tag: 'soil-${widget.soilId ?? ""}',
                              child: imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: cloudinaryUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D6E63)),
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: Colors.grey.shade200,
                                      child: Icon(
                                        Icons.landscape,
                                        size: 80,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.landscape,
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
                                  color: Color(0xFF8D6E63),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                          // Soil name
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Text(
                              soilName,
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
                          ),
                        ],
                      ),
                      
                      // Soil details
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
                                color: Color(0xFF8D6E63),
                              ),
                            ),
                            const SizedBox(height: 16),
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
                            
                            const SizedBox(height: 16),
                            
                            // Common Use section
                            if (commonUse.isNotEmpty)
                              _buildSoilSection(
                                title: 'Common Uses',
                                items: commonUse,
                                icon: Icons.agriculture,
                                color: const Color(0xFF8D6E63),
                              ),
                            
                            const SizedBox(height: 16),
                            
                            // Soil Characteristics section
                            if (soilChar.isNotEmpty)
                              _buildSoilSection(
                                title: 'Soil Characteristics',
                                items: soilChar,
                                icon: Icons.analytics,
                                color: const Color(0xFF8D6E63),
                              ),
                            
                            const SizedBox(height: 16),
                            
                            // Soil Size section
                            if (soilSize.isNotEmpty)
                              _buildSoilSection(
                                title: 'Soil Size',
                                items: soilSize,
                                icon: Icons.straighten,
                                color: const Color(0xFF8D6E63),
                              ),
                            
                            const SizedBox(height: 16),
                            
                            // pH Level section
                            if (pHLevel.isNotEmpty)
                              _buildSoilSection(
                                title: 'pH Level',
                                items: pHLevel,
                                icon: Icons.science,
                                color: const Color(0xFF8D6E63),
                              ),
                            
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSoilSection({
    required String title,
    String? content,
    List<dynamic>? items,
    required IconData icon,
    required Color color,
  }) {
    bool isEmpty = (content == null || content.isEmpty) && (items == null || items.isEmpty);
    
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
            child: isEmpty
                ? Text(
                    'No $title information available',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  )
                : items != null
                    ? Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: items.map((item) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: color.withOpacity(0.3)),
                          ),
                          child: Text(
                            item.toString(),
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                        )).toList(),
                      )
                    : Text(
                        content ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}




