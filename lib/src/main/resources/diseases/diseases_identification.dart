import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'diseases_history.dart';

class DiseaseIdentificationScreen extends StatefulWidget {
  const DiseaseIdentificationScreen({super.key});

  @override
  _DiseaseIdentificationScreenState createState() => _DiseaseIdentificationScreenState();
}

class _DiseaseIdentificationScreenState extends State<DiseaseIdentificationScreen> with SingleTickerProviderStateMixin {
  File? _imageFile;
  bool _isHealthy = false;
  double _healthProbability = 0.0;
  List<Map<String, dynamic>> _diseaseSuggestions = [];
  bool _isLoading = false;
  bool _showResults = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final String _apiKey = 'oSE8hxDUFVQHm8e1ptBjQZoBhv6OO8YAqYpsXu9InNlNU3zq0m';
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _getImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 95,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _resetResults();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Image selection failed: ${e.toString()}';
      });
    }
  }

  void _resetResults() {
    setState(() {
      _isHealthy = false;
      _healthProbability = 0.0;
      _diseaseSuggestions = [];
      _showResults = false;
      _errorMessage = null;
    });
  }

  Future<void> _assessPlantHealth() async {
    if (_imageFile == null) {
      setState(() => _errorMessage = 'Please select an image first');
      return;
    }

    setState(() {
      _isLoading = true;
      _showResults = false;
      _errorMessage = null;
    });

    try {
      // Convert image to base64
      final imageBytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(imageBytes);

      // Prepare API request
      final url = Uri.parse('https://plant.id/api/v3/health_assessment');
      final queryParams = {
        'details': 'local_name,description,url,treatment,classification,common_names,cause',
        'language': 'en',
        'full_disease_list': 'true',
      };
      final headers = {
        'Content-Type': 'application/json',
        'Api-Key': _apiKey,
      };
      final body = jsonEncode({
        'images': [base64Image],
      });

      // Send request
      final response = await http.post(
        url.replace(queryParameters: queryParams),
        headers: headers,
        body: body,
      );

      // Handle response
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _processHealthAssessment(data);
      } else {
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('Error details: $e');
      setState(() {
        _errorMessage = 'Health assessment failed: ${e.toString()}';
        _showResults = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _processHealthAssessment(Map<String, dynamic> data) {
    try {
      final healthAssessment = data['result']['disease'];
      final isHealthy = healthAssessment['is_healthy'] ?? false;
      final healthProbability = (1 - (healthAssessment['suggestions'][0]['probability'] ?? 0.0)) * 100.0;
      final diseases = healthAssessment['suggestions'] ?? [];

      // Process disease suggestions
      final processedDiseases = diseases.map<Map<String, dynamic>>((disease) {
        final details = disease['details'] ?? {};
        final treatment = details['treatment'] is Map 
            ? details['treatment'] 
            : {'biological': '', 'chemical': '', 'prevention': ''};

        return {
          'id': disease['id'],
          'name': disease['name'],
          'probability': (disease['probability'] ?? 0.0) * 100,
          'local_name': details['local_name'],
          'description': details['description'],
          'url': details['url'],
          'classification': details['classification'] ?? [],
          'common_names': details['common_names'] ?? [],
          'cause': details['cause'],
          'treatment': treatment,
        };
      }).toList();

      setState(() {
        _isHealthy = isHealthy;
        _healthProbability = healthProbability;
        _diseaseSuggestions = processedDiseases;
        _showResults = true;
      });

      if (isHealthy && processedDiseases.isEmpty) {
        setState(() => _errorMessage = 'No diseases detected - plant appears healthy');
      } else if (processedDiseases.isEmpty) {
        setState(() => _errorMessage = 'No specific diseases identified');
      }
    } catch (e) {
      throw Exception('Failed to process health assessment: $e');
    }
  }

  Future<void> _launchDiseaseInfo(String url) async {
    if (url.isEmpty) {
      setState(() => _errorMessage = 'No information page available');
      return;
    }
    
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      setState(() => _errorMessage = 'Could not launch information page');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.green.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // Improved app bar with proper padding and alignment
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
                      InkWell(
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
                      Text(
                        'Plant Health Assessment',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const DiseasesHistoryPage()),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.history_rounded,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Capture Section
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.health_and_safety,
                                    size: 40,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Capture clear photo of affected plant area',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Image Preview
                                Container(
                                  height: 250,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: _imageFile == null
                                      ? Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.photo_camera,
                                                size: 60,
                                                color: Colors.grey.shade400,
                                              ),
                                              const SizedBox(height: 16),
                                              Text(
                                                'No image selected',
                                                style: TextStyle(
                                                  color: Colors.grey.shade600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(15),
                                          child: Image.file(
                                            _imageFile!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: 250,
                                          ),
                                        ),
                                ),
                                
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: _buildImageButton(
                                        'Camera',
                                        Icons.camera_alt_rounded,
                                        ImageSource.camera,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _buildImageButton(
                                        'Gallery',
                                        Icons.photo_library_rounded,
                                        ImageSource.gallery,
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Colors.grey.shade300,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    onPressed: _isLoading ? null : _assessPlantHealth,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : const Text(
                                            'ASSESS PLANT HEALTH',
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
                        
                        // Error Message
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.only(top: 20),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.shade200,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.red.shade700,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // Results Section
                        if (_showResults) ...[
                          const SizedBox(height: 32),
                          _buildHealthSummary(),
                          const SizedBox(height: 20),
                          ..._buildDiseaseResults(),
                          const SizedBox(height: 32),
                        ],
                      ],
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

  Widget _buildImageButton(String text, IconData icon, ImageSource source) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.green.shade700,
        elevation: 0,
        side: BorderSide(color: Colors.green.shade200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      onPressed: () => _getImage(source),
      icon: Icon(icon),
      label: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildHealthSummary() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: _isHealthy ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isHealthy ? Icons.check_circle : Icons.warning,
                  color: _isHealthy ? Colors.green.shade600 : Colors.red.shade600,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  _isHealthy ? 'HEALTHY PLANT' : 'POSSIBLE DISEASE DETECTED',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _isHealthy ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _healthProbability / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: _isHealthy 
                      ? Colors.green.shade600 
                      : Colors.red.shade600,
                  minHeight: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Health confidence: ${_healthProbability.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _isHealthy
                    ? Colors.green.shade700
                    : Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDiseaseResults() {
    if (_isHealthy || _diseaseSuggestions.isEmpty) {
      return [];
    }

    return [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          'DISEASE DETAILS',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade900,
          ),
        ),
      ),
      const SizedBox(height: 8),
      ..._diseaseSuggestions.map((disease) => _buildDiseaseCard(disease)),
    ];
  }

  Future<void> _saveDiseaseDetection(Map<String, dynamic> disease) async {
    try {
      // Save to Firebase
      await FirebaseFirestore.instance.collection('diseaseHistory').add({
        'diseaseName': disease['name'],
        'probability': disease['probability'],
        'timestamp': FieldValue.serverTimestamp(),
        'diseaseImage': _imageFile != null ? base64Encode(_imageFile!.readAsBytesSync()) : null,
        'diseaseDesc': disease['description'],
        'plantTreat': disease['treatment'] is Map 
            ? jsonEncode(disease['treatment'])
            : disease['treatment'],
        'diseasePrevent': disease['treatment'] is Map && disease['treatment']['prevention'] != null
            ? disease['treatment']['prevention']
            : '',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Disease detection saved to history!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving disease detection: $e'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getSavedDiseaseDetections() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDiseases = prefs.getStringList('savedDiseases') ?? [];
    
    return savedDiseases.map((diseaseJson) => 
      jsonDecode(diseaseJson) as Map<String, dynamic>
    ).toList();
  }

  Widget _buildDiseaseCard(Map<String, dynamic> disease) {
    final treatment = disease['treatment'] is Map ? disease['treatment'] : {};
    
    String formatTreatment(dynamic treatmentData) {
      if (treatmentData is List) {
        return treatmentData.join('\n• ');
      } else if (treatmentData is String) {
        return treatmentData;
      } else {
        return 'No treatment specified';
      }
    }

    final biologicalTreatment = formatTreatment(treatment['biological']);
    final chemicalTreatment = formatTreatment(treatment['chemical']);
    final prevention = formatTreatment(treatment['prevention']);

    // Redesigned disease card with improved visual hierarchy and cleaner layout
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Disease Header with colored background
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        disease['local_name']?.toString() ?? disease['name']?.toString() ?? 'Unknown Disease',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${(disease['probability'] as num? ?? 0.0).toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (disease['classification'] is List && (disease['classification'] as List).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Classification: ${(disease['classification'] as List).join(' > ')}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Content with action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _saveDiseaseDetection(disease),
                      icon: const Icon(Icons.save_alt),
                      label: const Text('SAVE'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (disease['url'] != null)
                      OutlinedButton.icon(
                        onPressed: () => _launchDiseaseInfo(disease['url'].toString()),
                        icon: const Icon(Icons.link),
                        label: const Text('LEARN MORE'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Description Section
                if (disease['description'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.description_outlined, color: Colors.blue.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'DESCRIPTION',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          disease['description'].toString(),
                          style: TextStyle(
                            height: 1.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Cause Section
                if (disease['cause'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'CAUSE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          disease['cause'].toString(),
                          style: TextStyle(
                            height: 1.5,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Treatment Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.healing, color: Colors.green.shade700, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'TREATMENT',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      
                      // Biological Treatment
                      if (biologicalTreatment.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Biological:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          biologicalTreatment,
                          style: TextStyle(
                            height: 1.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                      
                      // Chemical Treatment
                      if (chemicalTreatment.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Chemical:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          chemicalTreatment,
                          style: TextStyle(
                            height: 1.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Prevention Section
                if (prevention.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined, color: Colors.amber.shade800, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'PREVENTION',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          prevention,
                          style: TextStyle(
                            height: 1.5,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
} 