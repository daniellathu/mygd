import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pigeon_user_details.dart'; // Import our dummy class

class UserProfile with ChangeNotifier {
  String? username;
  String? profileImageUrl;
  bool isLoading = false;
  DateTime? dateOfBirth;
  String? gender;
  String? userId;
  PigeonUserDetails? pigeonUserDetails;

  // Helper method to get profile image URL
  String getProfileImageUrl() {
    if (profileImageUrl == null || profileImageUrl!.isEmpty) {
      return '';
    }
    
    // Return the URL as is since it's already a Firebase Storage URL
    return profileImageUrl!;
  }

  Future<void> loadUserData() async {
    try {
      print("Loading user data...");
      
      // Clear existing user data to prevent conflicts
      clearUserData();
      
      // Get the current user ID
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        print("No user is signed in");
        return;
      }
      
      userId = currentUser.uid;
      print("Loading data for user ID: $userId");
      
      // Try to get the user's display name from Firebase Auth
      if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
        username = currentUser.displayName!;
        print("Username from Auth: $username");
      }
      
      // Get user data from Firestore
      final docSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .doc(userId)
          .get();
      
      if (docSnapshot.exists) {
        final userData = docSnapshot.data() as Map<String, dynamic>;
        
        // Safely retrieve user data with null checks and type checking
        try {
          if (userData.containsKey('username') && userData['username'] != null) {
            username = userData['username'].toString();
          }
          
          if (userData.containsKey('profileImageUrl') && userData['profileImageUrl'] != null) {
            profileImageUrl = userData['profileImageUrl'].toString();
            print("Loaded profile image URL: $profileImageUrl");
          }
          
          if (userData.containsKey('dateOfBirth') && userData['dateOfBirth'] != null) {
            final dob = userData['dateOfBirth'];
            if (dob is Timestamp) {
              dateOfBirth = dob.toDate();
            }
          }
          
          if (userData.containsKey('gender') && userData['gender'] != null) {
            gender = userData['gender'].toString();
          }
          
          // Skip pigeonUserDetails processing to avoid type casting errors
          print("User data loaded successfully: Username=$username, ProfileImage=$profileImageUrl");
        } catch (e) {
          print("Error parsing user data fields: $e");
          // If we have basic auth data, keep it
          if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
            username = currentUser.displayName!;
          }
        }
      } else {
        print("User document doesn't exist in Firestore");
        // If we have basic auth data, keep it
        if (currentUser.displayName != null && currentUser.displayName!.isNotEmpty) {
          username = currentUser.displayName!;
        }
      }
      
      // Update the state to notify listeners of changes
      notifyListeners();
    } catch (e) {
      print("Error loading user data: $e");
      // If we have basic auth data, keep it
      if (FirebaseAuth.instance.currentUser?.displayName != null) {
        username = FirebaseAuth.instance.currentUser!.displayName!;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String newUsername,
    required DateTime? newDateOfBirth,
    required String? newGender,
    required String? newProfileImageUrl,
  }) async {
    isLoading = true;
    notifyListeners();

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Create a data map to update in Firestore
        Map<String, dynamic> userData = {
          'username': newUsername,
        };
        
        // Only add non-null values
        if (newDateOfBirth != null) {
          userData['dateOfBirth'] = Timestamp.fromDate(newDateOfBirth);
        }
        
        if (newGender != null) {
          userData['gender'] = newGender;
        }
        
        // Only update the profile image URL if a new one is provided
        if (newProfileImageUrl != null) {
          print('Updating profile image URL to: $newProfileImageUrl');
          userData['profileImageUrl'] = newProfileImageUrl;
          profileImageUrl = newProfileImageUrl;
        }

        print('Updating user profile with data: $userData');

        // Update Firestore
        await FirebaseFirestore.instance.collection('Users').doc(user.uid).set(
          userData,
          SetOptions(merge: true),
        );

        // Update local state
        username = newUsername;
        dateOfBirth = newDateOfBirth;
        gender = newGender;

        // Update Firebase Auth
        try {
          await user.updateDisplayName(newUsername);
        } catch (e) {
          print('Error updating Firebase Auth user profile: $e');
          // Continue even if Auth update fails
        }

        notifyListeners();
      }
    } catch (e) {
      print('Error updating profile in Firestore: $e');
      rethrow;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // Clear all user data when logging out
  void clearUserData({bool notifyAfterClear = true}) {
    print('Clearing all user profile data');
    username = null;
    profileImageUrl = null;
    dateOfBirth = null;
    gender = null;
    isLoading = false;
    pigeonUserDetails = null;
    
    if (notifyAfterClear) {
      notifyListeners();
    }
  }
}