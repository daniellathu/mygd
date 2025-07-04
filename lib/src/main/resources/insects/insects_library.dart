import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'insects_description.dart';
import '../../services/cloudinary_service.dart';
import 'insects_identification.dart'; // Import the InsectsIdentificationScreen

class InsectsLibrary extends StatefulWidget {
  const InsectsLibrary({super.key});

  @override
  InsectsLibraryState createState() => InsectsLibraryState();
}

class InsectsLibraryState extends State<InsectsLibrary> with SingleTickerProviderStateMixin {
  late Stream<QuerySnapshot> insectsStream;
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
    insectsStream = FirebaseFirestore.instance
        .collection('InsectsLibrary')
        .orderBy('InsectName')
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
                        "Insects Library",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InsectsIdentificationScreen(),
                ),
              );
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
                            Icons.qr_code_scanner_rounded,
                            color: Color(0xFF2E7D32),
                            size: 20,
                          ),
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
                hintText: 'Search insects...',
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
                
                // Insects grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: insectsStream,
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
                                Icons.bug_report_outlined,
                                size: 70,
                                color: Colors.green.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "No insects found",
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
                  List<DocumentSnapshot> insects = snapshot.data!.docs;
                  List<DocumentSnapshot> filteredInsects = insects.where((insect) {
                    var insectData = insect.data() as Map<String, dynamic>;
                    return insectData['InsectName'].toString().toLowerCase().contains(searchQuery);
                  }).toList();

                        if (filteredInsects.isEmpty) {
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
                                  'No insects match "$searchQuery"',
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
                    itemCount: filteredInsects.length,
                    itemBuilder: (context, index) {
                      var insect = filteredInsects[index];
                      var insectData = insect.data() as Map<String, dynamic>;
                      String insectName = insectData['InsectName'] ?? "Unknown Insect";
                      String insectSpecies = insectData['InsectSpecies'] ?? "Unknown Species";
                      String? imageUrl = insectData['InsectImage'];
                      String cloudinaryUrl = CloudinaryService.getImageUrl(imageUrl);

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InsectsDescription(insectId: insect.id),
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
                                            child: const Icon(Icons.bug_report, color: Colors.grey),
                                          ),
                                ),
                              ),
                              Padding(
                                        padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      insectName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 16,
                                                color: Color(0xFF2E7D32), // Dark green
                                              ),
                                              maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      insectSpecies,
                                              style: TextStyle(
                                                color: Colors.grey.shade700,
                                                fontSize: 13,
                                                fontStyle: FontStyle.italic,
                                              ),
                                              maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
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
