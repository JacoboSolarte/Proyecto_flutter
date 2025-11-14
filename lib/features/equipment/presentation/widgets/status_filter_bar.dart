import 'package:flutter/material.dart';

class StatusFilterBar extends StatelessWidget {
  final String? selectedStatus;
  final int total;
  final int countOperativo;
  final int countMantenimiento;
  final int countFueraServicio;
  final int countSeguimiento;
  final void Function(String? status) onStatusSelected;

  const StatusFilterBar({
    super.key,
    required this.selectedStatus,
    required this.total,
    required this.countOperativo,
    required this.countMantenimiento,
    required this.countFueraServicio,
    required this.countSeguimiento,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _statusChip(context, null, 'Todos', count: total),
          _statusChip(context, 'operativo', 'Operativo', count: countOperativo),
          _statusChip(context, 'mantenimiento', 'Mantenimiento', count: countMantenimiento),
          _statusChip(context, 'fuera_de_servicio', 'Fuera de servicio', count: countFueraServicio),
          _statusChip(context, 'requiere_seguimiento', 'Requiere seguimiento', count: countSeguimiento),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, String? value, String label, {int? count}) {
    final selected = selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(count == null ? label : '$label ($count)'),
        selected: selected,
        onSelected: (isSelected) {
          onStatusSelected(isSelected ? value : null);
        },
      ),
    );
  }
}