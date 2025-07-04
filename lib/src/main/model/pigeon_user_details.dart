/// Dummy implementation of PigeonUserDetails to handle type casting errors
class PigeonUserDetails {
  final String? id;
  final String? email;
  final String? username;
  
  PigeonUserDetails({this.id, this.email, this.username});
  
  /// Factory to create from a List or Map, which seems to be what's happening during the error
  factory PigeonUserDetails.fromAny(dynamic data) {
    if (data == null) {
      return PigeonUserDetails();
    }
    
    if (data is List) {
      // Handle List case that's causing the error
      return PigeonUserDetails(
        id: data.isNotEmpty && data[0] != null ? data[0].toString() : null,
        email: data.length > 1 && data[1] != null ? data[1].toString() : null,
        username: data.length > 2 && data[2] != null ? data[2].toString() : null,
      );
    }
    
    if (data is Map) {
      return PigeonUserDetails(
        id: data['id']?.toString(),
        email: data['email']?.toString(),
        username: data['username']?.toString(),
      );
    }
    
    // Default case
    return PigeonUserDetails();
  }
} 