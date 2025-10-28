import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../../domain/entities/equipment.dart';
import '../providers/equipment_providers.dart';
import 'equipment_form_page.dart';

Future<String?> _fetchLatestImageUrl(String equipmentId) async {
  try {
    final client = Supabase.instance.client;
    final files = await client.storage.from('images').list(path: 'equipment/$equipmentId');
    if (files.isEmpty) return null;
    DateTime _parse(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    files.sort((a, b) => _parse(b.createdAt).compareTo(_parse(a.createdAt)));
    final latest = files.first;
    final path = 'equipment/$equipmentId/${latest.name}';
    final url = client.storage.from('images').getPublicUrl(path);
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

  Future<void> _downloadQr(BuildContext context) async {
    try {
      final painter = QrPainter(
        data: 'equipment:${eq.id}',
        version: QrVersions.auto,
        gapless: true,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );
      final byteData = await painter.toImageData(1024, format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null) {
        throw Exception('No se pudo generar la imagen del QR');
      }
      final sanitizedName = eq.name
          .trim()
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '-')
          .replaceAll(RegExp(r'\s+'), '_');
      await FileSaver.instance.saveFile(
        name: 'equipment_${sanitizedName}_${eq.id}',
        bytes: bytes,
        ext: 'png',
        mimeType: MimeType.png,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR descargado correctamente')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al descargar QR: $e')),
        );
      }
    }
  }

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
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Código QR', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Center(
                    child: QrImageView(
                      data: 'equipment:${eq.id}',
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
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
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Descargar QR'),
                onPressed: () => _downloadQr(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}