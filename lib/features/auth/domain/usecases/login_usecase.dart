import '../repositories/auth_repository.dart';

class LoginUseCase {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  Future<void> call({required String email, required String password}) {
    return repository.signIn(email: email, password: password);
  }
}