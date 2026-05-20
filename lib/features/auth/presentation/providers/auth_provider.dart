import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/auth_model.dart';
import '../../../../core/storage/secure_storage.dart';

// Current logged-in user
final currentUserProvider = StateProvider<AuthUser?>((ref) => null);

// Auth state: loading user on app start
final authInitProvider = FutureProvider<AuthUser?>((ref) async {
  final storage = ref.read(secureStorageProvider);
  if (!await storage.hasToken()) return null;
  try {
    final user = await ref.read(authRepositoryProvider).me();
    ref.read(currentUserProvider.notifier).state = user;
    return user;
  } catch (_) {
    await storage.clearToken();
    return null;
  }
});

// Login state
class LoginNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;
  final Ref _ref;

  LoginNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repo.login(email, password);
      final user = await _repo.me();
      _ref.read(currentUserProvider.notifier).state = user;
    });
  }

  void reset() => state = const AsyncValue.data(null);
}

final loginProvider = StateNotifierProvider<LoginNotifier, AsyncValue<void>>((ref) {
  return LoginNotifier(ref.read(authRepositoryProvider), ref);
});

// Register state
class RegisterNotifier extends StateNotifier<AsyncValue<void>> {
  final AuthRepository _repo;

  RegisterNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.register(
          name: name,
          email: email,
          password: password,
          passwordConfirmation: passwordConfirmation,
        ));
  }

  void reset() => state = const AsyncValue.data(null);
}

final registerProvider = StateNotifierProvider<RegisterNotifier, AsyncValue<void>>((ref) {
  return RegisterNotifier(ref.read(authRepositoryProvider));
});

// Logout
final logoutProvider = Provider((ref) {
  return () async {
    await ref.read(authRepositoryProvider).logout();
    ref.read(currentUserProvider.notifier).state = null;
  };
});
