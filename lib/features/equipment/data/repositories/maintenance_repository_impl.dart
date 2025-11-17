import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/maintenance.dart';
import '../../domain/repositories/maintenance_repository.dart';

class MaintenanceRepositoryImpl implements MaintenanceRepository {
  final SupabaseClient _client;
  MaintenanceRepositoryImpl(this._client);

  static const String table = 'maintenances';

  @override
  Future<Maintenance> create(Maintenance maintenance) async {
    final response = await _client
        .from(table)
        .insert(maintenance.toInsertMap())
        .select()
        .single();
    return Maintenance.fromMap(response);
  }

  @override
  Future<List<Maintenance>> listByEquipment(String equipmentId) async {
    final response = await _client
        .from(table)
        .select()
        .eq('equipment_id', equipmentId)
        .order('maintenance_date', ascending: false);
    final list = (response as List)
        .map((e) => Maintenance.fromMap(e as Map<String, dynamic>))
        .toList();
    return list;
  }
}
