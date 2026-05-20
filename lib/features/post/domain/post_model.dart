import '../../../core/constants/api_constants.dart';

class Post {
  final int id;
  final String title;
  final String? caption;
  final String? imageUrl;
  final String? habitTitle;
  final double? progressPercent;
  final int likesCount;
  final int commentsCount;
  final bool likedByMe;
  final bool isMine;
  final String frameStyle;
  final PostUser user;
  final String createdAt;

  const Post({
    required this.id,
    required this.title,
    this.caption,
    this.imageUrl,
    this.habitTitle,
    this.progressPercent,
    required this.likesCount,
    required this.commentsCount,
    required this.likedByMe,
    required this.isMine,
    required this.frameStyle,
    required this.user,
    required this.createdAt,
  });

  bool get isCircular => frameStyle != 'rect';

  factory Post.fromJson(Map<String, dynamic> json) {
    final raw = json['image_url'] as String?;
    String? url;
    if (raw != null && raw.isNotEmpty) {
      url = raw.startsWith('http') ? raw : '${ApiConstants.serverUrl}$raw';
    }
    return Post(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      caption: json['caption'] as String?,
      imageUrl: url,
      habitTitle: json['habit_title'] as String?,
      progressPercent: json['progress_percent'] != null
          ? double.tryParse(json['progress_percent'].toString())
          : null,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      isMine: json['is_mine'] as bool? ?? false,
      frameStyle: json['frame_style'] as String? ?? 'rect',
      user: PostUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  Post copyWith({bool? likedByMe, int? likesCount, int? commentsCount}) => Post(
        id: id,
        title: title,
        caption: caption,
        imageUrl: imageUrl,
        habitTitle: habitTitle,
        progressPercent: progressPercent,
        likesCount: likesCount ?? this.likesCount,
        commentsCount: commentsCount ?? this.commentsCount,
        likedByMe: likedByMe ?? this.likedByMe,
        isMine: isMine,
        frameStyle: frameStyle,
        user: user,
        createdAt: createdAt,
      );
}

class PostUser {
  final int id;
  final String username;
  final String? fullName;
  final String? profilePicture;

  const PostUser({
    required this.id,
    required this.username,
    this.fullName,
    this.profilePicture,
  });

  String get displayName =>
      (fullName?.isNotEmpty ?? false) ? fullName! : username;

  String get initials {
    final words = displayName.split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) return '${words[0][0]}${words[1][0]}'.toUpperCase();
    if (words.isNotEmpty) return words[0][0].toUpperCase();
    return 'U';
  }

  factory PostUser.fromJson(Map<String, dynamic> json) => PostUser(
        id: (json['id'] as num?)?.toInt() ?? 0,
        username: json['username'] as String? ?? '',
        fullName: json['full_name'] as String?,
        profilePicture: json['profile_picture'] as String?,
      );
}

class Comment {
  final int id;
  final String content;
  final PostUser user;
  final String createdAt;

  const Comment({
    required this.id,
    required this.content,
    required this.user,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: (json['id'] as num).toInt(),
        content: json['content'] as String? ?? '',
        user: PostUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
        createdAt: json['created_at'] as String? ?? '',
      );
}
