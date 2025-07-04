import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'diseases_detail.dart';

class DiseasesHistoryPage extends StatefulWidget {
  const DiseasesHistoryPage({super.key});

  @override
  State<DiseasesHistoryPage> createState() => _DiseasesHistoryPageState();
}

class _DiseasesHistoryPageState extends State<DiseasesHistoryPage> with SingleTickerProviderStateMixin {
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
    _animationController.forward();
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
              Colors.red.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Custom App Bar
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
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Disease History',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ],
                  ),
                ),

                // History Content
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('diseaseHistory')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade600),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'Error: ${snapshot.error}',
                                  style: TextStyle(color: Colors.red.shade700),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.healing,
                                size: 80,
                                color: Colors.red.shade200,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No disease history found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  'Scan plants to identify diseases and they will appear here',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var diseaseData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                          String diseaseId = snapshot.data!.docs[index].id;
                          return _buildHistoryCard(context, diseaseData, diseaseId);
                        },
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

  Widget _buildHistoryCard(BuildContext context, Map<String, dynamic> diseaseData, String diseaseId) {
    final DateTime timestamp = (diseaseData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    final String formattedDate = DateFormat('MMM d, yyyy · h:mm a').format(timestamp);
    final double probability = (diseaseData['probability'] as num?)?.toDouble() ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DiseasesDetailPage(diseaseId: diseaseId),
            ),
          );
        },
        onLongPress: () => _showDeleteConfirmationDialog(context, diseaseId),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Disease Image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: diseaseData['diseaseImage'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(
                          base64Decode(diseaseData['diseaseImage']),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(
                        Icons.bug_report,
                        size: 32,
                        color: Colors.red.shade300,
                      ),
              ),
              const SizedBox(width: 16),
              
              // Disease Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diseaseData['diseaseName'] ?? 'Unknown Disease',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _getProbabilityColor(probability).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _getProbabilityColor(probability).withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Probability: ${probability.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _getProbabilityColor(probability),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Navigation icon
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String diseaseId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade700),
              const SizedBox(width: 8),
              const Text('Delete Disease Record'),
            ],
          ),
          content: const Text('Are you sure you want to delete this disease record? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade700,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
              onPressed: () {
                _deleteDisease(context, diseaseId);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteDisease(BuildContext context, String diseaseId) async {
    try {
      await FirebaseFirestore.instance.collection('diseaseHistory').doc(diseaseId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Disease record deleted successfully'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print('Error deleting disease record: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete disease record'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }
  
  Color _getProbabilityColor(double probability) {
    if (probability >= 90) return Colors.green.shade700;
    if (probability >= 70) return Colors.green.shade600;
    if (probability >= 50) return Colors.amber.shade700;
    if (probability >= 30) return Colors.orange.shade700;
    return Colors.red.shade700;
  }
}