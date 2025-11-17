import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/repositories/equipment_repository.dart';

class EquipmentRepositoryImpl implements EquipmentRepository {
  final SupabaseClient _client;
  final String _table = 'equipments';

  EquipmentRepositoryImpl(this._client);

  @override
  Future<List<Equipment>> list({int limit = 20, int offset = 0, EquipmentQuery? query}) async {
    var builder = _client.from(_table).select('*');
    if (query != null) {
      final search = query.search;
      final status = query.status;
      final location = query.location;
      if (search != null && search.isNotEmpty) {
        builder = builder.or('name.ilike.%$search%,brand.ilike.%$search%,model.ilike.%$search%,serial.ilike.%$search%,location.ilike.%$search%');
      }
      if (status != null && status.isNotEmpty) {
        builder = builder.eq('status', status);
      }
      if (location != null && location.isNotEmpty) {
        builder = builder.ilike('location', '%$location%');
      }
    }
    final data = await builder.order('created_at', ascending: false).range(offset, offset + limit - 1);

    final list = (data as List).map((e) => Equipment.fromMap(e as Map<String, dynamic>)).toList();
    return list;
  }

  @override
  Future<Equipment> getById(String id) async {
    final data = await _client.from(_table).select('*').eq('id', id).single();
    return Equipment.fromMap(data);
  }

  @override
  Future<Equipment> create(Equipment equipment, {required String userId}) async {
    final payload = equipment.toInsertMap(userId: userId);
    final data = await _client.from(_table).insert(payload).select('*').single();
    return Equipment.fromMap(data);
  }

  @override
  Future<Equipment> update(String id, Equipment equipment) async {
    final payload = equipment.toUpdateMap();
    final data = await _client.from(_table).update(payload).eq('id', id).select('*').single();
    return Equipment.fromMap(data);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}