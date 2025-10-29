import 'package:flutter/material.dart';

class EquipmentStatusChip extends StatelessWidget {
  final String status;
  const EquipmentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Map<String, Color> colors = {
      'operativo': Colors.green,
      'mantenimiento': Colors.orange,
      'fuera_de_servicio': Colors.red,
    };
    final Color base = colors[status] ?? scheme.primary;
    final Color bg = base.withValues(alpha: 0.15);
    final Color fg = base;
    String label = switch (status) {
      'operativo' => 'Operativo',
      'mantenimiento' => 'Mantenimiento',
      'fuera_de_servicio' => 'Fuera de servicio',
      _ => status,
    };
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w600),
      backgroundColor: bg,
      side: BorderSide(color: fg.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}