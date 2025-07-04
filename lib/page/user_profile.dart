import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../src/main/model/user_profile_model.dart';
import '../src/main/services/cloudinary_service.dart';

class UserProfileDialog extends StatefulWidget {
  const UserProfileDialog({super.key});

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  File? _imageFile;
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isUploadingImage = false;
  final CloudinaryService _cloudinaryService = CloudinaryService();

  @override
  void initState() {
    super.initState();
    // Initialize Cloudinary service
    CloudinaryService.ensureInitialized();
    
    final userProfile = Provider.of<UserProfile>(context, listen: false);
    _usernameController = TextEditingController(text: userProfile.username);
    _selectedDate = userProfile.dateOfBirth;
    _selectedGender = userProfile.gender;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorMessage('Error picking image: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF348F50),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      try {
        // First upload image if selected
        String? imageUrl;
        if (_imageFile != null) {
          setState(() => _isUploadingImage = true);
          
          try {
            // Upload to Cloudinary
            imageUrl = await _cloudinaryService.uploadImage(_imageFile!.path);
            if (imageUrl == null) {
              _showErrorMessage('Image upload failed, but other profile details will be updated');
            } else {
              print('Image uploaded successfully to Cloudinary. URL: $imageUrl');
            }
          } catch (e) {
            print('Error during image upload: $e');
            _showErrorMessage('Image upload failed: $e');
          } finally {
            setState(() => _isUploadingImage = false);
          }
        }

        // Update profile with image URL
        await Provider.of<UserProfile>(context, listen: false).updateProfile(
          newUsername: _usernameController.text,
          newDateOfBirth: _selectedDate,
          newGender: _selectedGender,
          newProfileImageUrl: imageUrl,
        );
        
        // Force a rebuild of the home page
        if (mounted) {
          Navigator.of(context).pop();
          // Notify listeners to update the UI
          Provider.of<UserProfile>(context, listen: false).notifyListeners();
        }
      } catch (e) {
        print('Profile update error details: $e');
        _showErrorMessage('Error updating profile: $e');
      }
    }
  }

  String _getProfileImageUrl(UserProfile userProfile) {
    if (userProfile.profileImageUrl == null || userProfile.profileImageUrl!.isEmpty) {
      return '';
    }
    
    // Get the Cloudinary URL
    return CloudinaryService.getImageUrl(userProfile.profileImageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = Provider.of<UserProfile>(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: contentBox(context, userProfile),
    );
  }

  Widget contentBox(BuildContext context, UserProfile userProfile) {
    final String profileImageUrl = _getProfileImageUrl(userProfile);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Edit Profile',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF348F50),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF348F50),
                          width: 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: _imageFile != null
                            ? Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                              )
                            : (profileImageUrl.isNotEmpty
                                ? (profileImageUrl.startsWith('/')
                                    ? Image.file(
                                        File(profileImageUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Error loading local profile image: $error');
                                          return const Center(
                                            child: Icon(Icons.person, size: 50, color: Colors.grey),
                                          );
                                        },
                                      )
                                    : Image.network(
                                        profileImageUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF348F50),
                                              strokeWidth: 2,
                                            ),
                                          );
                                        },
                                        errorBuilder: (context, error, stackTrace) {
                                          print('Error loading profile image: $error');
                                          return const Center(
                                            child: Icon(Icons.person, size: 50, color: Colors.grey),
                                          );
                                        },
                                      ))
                                : const Center(
                                    child: Icon(Icons.person, size: 50, color: Colors.grey),
                                  )),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF348F50),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    if (_isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black26,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'Enter your username',
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF348F50)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.calendar_today, color: Color(0xFF348F50)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedDate == null
                            ? 'Date of Birth'
                            : DateFormat('MMM d, yyyy').format(_selectedDate!),
                        style: TextStyle(
                          color: _selectedDate == null ? Colors.grey.shade600 : Colors.black87,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down, color: Color(0xFF348F50)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.people_outline, color: Color(0xFF348F50)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGender,
                    hint: const Text('Select Gender'),
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF348F50)),
                    items: ['Male', 'Female', 'Other']
                        .map((gender) => DropdownMenuItem(
                              value: gender,
                              child: Text(gender),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _selectedGender = value),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: userProfile.isLoading || _isUploadingImage ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF348F50),
                      foregroundColor: Colors.white,
                      elevation: 5,
                      shadowColor: const Color(0xFF348F50).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: userProfile.isLoading || _isUploadingImage
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}