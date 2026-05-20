import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../post/domain/post_model.dart';
import '../../data/profile_repository.dart';
import '../../domain/profile_model.dart';

final profileProvider = FutureProvider<UserProfile>((ref) {
  return ref.read(profileRepositoryProvider).getProfile();
});

final myPostsProvider = FutureProvider<List<Post>>((ref) {
  return ref.read(profileRepositoryProvider).getMyPosts();
});
