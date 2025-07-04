// FILEPATH: c:/Users/thu/OneDrive/Documents/FYP/MyGd_app/mygd_frontend/lib/src/main/services/cloudinary_service.dart

import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String cloudName = 'dni8bff4z'; // Replace with your cloud name
  static const String apiKey = '262236349362497'; // Replace with your API key
  static const String apiSecret = 'mn3AAogKrYWYVWck2Xs8lNrNRzc'; // Replace with your API secret
  static const String uploadPreset = 'mygd_user_profile'; // Replace with your upload preset

  static void ensureInitialized() {
    // No initialization needed for Cloudinary
  }

  static String getImageUrl(String? imageId) {
    if (imageId == null || imageId.isEmpty) return '';
    
    // If it's already a full URL, return it as is
    if (imageId.startsWith('http')) {
      return imageId;
    }
    
    // If it's a Cloudinary public ID, construct the URL
    return 'https://res.cloudinary.com/$cloudName/image/upload/$imageId';
  }
  
  Future<String?> uploadImage(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        print('File does not exist: $imagePath');
        return null;
      }

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );

      // Add file to request
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
        ),
      );

      // Add other parameters
      request.fields['api_key'] = apiKey;
      request.fields['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
      request.fields['upload_preset'] = uploadPreset;

      // Send request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = json.decode(responseData);

      if (response.statusCode == 200) {
        print('Image uploaded successfully to Cloudinary');
        return jsonResponse['secure_url'];
      } else {
        print('Failed to upload image to Cloudinary: ${jsonResponse['error']}');
        return null;
      }
    } catch (e) {
      print('Exception during Cloudinary upload: $e');
      return null;
    }
  }
}