import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiseasesDetailPage extends StatefulWidget {
  final String diseaseId;

  const DiseasesDetailPage({super.key, required this.diseaseId});

  @override
  State<DiseasesDetailPage> createState() => _DiseasesDetailPageState();
}

class _DiseasesDetailPageState extends State<DiseasesDetailPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;
  Map<String, dynamic>? _diseaseData;
  String _errorMessage = '';

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
    _fetchDiseaseDetails();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchDiseaseDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('diseaseHistory')
          .doc(widget.diseaseId)
          .get();

      if (!docSnapshot.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Disease record not found';
        });
        return;
      }

      setState(() {
        _diseaseData = docSnapshot.data();
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching disease details: $e';
      });
    }
  }

  // Helper function to safely convert any type to String
  String _safeToString(dynamic value) {
    if (value == null) return '';
    
    if (value is List) {
      return value.map((item) => item.toString()).join('\n• ');
    }
    
    if (value is Map) {
      try {
        return jsonEncode(value);
      } catch (e) {
        return value.toString();
      }
    }
    
    return value.toString();
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
              Colors.green.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                  ),
                )
              : _errorMessage.isNotEmpty
                  ? _buildErrorView()
                  : _buildDiseaseDetailContent(),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 56),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiseaseDetailContent() {
    // Extract disease name with type safety
    String diseaseName = 'Unknown Disease';
    if (_diseaseData?['name'] != null) {
      final nameData = _diseaseData!['name'];
      diseaseName = nameData is String ? nameData : _safeToString(nameData);
    }
    
    // Extract probability with type safety
    double probability = 0.0;
    if (_diseaseData?['probability'] != null) {
      final probData = _diseaseData!['probability'];
      if (probData is num) {
        probability = probData.toDouble();
      } else if (probData is String) {
        try {
          probability = double.parse(probData);
        } catch (e) {
          // Keep default if parsing fails
        }
      }
    }
    
    // Extract timestamp
    final DateTime timestamp = (_diseaseData?['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final String? base64Image = _diseaseData?['image'] as String?;
    
    // Get description data with type safety
    String description = 'No description available.';
    if (_diseaseData?['diseaseDesc'] != null) {
      final descData = _diseaseData!['diseaseDesc'];
      if (descData is List) {
        description = '• ${_safeToString(descData)}';
      } else {
        description = _safeToString(descData);
      }
    }
    
    // Parse treatment data
    String treatment = '';
    if (_diseaseData?['plantTreat'] != null) {
      final treatmentData = _diseaseData!['plantTreat'];
      
      if (treatmentData is String) {
        // If treatment is already a string
        if (treatmentData.startsWith('{')) {
          // If it's a JSON string
          try {
            final Map<String, dynamic> treatmentMap = jsonDecode(treatmentData);
            if (treatmentMap.containsKey('biological')) {
              final biological = treatmentMap['biological'];
              if (biological is List) {
                treatment += 'Biological:\n• ${biological.map((item) => item.toString()).join('\n• ')}\n\n';
              } else {
                treatment += 'Biological: ${_safeToString(biological)}\n\n';
              }
            }
            if (treatmentMap.containsKey('chemical')) {
              final chemical = treatmentMap['chemical'];
              if (chemical is List) {
                treatment += 'Chemical:\n• ${chemical.map((item) => item.toString()).join('\n• ')}';
              } else {
                treatment += 'Chemical: ${_safeToString(chemical)}';
              }
            }
          } catch (e) {
            treatment = treatmentData;
          }
        } else {
          // Regular string
          treatment = treatmentData;
        }
      } else if (treatmentData is Map) {
        // If treatment is a map
        try {
          final Map<String, dynamic> treatmentMap = Map<String, dynamic>.from(treatmentData);
          if (treatmentMap.containsKey('biological')) {
            final biological = treatmentMap['biological'];
            if (biological is List) {
              treatment += 'Biological:\n• ${biological.map((item) => item.toString()).join('\n• ')}\n\n';
            } else {
              treatment += 'Biological: ${_safeToString(biological)}\n\n';
            }
          }
          if (treatmentMap.containsKey('chemical')) {
            final chemical = treatmentMap['chemical'];
            if (chemical is List) {
              treatment += 'Chemical:\n• ${chemical.map((item) => item.toString()).join('\n• ')}';
            } else {
              treatment += 'Chemical: ${_safeToString(chemical)}';
            }
          }
        } catch (e) {
          treatment = 'Treatment information unavailable: $e';
        }
      } else if (treatmentData is List) {
        // If treatment is a List
        treatment = '• ${treatmentData.map((item) => item.toString()).join('\n• ')}';
      } else {
        treatment = _safeToString(treatmentData);
      }
    }
    
    if (treatment.isEmpty) {
      treatment = 'No treatment information available.';
    }
    
    // Get prevention data with proper type handling
    String prevention = '';
    if (_diseaseData?['diseasePrevent'] != null) {
      final preventionData = _diseaseData!['diseasePrevent'];
      if (preventionData is List) {
        prevention = '• ${preventionData.map((item) => item.toString()).join('\n• ')}';
      } else if (preventionData is String) {
        prevention = preventionData;
      } else {
        prevention = _safeToString(preventionData);
      }
    } else if (_diseaseData?['plantTreat'] is String && (_diseaseData!['plantTreat'] as String).startsWith('{')) {
      try {
        final Map<String, dynamic> treatmentMap = jsonDecode(_diseaseData!['plantTreat']);
        if (treatmentMap.containsKey('prevention')) {
          final preventionData = treatmentMap['prevention'];
          if (preventionData is List) {
            prevention = '• ${preventionData.map((item) => item.toString()).join('\n• ')}';
          } else {
            prevention = _safeToString(preventionData);
          }
        }
      } catch (e) {
        // Already handled in treatment section
      }
    }
    
    if (prevention.isEmpty) {
      prevention = 'No prevention information available.';
    }

    return FadeTransition(
      opacity: _fadeAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // Custom App Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.green.shade700,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Disease Details',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  ),
              ],
            ),
          ),
          
          // Disease Header Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: Card(
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Disease Image
                  if (base64Image != null)
                    SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: (() {
                        try {
                          return ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.memory(
                              base64Decode(base64Image),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 200,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: double.infinity,
                                  height: 200,
                                  color: Colors.grey.shade200,
                                  child: Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
            ),
          );
        },
                            ),
                          );
                        } catch (e) {
                          return Container(
                            width: double.infinity,
                            height: 200,
                            color: Colors.grey.shade200,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.bug_report,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Image not available',
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      })(),
                    ),
                  
                  // Disease Name & Probability
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                diseaseName,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getProbabilityColor(probability).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getProbabilityColor(probability).withOpacity(0.5),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${probability.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: _getProbabilityColor(probability),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Disease Information Sections
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Description Section
                  _buildInfoCard(
                    title: 'Description', 
                    content: description,
                    icon: Icons.description_outlined,
                    iconColor: Colors.blue.shade700,
                    backgroundColor: Colors.blue.shade50,
                    borderColor: Colors.blue.shade100,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Treatment Section
                  _buildInfoCard(
                    title: 'Treatment', 
                    content: treatment,
                    icon: Icons.healing_outlined,
                    iconColor: Colors.green.shade700,
                    backgroundColor: Colors.green.shade50,
                    borderColor: Colors.green.shade100,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Prevention Section
                  _buildInfoCard(
                    title: 'Prevention', 
                    content: prevention,
                    icon: Icons.verified_user_outlined,
                    iconColor: Colors.amber.shade800,
                    backgroundColor: Colors.amber.shade50,
                    borderColor: Colors.amber.shade100,
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getProbabilityColor(double probability) {
    if (probability >= 90) return Colors.green.shade700;
    if (probability >= 70) return Colors.green.shade600;
    if (probability >= 50) return Colors.amber.shade700;
    if (probability >= 30) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}