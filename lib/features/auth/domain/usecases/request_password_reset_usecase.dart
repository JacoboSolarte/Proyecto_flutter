import '../repositories/auth_repository.dart';

class RequestPasswordResetUseCase {
  final AuthRepository repository;
  RequestPasswordResetUseCase(this.repository);

  Future<void> call({required String email, String? redirectTo}) {
    return repository.requestPasswordReset(email: email, redirectTo: redirectTo);
  }
}