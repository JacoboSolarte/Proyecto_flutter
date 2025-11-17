import '../../constants/status.dart';

class Equipment {
  final String id;
  final String name;
  final String? brand;
  final String? model;
  final String? serial;
  final String? location;
  final String status; // operativo | mantenimiento | fuera_de_servicio
  final DateTime? purchaseDate;
  final DateTime? lastMaintenanceDate;
  final DateTime? nextMaintenanceDate;
  final String? vendor;
  final DateTime? warrantyExpireDate;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;

  Equipment({
    required this.id,
    required this.name,
    this.brand,
    this.model,
    this.serial,
    this.location,
    required this.status,
    this.purchaseDate,
    this.lastMaintenanceDate,
    this.nextMaintenanceDate,
    this.vendor,
    this.warrantyExpireDate,
    this.notes,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
  });

  factory Equipment.fromMap(Map<String, dynamic> map) {
    DateTime? _parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return Equipment(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String?,
      model: map['model'] as String?,
      serial: map['serial'] as String?,
      location: map['location'] as String?,
      status: (map['status'] as String?) ?? EquipmentStatus.operativo,
      purchaseDate: _parseDate(map['purchase_date']),
      lastMaintenanceDate: _parseDate(map['last_maintenance_date']),
      nextMaintenanceDate: _parseDate(map['next_maintenance_date']),
      vendor: map['vendor'] as String?,
      warrantyExpireDate: _parseDate(map['warranty_expire_date']),
      notes: map['notes'] as String?,
      createdAt: _parseDate(map['created_at']),
      updatedAt: _parseDate(map['updated_at']),
      createdBy: map['created_by'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap({required String userId}) {
    return {
      'name': name,
      'brand': brand,
      'model': model,
      'serial': serial,
      'location': location,
      'status': status,
      'purchase_date': purchaseDate?.toIso8601String(),
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
      'next_maintenance_date': nextMaintenanceDate?.toIso8601String(),
      'vendor': vendor,
      'warranty_expire_date': warrantyExpireDate?.toIso8601String(),
      'notes': notes,
      'created_by': userId,
    }..removeWhere((key, value) => value == null);
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'name': name,
      'brand': brand,
      'model': model,
      'serial': serial,
      'location': location,
      'status': status,
      'purchase_date': purchaseDate?.toIso8601String(),
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
      'next_maintenance_date': nextMaintenanceDate?.toIso8601String(),
      'vendor': vendor,
      'warranty_expire_date': warrantyExpireDate?.toIso8601String(),
      'notes': notes,
    }..removeWhere((key, value) => value == null);
  }
}