import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'insects_description.dart';

class InsectsIdentificationScreen extends StatefulWidget {
  const InsectsIdentificationScreen({super.key});

  @override
  _InsectsIdentificationScreenState createState() => _InsectsIdentificationScreenState();
}

class _InsectsIdentificationScreenState extends State<InsectsIdentificationScreen> with SingleTickerProviderStateMixin {
  File? _imageFile;
  List<dynamic> _identificationResults = [];
  List<Map<String, dynamic>> _insectDetails = [];
  bool _isLoading = false;
  bool _showResults = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String apiKey = 'xggKLAihhrqhxUP3nQG9fzPm20As5DtQnXhnxPX9TvkjMeIIyj';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    
    // Initialize animation controller
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

  Future<void> _initializeFirebase() async {
    await Firebase.initializeApp();
  }

  Future<void> _getImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _identificationResults = [];
        _insectDetails = [];
        _showResults = false;
      });
    }
  }

  Future<void> _identifyInsect() async {
    if (_imageFile == null) {
      _showErrorDialog('Please select an image first');
      return;
    }

    setState(() {
      _isLoading = true;
      _showResults = false;
    });

    try {
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('https://insect.kindwise.com/api/v1/identification')
      );
      
      request.headers['Api-Key'] = apiKey;
      request.fields['similar_images'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('images', _imageFile!.path));

      print('Sending request to Insect.id API...');
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        List<dynamic> suggestions = data['result']['classification']['suggestions'] ?? [];
        
        print('Number of suggestions: ${suggestions.length}');

        List<Map<String, dynamic>> details = [];
        
        for (var suggestion in suggestions) {
          String insectName = suggestion['name'];
          print('Searching Firebase for: $insectName');
          var firebaseInsect = await _searchFirebaseDatabase(insectName);
          
          details.add({
            'insect_name': insectName,
            'probability': suggestion['probability'],
            'firebase_details': firebaseInsect,
          });
        }

        setState(() {
          _identificationResults = suggestions;
          _insectDetails = details;
          _isLoading = false;
          _showResults = true;
        });
      } else {
        print('API request failed with status code: ${response.statusCode}');
        _showErrorDialog('Failed to identify insect. Please try again. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('Error during insect identification: $e');
      _showErrorDialog('An error occurred: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>?> _searchFirebaseDatabase(String insectName) async {
    try {
      print('Searching Firebase for: $insectName');
      
      // First, try to find by commonName or insectSpecies
      var commonNameQuery = await _firestore
          .collection('InsectsLibrary')
          .where('InsectName', isEqualTo: insectName)
          .limit(1)
          .get();

      var speciesQuery = await _firestore
          .collection('InsectsLibrary')
          .where('InsectSpecies', isEqualTo: insectName)
          .limit(1)
          .get();
      
      if (commonNameQuery.docs.isNotEmpty) {
        print('Found match in Firebase by InsectName: ${commonNameQuery.docs.first.data()}');
        return commonNameQuery.docs.first.data();
      } else if (speciesQuery.docs.isNotEmpty) {
        print('Found match in Firebase by InsectSpecies: ${speciesQuery.docs.first.data()}');
        return speciesQuery.docs.first.data();
      }

      print('No match found in Firebase for: $insectName');
    } catch (e) {
      print('Error searching Firebase: $e');
    }
    return null;
  }

  Future<void> _launchInsectInfo(String insectName) async {
    final Uri url = Uri.parse('https://en.wikipedia.org/wiki/${insectName.replaceAll(' ', '_')}');
    
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showErrorDialog('Could not launch insect information');
    }
  }

  void _showErrorDialog(String message) {
    setState(() {
      _isLoading = false;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('Okay'),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
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
            colors: [Colors.grey.shade50, Colors.grey.shade100],
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
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Insect Identification',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                Expanded(
                  child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Analyzing your image...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Image selection card
                              Card(
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.bug_report_outlined,
                                        size: 48,
                                        color: Colors.green.shade700,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Take or select a photo of an insect to identify',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 24),
                                      _imageFile == null
                                          ? Container(
                                              height: 200,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.grey.shade300),
                                              ),
                                              child: Center(
                                                child: Icon(Icons.bug_report, size: 64, color: Colors.grey.shade400),
                                              ),
                                            )
                                          : ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.file(
                                                _imageFile!,
                                                height: 300,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                      const SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                        children: [
                                          _buildImageSourceButton(
                                            icon: Icons.camera_alt_outlined,
                                            label: 'Camera',
                                            onTap: () => _getImage(ImageSource.camera),
                                          ),
                                          _buildImageSourceButton(
                                            icon: Icons.photo_library_outlined,
                                            label: 'Gallery',
                                            onTap: () => _getImage(ImageSource.gallery),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 50,
                                        child: ElevatedButton(
                                          onPressed: _imageFile == null ? null : _identifyInsect,
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor: Colors.green.shade700,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            elevation: 2,
                                          ),
                                          child: const Text(
                                            'Identify Insect',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Results section
                              if (_showResults) ...[
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Icon(Icons.insights, color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Identification Results',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (_insectDetails.isEmpty) 
                                  _buildNoResultsCard()
                                else
                                  ..._buildResultCards(),
                              ],
                            ],
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
  
  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.green.shade700, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.green.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildNoResultsCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: Colors.grey.shade500,
            ),
            const SizedBox(height: 16),
            const Text(
              'No matching insects found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t identify the insect in your image. Try with a clearer photo or different angle.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  List<Widget> _buildResultCards() {
    return _insectDetails.map((result) {
      var insectName = result['insect_name'] ?? 'Unknown Insect';
      var probability = result['probability'] as double? ?? 0.0;
      var matchConfidence = (probability * 100).round();
      var firebaseDetails = result['firebase_details'];
      
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: firebaseDetails != null 
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InsectsDescription(
                        insectId: firebaseDetails['insectId'] as String?,
                        insectData: firebaseDetails,
                      ),
                    ),
                  );
                }
              : () => _launchInsectInfo(insectName),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Insect details in a row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insectName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (firebaseDetails != null && firebaseDetails['InsectSpecies'] != null)
                            Text(
                              firebaseDetails['InsectSpecies'],
                              style: TextStyle(
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$matchConfidence% Match',
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      firebaseDetails != null ? Icons.menu_book : Icons.language,
                      color: firebaseDetails != null ? Colors.green.shade700 : Colors.blue.shade700,
                      size: 24,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }
  
  Color _getConfidenceColor(double probability) {
    if (probability >= 0.9) {
      return Colors.green.shade700;
    } else if (probability >= 0.7) {
      return Colors.green.shade500;
    } else if (probability >= 0.5) {
      return Colors.amber.shade700;
    } else if (probability >= 0.3) {
      return Colors.orange.shade700;
    } else {
      return Colors.red.shade500;
    }
  }
}