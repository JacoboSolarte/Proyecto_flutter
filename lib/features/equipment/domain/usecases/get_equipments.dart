import '../entities/equipment.dart';
import '../repositories/equipment_repository.dart';

class GetEquipmentsUseCase {
  final EquipmentRepository repository;
  GetEquipmentsUseCase(this.repository);

  Future<List<Equipment>> call({int limit = 20, int offset = 0, EquipmentQuery? query}) {
    return repository.list(limit: limit, offset: offset, query: query);
  }
}