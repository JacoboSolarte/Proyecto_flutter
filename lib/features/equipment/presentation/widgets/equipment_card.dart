import 'package:flutter/material.dart';
import '../../../equipment/domain/entities/equipment.dart';
import 'equipment_status_chip.dart';

class EquipmentCard extends StatelessWidget {
  final Equipment equipment;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onHeader;
  final VoidCallback? onAddMaintenance;

  const EquipmentCard({
    super.key,
    required this.equipment,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onHeader,
    this.onAddMaintenance,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.precision_manufacturing, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            equipment.name,
                            style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ),
                        EquipmentStatusChip(status: equipment.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (equipment.brand != null)
                          _InfoChip(icon: Icons.business, label: 'Marca: ${equipment.brand}'),
                        if (equipment.model != null)
                          _InfoChip(icon: Icons.layers, label: 'Modelo: ${equipment.model}'),
                        if (equipment.serial != null)
                          _InfoChip(icon: Icons.qr_code_2, label: 'Serie: ${equipment.serial}'),
                        if (equipment.location != null)
                          _InfoChip(icon: Icons.place, label: 'Ubicación: ${equipment.location}'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ActionsMenu(onEdit: onEdit, onDelete: onDelete, onHeader: onHeader, onAddMaintenance: onAddMaintenance),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    // Limitar el ancho para permitir salto de línea sin overflow en móvil.
    // Damos más espacio en pantallas pequeñas para que el texto pueda envolver varias líneas.
    final maxChipWidth = (screenWidth - 64).clamp(220.0, screenWidth);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: scheme.onSurfaceVariant),
                softWrap: true,
                // Permitimos que se expanda verticalmente sin cortar contenido.
                maxLines: null,
                overflow: TextOverflow.visible,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionsMenu extends StatelessWidget {
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onHeader;
  final VoidCallback? onAddMaintenance;
  const _ActionsMenu({this.onEdit, this.onDelete, this.onHeader, this.onAddMaintenance});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Más acciones',
      onSelected: (value) async {
        switch (value) {
          case 'edit':
            onEdit?.call();
            break;
          case 'delete':
            onDelete?.call();
            break;
          case 'header':
            onHeader?.call();
            break;
          case 'maintenance':
            onAddMaintenance?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'header', child: ListTile(leading: Icon(Icons.badge), title: Text('Encabezado'))),
        const PopupMenuItem(value: 'maintenance', child: ListTile(leading: Icon(Icons.build_circle), title: Text('Registrar mantenimiento'))),
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'))),
        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Eliminar'))),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }
}