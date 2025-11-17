import '../features/equipment/constants/status.dart';
import '../features/equipment/constants/maintenance.dart';

// Listas de selección para formularios (datos estáticos reutilizables)

// Opciones de tipos de mantenimiento
final List<String> maintenanceTypeOptions = List.unmodifiable(MaintenanceTypes.values);

// Opciones de estado de equipo para formularios
final List<String> equipmentStatusOptions = List.unmodifiable(EquipmentStatus.values);