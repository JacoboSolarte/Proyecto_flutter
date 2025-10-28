import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/equipment.dart';
import '../providers/equipment_providers.dart';
import 'equipment_form_page.dart';

Future<String?> _fetchLatestImageUrl(String equipmentId) async {
  try {
    final client = Supabase.instance.client;
    final files = await client.storage.from('task-images').list(path: 'equipment/$equipmentId');
    if (files.isEmpty) return null;
    DateTime _parse(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    files.sort((a, b) => _parse(b.createdAt).compareTo(_parse(a.createdAt)));
    final latest = files.first;
    final path = 'equipment/$equipmentId/${latest.name}';
    final url = client.storage.from('task-images').getPublicUrl(path);
    return url;
  } catch (_) {
    return null;
  }
}

class EquipmentDetailPage extends ConsumerWidget {
  final String id;
  const EquipmentDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(equipmentDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de equipo')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (eq) => _DetailContent(eq: eq),
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final Equipment eq;
  const _DetailContent({required this.eq});

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<String, String?>>[
      MapEntry('Nombre', eq.name),
      MapEntry('Marca', eq.brand),
      MapEntry('Modelo', eq.model),
      MapEntry('Serie', eq.serial),
      MapEntry('Ubicación', eq.location),
      MapEntry('Estado', eq.status),
      MapEntry('Proveedor', eq.vendor),
      MapEntry('Notas', eq.notes),
      MapEntry('Creado', eq.createdAt?.toIso8601String()),
      MapEntry('Actualizado', eq.updatedAt?.toIso8601String()),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(eq.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<String?>(
            future: _fetchLatestImageUrl(eq.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
              }
              final url = snapshot.data;
              if (url == null || url.isEmpty) return const SizedBox.shrink();
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final it = items[i];
                if (it.value == null || it.value!.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ListTile(
                  title: Text(it.key),
                  subtitle: Text(it.value!),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Editar'),
                onPressed: () async {
                  final updated = await Navigator.of(context).push<Equipment?>(
                    MaterialPageRoute(builder: (_) => EquipmentFormPage(existing: eq)),
                  );
                  if (updated != null && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}