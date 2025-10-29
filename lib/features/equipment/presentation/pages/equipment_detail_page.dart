import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import '../../domain/entities/equipment.dart';
import '../providers/equipment_providers.dart';
import 'equipment_form_page.dart';

Future<String?> _fetchLatestImageUrl(String equipmentId) async {
  try {
    final client = Supabase.instance.client;
    final files = await client.storage.from('images').list(path: 'equipment/$equipmentId');
    if (files.isEmpty) return null;
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    files.sort((a, b) => parseDate(b.createdAt).compareTo(parseDate(a.createdAt)));
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

  String? _fmtDate(DateTime? d, {bool withTime = false}) {
    if (d == null) return null;
    final df = DateFormat(withTime ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy');
    return df.format(d);
  }

  String _fmtStatus(String s) {
    final t = s.replaceAll('_', ' ').toLowerCase();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }

  Color _statusColor(String s) {
    final t = s.toLowerCase();
    if (t.contains('operativo')) return Colors.green.shade100;
    if (t.contains('mantenimiento')) return Colors.amber.shade100;
    return Colors.red.shade100;
  }

  IconData _iconForKey(String key) {
    switch (key) {
      case 'Nombre':
        return Icons.label;
      case 'Marca':
        return Icons.factory;
      case 'Modelo':
        return Icons.memory;
      case 'Serie':
        return Icons.confirmation_number;
      case 'Ubicación':
        return Icons.place;
      case 'Estado':
        return Icons.info;
      case 'Proveedor':
        return Icons.store;
      case 'Fecha de compra':
        return Icons.shopping_cart;
      case 'Último mantenimiento':
        return Icons.build;
      case 'Próximo mantenimiento':
        return Icons.event_available;
      case 'Garantía vence':
        return Icons.verified_user;
      case 'Notas':
        return Icons.notes;
      case 'Creado':
        return Icons.schedule;
      case 'Actualizado':
        return Icons.update;
      case 'Creado por':
        return Icons.person_outline;
      default:
        return Icons.info_outline;
    }
  }

  Future<void> _downloadQr(BuildContext context) async {
    try {
      final painter = QrPainter(
        data: 'equipment:${eq.id}',
        version: QrVersions.auto,
        gapless: true,
        eyeStyle: const QrEyeStyle(color: Color(0xFF000000)),
        dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF000000)),
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
      MapEntry('Estado', _fmtStatus(eq.status)),
      MapEntry('Proveedor', eq.vendor),
      MapEntry('Fecha de compra', _fmtDate(eq.purchaseDate)),
      MapEntry('Último mantenimiento', _fmtDate(eq.lastMaintenanceDate)),
      MapEntry('Próximo mantenimiento', _fmtDate(eq.nextMaintenanceDate)),
      MapEntry('Garantía vence', _fmtDate(eq.warrantyExpireDate)),
      MapEntry('Notas', eq.notes),
      MapEntry('Creado', _fmtDate(eq.createdAt, withTime: true)),
      MapEntry('Actualizado', _fmtDate(eq.updatedAt, withTime: true)),
      MapEntry('Creado por', eq.createdBy),
    ];

    final visibleItems = items.where((it) => it.value != null && it.value!.isNotEmpty).toList();

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eq.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Chip(
                  label: Text(_fmtStatus(eq.status)),
                  backgroundColor: _statusColor(eq.status),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 600;

                Widget imageSection = FutureBuilder<String?>(
                  future: _fetchLatestImageUrl(eq.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: const SizedBox(
                          height: 180,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    final url = snapshot.data;
                    if (url == null || url.isEmpty) {
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Container(
                          height: 200,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.all(16),
                          child: const Text('Sin imagen disponible'),
                        ),
                      );
                    }
                    return Card(
                      elevation: 3,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Image.network(
                        url,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          alignment: Alignment.center,
                          color: Colors.grey.shade200,
                          child: const Text('No se pudo cargar la imagen'),
                        ),
                      ),
                    );
                  },
                );

                Widget qrSection = Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                );

                if (horizontal) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: imageSection),
                      const SizedBox(width: 12),
                      Expanded(child: qrSection),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      imageSection,
                      const SizedBox(height: 12),
                      qrSection,
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            ...[
              for (final it in visibleItems) ...[
                ListTile(
                  leading: Icon(_iconForKey(it.key), color: Colors.grey.shade700),
                  title: Text(
                    it.key,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(it.value!),
                ),
                const Divider(height: 1),
              ]
            ],
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
      ),
    );
  }
}