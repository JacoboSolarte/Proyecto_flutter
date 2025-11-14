import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class ListMaintenancesForEquipmentUseCase {
  final MaintenanceRepository _repo;
  ListMaintenancesForEquipmentUseCase(this._repo);

  Future<List<Maintenance>> call(String equipmentId) {
    return _repo.listByEquipment(equipmentId);
  }
}
