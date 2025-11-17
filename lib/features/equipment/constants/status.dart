// Estados de equipo (valores fijos del sistema)
class EquipmentStatus {
  static const String operativo = 'operativo';
  static const String mantenimiento = 'mantenimiento';
  static const String fueraDeServicio = 'fuera_de_servicio';
  static const String requiereSeguimiento = 'requiere_seguimiento';

  static const List<String> values = <String>[
    operativo,
    mantenimiento,
    fueraDeServicio,
    requiereSeguimiento,
  ];

  static String label(String value) {
    switch (value) {
      case operativo:
        return 'Operativo';
      case mantenimiento:
        return 'Mantenimiento';
      case fueraDeServicio:
        return 'Fuera de servicio';
      case requiereSeguimiento:
        return 'Requiere seguimiento';
      default:
        final t = value.replaceAll('_', ' ').trim();
        return t.isEmpty ? value : t[0].toUpperCase() + t.substring(1);
    }
  }
}
