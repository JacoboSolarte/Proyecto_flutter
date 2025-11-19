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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 400;
        final isVeryNarrow = constraints.maxWidth < 320;
        final spacing = isVeryNarrow ? 6.0 : (isNarrow ? 8.0 : 10.0);
        final padding = EdgeInsets.all(isNarrow ? 10 : 12);
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: padding,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _summaryChip(
                  context,
                  label: 'Total',
                  icon: Icons.list_alt,
                  count: total,
                  color: Theme.of(context).colorScheme.primary,
                  compact: isNarrow,
                ),
                _summaryChip(
                  context,
                  label: EquipmentStatus.label(EquipmentStatus.operativo),
                  icon: Icons.check_circle,
                  count: countOperativo,
                  color: Colors.green,
                  compact: isNarrow,
                ),
                _summaryChip(
                  context,
                  label: EquipmentStatus.label(EquipmentStatus.mantenimiento),
                  icon: Icons.build_circle,
                  count: countMantenimiento,
                  color: Colors.amber,
                  compact: isNarrow,
                ),
                _summaryChip(
                  context,
                  label: EquipmentStatus.label(EquipmentStatus.fueraDeServicio),
                  icon: Icons.report,
                  count: countFueraServicio,
                  color: Colors.red,
                  compact: isNarrow,
                ),
                _summaryChip(
                  context,
                  label: EquipmentStatus.label(
                    EquipmentStatus.requiereSeguimiento,
                  ),
                  icon: Icons.track_changes,
                  count: countSeguimiento,
                  color: Colors.blueGrey,
                  compact: isNarrow,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _summaryChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required int count,
    required Color color,
    bool compact = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color.withValues(alpha: 0.10);
    final border = color.withValues(alpha: 0.25);
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: scheme.onSurface,
      fontSize: compact ? 12 : 13,
      fontWeight: FontWeight.w500,
    );
    return Chip(
      avatar: Icon(icon, color: color, size: compact ? 16 : 18),
      label: Text('$label: $count', style: textStyle),
      backgroundColor: bg,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
    );
  }
}