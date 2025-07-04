import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/cloudinary_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ToolsDescription extends StatefulWidget {
  final String? toolId;
  final Map<String, dynamic>? toolData;
  
  const ToolsDescription({
    super.key, 
    this.toolId, 
    this.toolData
  });

  @override
  _ToolsDescriptionState createState() => _ToolsDescriptionState();
}

class _ToolsDescriptionState extends State<ToolsDescription> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _toolDetailsFuture;
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';
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
    
    _toolDetailsFuture = _fetchToolDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _fetchToolDetails() async {
    try {
      setState(() {
        isLoading = true;
        hasError = false;
      });

      Map<String, dynamic> toolDetails;

      if (widget.toolData != null) {
        toolDetails = Map<String, dynamic>.from(widget.toolData!);
      } else if (widget.toolId != null) {
        DocumentSnapshot toolDoc = await FirebaseFirestore.instance
            .collection('ToolsLibrary')
            .doc(widget.toolId)
            .get();

        if (!toolDoc.exists) {
          setState(() {
            hasError = true;
            errorMessage = 'Tool details not found';
            isLoading = false;
          });
          return {};
        }

        toolDetails = toolDoc.data() as Map<String, dynamic>;
      } else {
        setState(() {
          hasError = true;
          errorMessage = 'No tool ID or data provided';
          isLoading = false;
        });
        return {};
      }

      setState(() {
        isLoading = false;
      });
      _animationController.forward();
      return toolDetails;
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error fetching tool details: $e';
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

    return FutureBuilder<Map<String, dynamic>>(
      future: _toolDetailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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

        if (hasError || !snapshot.hasData) {
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
                        'Error Loading Tool Data',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        errorMessage.isEmpty ? 'No tool details found' : errorMessage,
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

        final tool = snapshot.data!;
        String toolName = tool['ToolName'] ?? 'Unknown Tool';
        String? description;
        if (tool['ToolDesc'] is List) {
          description = (tool['ToolDesc'] as List).join('\n');
        } else {
          description = tool['ToolDesc'] as String?;
        }
        String? imageUrl = tool['ToolImage'];
        String? toolFunction;
        if (tool['ToolFunc'] is List) {
          toolFunction = (tool['ToolFunc'] as List).join('\n');
        } else {
          toolFunction = tool['ToolFunc'] as String?;
        }
        
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
                              tag: 'tool-${widget.toolId ?? ""}',
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
                                        Icons.build,
                                        size: 80,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.build,
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
                          // Tool name
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Text(
                              toolName,
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
                      
                      // Tool details
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
                            
                            // Function section
                            _buildToolSection(
                              title: 'Function',
                              content: toolFunction,
                              icon: Icons.build_circle,
                              color: Colors.blue.shade700,
                            ),
                            
                            const SizedBox(height: 24),
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

  Widget _buildToolSection({
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
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          content ?? '',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}