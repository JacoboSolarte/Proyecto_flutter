import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/image_analysis.dart';
import '../providers/image_analysis_providers.dart';
import '../providers/equipment_providers.dart';

class AnalysisHistoryPage extends ConsumerWidget {
  const AnalysisHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = ref.watch(supabaseClientProvider);
    final userId = client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de análisis')),
      backgroundColor: const Color(0xFFCDE8FF),
      body: SafeArea(
        child: userId == null
            ? const Center(
                child: Text('Debes iniciar sesión para ver el historial.'),
              )
            : Consumer(
                builder: (context, ref, _) {
                  final analysesAsync = ref.watch(
                    imageAnalysesByUserProvider(userId),
                  );
                  return analysesAsync.when(
                    data: (items) => _HistoryList(items: items),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, st) =>
                        Center(child: Text('Error al cargar historial: $err')),
                  );
                },
              ),
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<ImageAnalysis> items;
  const _HistoryList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Aún no hay análisis guardados.'));
    }
    final df = DateFormat('dd/MM/yyyy HH:mm');
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final a = items[index];
        final created = a.createdAt != null
            ? df.format(a.createdAt!)
            : 'Fecha desconocida';
        Widget leading;
        if (a.imageUrl != null && a.imageUrl!.isNotEmpty) {
          leading = ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              a.imageUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.image_not_supported),
            ),
          );
        } else {
          // Fallback: intenta resolver la URL pública desde Storage
          leading = FutureBuilder<String?>(
            future: _resolveFallbackImageUrl(a),
            builder: (context, snap) {
              final url = snap.data;
              if (url == null || url.isEmpty) {
                return const Icon(Icons.history);
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  url,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image_not_supported),
                ),
              );
            },
          );
        }

        return Card(
          elevation: 6,
          shadowColor: Colors.red.withOpacity(0.45),
          color: const Color(0xFFFFEBEE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: leading,
            title: Text(a.imageName ?? 'Imagen analizada'),
            subtitle: Text('${a.model ?? 'Modelo desconocido'} • $created'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    a.notes?.isNotEmpty == true
                        ? a.notes!
                        : 'Sin notas disponibles',
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

Future<String?> _resolveFallbackImageUrl(ImageAnalysis a) async {
  try {
    final client = Supabase.instance.client;
    final userId = a.userId;
    if (userId == null || userId.isEmpty) return null;
    final files = await client.storage
        .from('images')
        .list(path: 'analyses/$userId');
    if (files.isEmpty) return null;
    // Si conocemos el nombre original, intentamos buscar por sufijo
    if (a.imageName != null && a.imageName!.isNotEmpty) {
      final match = files.firstWhere(
        (f) => f.name.toLowerCase().endsWith(a.imageName!.toLowerCase()),
        orElse: () => files.first,
      );
      final path = 'analyses/$userId/${match.name}';
      return client.storage.from('images').getPublicUrl(path);
    }
    // De lo contrario, devolvemos el más reciente
    DateTime parse(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    files.sort((a, b) => parse(b.createdAt).compareTo(parse(a.createdAt)));
    final latest = files.first;
    final path = 'analyses/$userId/${latest.name}';
    return client.storage.from('images').getPublicUrl(path);
  } catch (_) {
    return null;
  }
}