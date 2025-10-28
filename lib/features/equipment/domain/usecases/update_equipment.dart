import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

class UpdateEquipmentUseCase {
  final EquipmentRepository repository;
  UpdateEquipmentUseCase(this.repository);

  Future<Equipment> call(String id, Equipment equipment) {
    return repository.update(id, equipment);
  }
}