import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

class CreateEquipmentUseCase {
  final EquipmentRepository repository;
  CreateEquipmentUseCase(this.repository);

  Future<Equipment> call(Equipment equipment, {required String userId}) {
    return repository.create(equipment, userId: userId);
  }
}