import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

class GetEquipmentDetailUseCase {
  final EquipmentRepository repository;
  GetEquipmentDetailUseCase(this.repository);

  Future<Equipment> call(String id) {
    return repository.getById(id);
  }
}