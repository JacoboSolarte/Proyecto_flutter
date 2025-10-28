import '../repositories/auth_repository.dart';

class UpdateProfileUseCase {
  final AuthRepository repository;
  UpdateProfileUseCase(this.repository);

  Future<void> call({String? name, String? email}) {
    return repository.updateProfile(name: name, email: email);
  }
}