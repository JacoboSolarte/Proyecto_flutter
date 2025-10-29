class Maintenance {
  final String id;
  final String equipmentId;
  final DateTime maintenanceDate;
  final String maintenanceType; // 'preventivo' | 'correctivo'
  final String? description;
  final String? partsUsed;
  final String? responsible;
  final String finalStatus; // 'operativo' | 'requiere_seguimiento' | 'fuera_de_servicio'
  final DateTime? nextMaintenanceDate;
  final DateTime? createdAt;

  Maintenance({
    required this.id,
    required this.equipmentId,
    required this.maintenanceDate,
    required this.maintenanceType,
    required this.finalStatus,
    this.description,
    this.partsUsed,
    this.responsible,
    this.nextMaintenanceDate,
    this.createdAt,
  });

  factory Maintenance.fromMap(Map<String, dynamic> map) {
    return Maintenance(
      id: map['id'] as String,
      equipmentId: map['equipment_id'] as String,
      maintenanceDate: DateTime.parse(map['maintenance_date'] as String),
      maintenanceType: map['maintenance_type'] as String,
      description: map['description'] as String?,
      partsUsed: map['parts_used'] as String?,
      responsible: map['responsible'] as String?,
      finalStatus: map['final_status'] as String,
      nextMaintenanceDate: map['next_maintenance_date'] != null
          ? DateTime.parse(map['next_maintenance_date'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'equipment_id': equipmentId,
      'maintenance_date': maintenanceDate.toIso8601String(),
      'maintenance_type': maintenanceType,
      'description': description,
      'parts_used': partsUsed,
      'responsible': responsible,
      'final_status': finalStatus,
      'next_maintenance_date': nextMaintenanceDate?.toIso8601String(),
    };
  }
}