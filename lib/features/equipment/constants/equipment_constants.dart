// Constantes específicas del módulo de Equipos
// Reexporta constantes de estado y tipos de mantenimiento del sistema
export 'status.dart';
export 'maintenance.dart';

// Acciones del menú contextual en tarjetas de equipo
class EquipmentActions {
  static const String header = 'header';
  static const String maintenance = 'maintenance';
  static const String edit = 'edit';
  static const String delete = 'delete';

  static const List<String> values = [header, maintenance, edit, delete];
}