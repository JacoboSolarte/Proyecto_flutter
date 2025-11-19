import 'package:flutter/material.dart';
import '../../constants/status.dart';

class EquipmentStatusChip extends StatelessWidget {
  final String status;
  const EquipmentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Map<String, Color> colors = {
      EquipmentStatus.operativo: Colors.green,
      EquipmentStatus.mantenimiento: Colors.amber,
      EquipmentStatus.fueraDeServicio: Colors.red,
      EquipmentStatus.requiereSeguimiento: Colors.blueGrey,
    };
    final Color base = colors[status] ?? scheme.primary;
    final Color bg = base.withValues(alpha: 0.15);
    final Color fg = base;
    final String label = EquipmentStatus.label(status);
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: fg, fontWeight: FontWeight.w600),
      backgroundColor: bg,
      side: BorderSide(color: fg.withValues(alpha: 0.4)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    );
  }
}