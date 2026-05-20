class AuthUser {
  final int id;
  final String name;
  final String email;
  final String? profilePhoto;

  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    this.profilePhoto,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as int,
        name: (json['full_name'] ?? json['username'] ?? '') as String,
        email: json['email'] as String,
        profilePhoto: json['profile_picture'] as String?,
      );
}
