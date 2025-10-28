import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;
  RegisterUseCase(this.repository);

  Future<void> call({required String email, required String password, required String name}) {
    return repository.signUp(email: email, password: password, name: name);
  }
}