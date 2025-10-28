import '../repositories/equipment_repository.dart';

class DeleteEquipmentUseCase {
  final EquipmentRepository repository;
  DeleteEquipmentUseCase(this.repository);

  Future<void> call(String id) {
    return repository.delete(id);
  }
}