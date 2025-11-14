import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../../domain/usecases/request_password_reset_usecase.dart';
import '../../domain/usecases/reset_password_usecase.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthRepositoryImpl(client);
});

final currentUserStreamProvider = StreamProvider<AppUser?>((ref) {
  return ref.watch(authRepositoryProvider).onAuthUserChanges();
});

class AuthController extends StateNotifier<AsyncValue<AppUser?>> {
  AuthController(
    this._login,
    this._register,
    this._logout,
    this._update,
    this._requestReset,
    this._resetPassword,
    this._repo,
  ) : super(const AsyncValue.loading()) {
    _init();
  }

  final LoginUseCase _login;
  final RegisterUseCase _register;
  final LogoutUseCase _logout;
  final UpdateProfileUseCase _update;
  final RequestPasswordResetUseCase _requestReset;
  final ResetPasswordUseCase _resetPassword;
  final AuthRepository _repo;

  Future<void> _init() async {
    final user = await _repo.getCurrentUser();
    state = AsyncValue.data(user);
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await _login(email: email, password: password);
      final user = await _repo.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signUp(String email, String password, String name) async {
    state = const AsyncValue.loading();
    try {
      await _register(email: email, password: password, name: name);
      final user = await _repo.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await _logout();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateName(String name) async {
    try {
      await _update(name: name);
      final user = await _repo.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> sendPasswordResetEmail(
    String email, {
    String? redirectTo,
  }) async {
    // No cambiamos el estado global del usuario aquí; dejamos la UI manejar feedback
    try {
      await _requestReset(email: email, redirectTo: redirectTo);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> setNewPassword(String newPassword) async {
    try {
      await _resetPassword(newPassword: newPassword);
      final user = await _repo.getCurrentUser();
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AsyncValue<AppUser?>>((ref) {
      final repo = ref.watch(authRepositoryProvider);
      return AuthController(
        LoginUseCase(repo),
        RegisterUseCase(repo),
        LogoutUseCase(repo),
        UpdateProfileUseCase(repo),
        RequestPasswordResetUseCase(repo),
        ResetPasswordUseCase(repo),
        repo,
      );
    });
