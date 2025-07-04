import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'tools_description.dart';
import '../../services/cloudinary_service.dart';

class ToolsLibrary extends StatefulWidget {
  const ToolsLibrary({super.key});

  @override
  ToolsLibraryState createState() => ToolsLibraryState();
}

class ToolsLibraryState extends State<ToolsLibrary> with SingleTickerProviderStateMixin {
  late Stream<QuerySnapshot> toolsStream;
  String searchQuery = '';
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
    
    _animationController.forward();
    
    CloudinaryService.ensureInitialized();
    toolsStream = FirebaseFirestore.instance
        .collection('ToolsLibrary')
        .orderBy('ToolName')
        .snapshots();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
                        "Gardening Tools",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tools...',
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide(color: Colors.green.shade300, width: 1),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                
                // Tools grid
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: toolsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Center(
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
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.build_outlined,
                                size: 70,
                                color: Colors.green.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No tools found",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        );
                      } else {
                        List<DocumentSnapshot> tools = snapshot.data!.docs;
                        List<DocumentSnapshot> filteredTools = tools.where((tool) {
                          var toolData = tool.data() as Map<String, dynamic>;
                          return toolData['ToolName'].toString().toLowerCase().contains(searchQuery);
                        }).toList();
                        
                        // Sort tools alphabetically by name
                        filteredTools.sort((a, b) {
                          var aData = a.data() as Map<String, dynamic>;
                          var bData = b.data() as Map<String, dynamic>;
                          String aName = (aData['ToolName'] ?? '').toString().toLowerCase();
                          String bName = (bData['ToolName'] ?? '').toString().toLowerCase();
                          return aName.compareTo(bName);
                        });
                        
                        if (filteredTools.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 60,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No tools match "$searchQuery"',
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: GridView.builder(
                            padding: const EdgeInsets.only(bottom: 20),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.8,
                            ),
                            itemCount: filteredTools.length,
                            itemBuilder: (context, index) {
                              var tool = filteredTools[index];
                              var toolData = tool.data() as Map<String, dynamic>;
                              String toolName = toolData['ToolName'] ?? "Unknown Tool";
                              String? imageUrl = toolData['ToolImage'];
                              String cloudinaryUrl = CloudinaryService.getImageUrl(imageUrl);

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ToolsDescription(toolId: tool.id),
                                    ),
                                  );
                                },
                                child: Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 3,
                                  shadowColor: Colors.black26,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                        child: CachedNetworkImage(
                                          imageUrl: cloudinaryUrl,
                                          height: 130,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            height: 130,
                                            color: Colors.grey.shade200,
                                            child: const Center(
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: 130,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.build, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              toolName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 16,
                                                color: Color(0xFF2E7D32), // Dark green
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
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