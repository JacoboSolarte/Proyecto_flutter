import '../entities/equipment.dart';

class EquipmentQuery {
  final String? search;
  final String? status; // operativo/mantenimiento/fuera_de_servicio
  final String? location;

  EquipmentQuery({this.search, this.status, this.location});
}

abstract class EquipmentRepository {
  Future<List<Equipment>> list({int limit, int offset, EquipmentQuery? query});
  Future<Equipment> getById(String id);
  Future<Equipment> create(Equipment equipment, {required String userId});
  Future<Equipment> update(String id, Equipment equipment);
  Future<void> delete(String id);
}