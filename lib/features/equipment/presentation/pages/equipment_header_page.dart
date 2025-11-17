import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/entities/maintenance.dart';
import '../providers/equipment_providers.dart';
import '../providers/maintenance_providers.dart';
import '../widgets/ui_components.dart';
import '../../constants/maintenance.dart';
import '../../constants/status.dart';

class EquipmentHeaderPage extends ConsumerWidget {
  final String equipmentId;
  const EquipmentHeaderPage({super.key, required this.equipmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(equipmentDetailProvider(equipmentId));
    final maintState = ref.watch(maintenancesByEquipmentProvider(equipmentId));

    return detail.when(
      loading: () => const Scaffold(
        appBar: _HeaderAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: const _HeaderAppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error cargando equipo: ${e.toString()}'),
        ),
      ),
      data: (eq) => Scaffold(
        appBar: const _HeaderAppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderContent(eq: eq),
              const SizedBox(height: 16),
              _MaintenanceSection(state: maintState),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _HeaderAppBar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Encabezado del Equipo'));
  }
}

class _HeaderContent extends StatelessWidget {
  final Equipment eq;
  const _HeaderContent({required this.eq});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eq.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoChip(label: 'Código/ID', value: eq.id),
                    if (eq.location != null && eq.location!.isNotEmpty)
                      InfoChip(label: 'Ubicación', value: eq.location!),
                    InfoChip(label: 'Estado', value: eq.status),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Identificación técnica',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Fabricante', value: eq.vendor ?? '-'),
                InfoRow(label: 'Modelo', value: eq.model ?? '-'),
                InfoRow(label: 'Número de serie', value: eq.serial ?? '-'),
                InfoRow(
                  label: 'Fecha de adquisición',
                  value: eq.purchaseDate != null
                      ? formatDate(eq.purchaseDate!)
                      : '-',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MaintenanceSection extends StatelessWidget {
  final AsyncValue<List<Maintenance>> state;
  const _MaintenanceSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Historial de mantenimiento',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            state.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, st) =>
                  Text('Error cargando mantenimientos: ${e.toString()}'),
              data: (items) {
                if (items.isEmpty) {
                  return const Text('Sin registros de mantenimiento.');
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 8),
                  itemBuilder: (context, index) {
                    final m = items[index];
                    final icon =
                        m.maintenanceType == MaintenanceTypes.correctivo
                        ? Icons.build
                        : Icons.handyman;
                    final dateStr = formatDate(m.maintenanceDate);
                    final nextStr = m.nextMaintenanceDate != null
                        ? formatDate(m.nextMaintenanceDate!)
                        : null;
                    return ListTile(
                      leading: Icon(icon),
                      title: Text('${m.maintenanceType} • $dateStr'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.description != null &&
                              m.description!.isNotEmpty)
                            Text(
                              m.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text('Responsable: ${m.responsible ?? '-'}'),
                          if (nextStr != null)
                            Text('Próximo mantenimiento: $nextStr'),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(EquipmentStatus.label(m.finalStatus)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 0.0,
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Sin helpers adicionales: se usa formatDate() de ui_components y EquipmentStatus.label()
}
