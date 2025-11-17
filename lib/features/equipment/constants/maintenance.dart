// Tipos de mantenimiento (valores fijos del sistema)
class MaintenanceTypes {
  static const String preventivo = 'preventivo';
  static const String correctivo = 'correctivo';

  static const List<String> values = <String>[
    preventivo,
    correctivo,
  ];

  static String label(String value) {
    switch (value) {
      case preventivo:
        return 'Preventivo';
      case correctivo:
        return 'Correctivo';
      default:
        final t = value.replaceAll('_', ' ').trim();
        return t.isEmpty ? value : t[0].toUpperCase() + t.substring(1);
    }
  }
}