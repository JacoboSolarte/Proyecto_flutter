import '../entities/app_user.dart';

abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();
  Stream<AppUser?> onAuthUserChanges();

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  });
  Future<void> signIn({required String email, required String password});
  Future<void> signOut();
  Future<void> updateProfile({String? name, String? email});
  Future<void> requestPasswordReset({
    required String email,
    String? redirectTo,
  });
  Future<void> resetPassword({required String newPassword});
}
