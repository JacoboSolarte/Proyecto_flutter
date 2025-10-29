import '../entities/maintenance.dart';
import '../repositories/maintenance_repository.dart';

class CreateMaintenanceUseCase {
  final MaintenanceRepository _repo;
  CreateMaintenanceUseCase(this._repo);

  Future<Maintenance> call(Maintenance maintenance) {
    return _repo.create(maintenance);
  }
}