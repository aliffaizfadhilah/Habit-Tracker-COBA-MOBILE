class UserProfile {
  final String username;
  final String fullName;
  final String email;
  final bool isVerified;
  final String? profilePicture;

  const UserProfile({
    required this.username,
    required this.fullName,
    required this.email,
    required this.isVerified,
    this.profilePicture,
  });

  String get displayName => fullName.isNotEmpty ? fullName : username;

  String get initials {
    final words = displayName.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    if (words.isNotEmpty) return words[0][0].toUpperCase();
    return 'U';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final data = (json['user'] ?? json['data'] ?? json) as Map<String, dynamic>;
    return UserProfile(
      username: data['username'] as String? ?? '',
      fullName: data['full_name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      isVerified: data['is_verified'] == true || data['is_verified'] == 1,
      profilePicture: data['profile_picture'] as String?,
    );
  }
}
