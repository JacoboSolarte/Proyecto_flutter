import 'package:flutter/material.dart';
import '../../constants/status.dart';

class SummaryBar extends StatelessWidget {
  final int total;
  final int countOperativo;
  final int countMantenimiento;
  final int countFueraServicio;
  final int countSeguimiento;

  const SummaryBar({
    super.key,
    required this.total,
    required this.countOperativo,
    required this.countMantenimiento,
    required this.countFueraServicio,
    required this.countSeguimiento,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _summaryChip(
              context,
              label: 'Total',
              icon: Icons.list_alt,
              count: total,
              color: Theme.of(context).colorScheme.primary,
            ),
            _summaryChip(
              context,
              label: EquipmentStatus.label(EquipmentStatus.operativo),
              icon: Icons.check_circle,
              count: countOperativo,
              color: Colors.green,
            ),
            _summaryChip(
              context,
              label: EquipmentStatus.label(EquipmentStatus.mantenimiento),
              icon: Icons.build_circle,
              count: countMantenimiento,
              color: Colors.amber,
            ),
            _summaryChip(
              context,
              label: EquipmentStatus.label(EquipmentStatus.fueraDeServicio),
              icon: Icons.report,
              count: countFueraServicio,
              color: Colors.red,
            ),
            _summaryChip(
              context,
              label: EquipmentStatus.label(EquipmentStatus.requiereSeguimiento),
              icon: Icons.track_changes,
              count: countSeguimiento,
              color: Colors.blueGrey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required int count,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color.withValues(alpha: 0.10);
    final border = color.withValues(alpha: 0.25);
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text('$label: $count', style: TextStyle(color: scheme.onSurface)),
      backgroundColor: bg,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}
