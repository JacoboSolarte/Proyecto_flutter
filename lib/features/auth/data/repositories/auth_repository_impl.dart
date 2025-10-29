import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient _client;

  AuthRepositoryImpl(this._client);

  @override
  Future<AppUser?> getCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final name = user.userMetadata?['name'] as String?;
    return AppUser(id: user.id, email: user.email, name: name);
  }

  @override
  Stream<AppUser?> onAuthUserChanges() {
    return _client.auth.onAuthStateChange.map((event) {
      final user = event.session?.user;
      if (user == null) return null;
      final name = user.userMetadata?['name'] as String?;
      return AppUser(id: user.id, email: user.email, name: name);
    });
  }

  @override
  Future<void> signUp({required String email, required String password, required String name}) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<void> updateProfile({String? name, String? email}) async {
    await _client.auth.updateUser(
      UserAttributes(
        email: email,
        data: name != null ? {'name': name} : null,
      ),
    );
  }

  @override
  Future<void> requestPasswordReset({required String email, String? redirectTo}) async {
    await _client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
  }

  @override
  Future<void> resetPassword({required String newPassword}) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}