import '../entities/maintenance.dart';

abstract class MaintenanceRepository {
  Future<Maintenance> create(Maintenance maintenance);
  Future<List<Maintenance>> listByEquipment(String equipmentId);
}
