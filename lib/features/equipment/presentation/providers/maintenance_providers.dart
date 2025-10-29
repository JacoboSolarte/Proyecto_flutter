import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/maintenance_repository_impl.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/usecases/create_maintenance.dart';
import '../../domain/usecases/list_maintenances_for_equipment.dart';
import '../../domain/entities/maintenance.dart';
import 'equipment_providers.dart' show supabaseClientProvider; // reuse client

final maintenanceRepositoryProvider = Provider<MaintenanceRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MaintenanceRepositoryImpl(client);
});

final createMaintenanceUseCaseProvider = Provider<CreateMaintenanceUseCase>((ref) {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return CreateMaintenanceUseCase(repo);
});

final listMaintenancesForEquipmentUseCaseProvider = Provider<ListMaintenancesForEquipmentUseCase>((ref) {
  final repo = ref.watch(maintenanceRepositoryProvider);
  return ListMaintenancesForEquipmentUseCase(repo);
});

final maintenancesByEquipmentProvider = FutureProvider.family<List<Maintenance>, String>((ref, equipmentId) {
  final uc = ref.watch(listMaintenancesForEquipmentUseCaseProvider);
  return uc(equipmentId);
});