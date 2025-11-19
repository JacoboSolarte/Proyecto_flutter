import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../pages/analysis_result_page.dart';
import '../utils/notes_utils.dart';
import '../providers/image_analysis_providers.dart';
import '../providers/equipment_providers.dart';
import '../../domain/entities/image_analysis.dart';

class ImageAnalyzerSheet extends StatefulWidget {
  const ImageAnalyzerSheet({super.key});

  @override
  State<ImageAnalyzerSheet> createState() => _ImageAnalyzerSheetState();
}

class _ImageAnalyzerSheetState extends State<ImageAnalyzerSheet> {
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMimeType;
  bool _isAnalyzing = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.auto_awesome),
              title: Text('Analizador de imágenes'),
              subtitle: Text('Toma una foto o súbela y analiza con IA'),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Seleccionar imagen'),
                  onPressed: _pickFromFiles,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Tomar foto'),
                  onPressed: kIsWeb ? null : _pickFromCamera,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.smart_toy_outlined),
                  label: Text(_isAnalyzing ? 'Analizando…' : 'Analizar con IA'),
                  onPressed: (_isAnalyzing || _imageBytes == null)
                      ? null
                      : _analyzeImageWithAI,
                ),
              ],
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  _imageBytes!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) {
                    return Container(
                      height: 160,
                      width: double.infinity,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Text(
                        'Vista previa no soportada en web. Se analizará igualmente.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _imageName ?? 'imagen',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _imageBytes = null;
                      _imageName = null;
                      _imageMimeType = null;
                    }),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final name = xfile.name;
      final mime = lookupMimeType(name, headerBytes: bytes) ?? 'image/jpeg';
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = name;
        _imageMimeType = mime;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al tomar foto: $e')));
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
        allowMultiple: false,
      );
      final file = (res != null && res.files.isNotEmpty)
          ? res.files.first
          : null;
      final bytes = file?.bytes;
      if (bytes == null || file == null) {
        return;
      }
      final name = file.name;
      var mime =
          lookupMimeType(name, headerBytes: bytes) ??
          'application/octet-stream';
      if (mime == 'application/octet-stream') {
        final header = bytes.take(12).toList();
        final asHex = header
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        if (asHex.startsWith('89504e47')) {
          mime = 'image/png';
        } else if (asHex.startsWith('ffd8ff')) {
          mime = 'image/jpeg';
        } else if (asHex.startsWith('52494646') && asHex.contains('57454250')) {
          mime = 'image/webp';
        } else if (asHex.startsWith('424d')) {
          mime = 'image/bmp';
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageName = name;
        _imageMimeType = mime;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  Future<void> _analyzeImageWithAI() async {
    setState(() => _isAnalyzing = true);
    Map<String, dynamic> body;
    if (_imageBytes != null) {
      final base64Data = base64Encode(_imageBytes!);
      body = {
        'mode': 'base64',
        'image_base64': base64Data,
        'mime_type': _imageMimeType ?? 'image/jpeg',
      };
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona o toma una imagen para analizar'),
        ),
      );
      setState(() => _isAnalyzing = false);
      return;
    }

    try {
      // Leer configuración pública de IA desde Supabase (sin secretos)
      Map<String, dynamic>? aiCfg;
      try {
        final container = ProviderScope.containerOf(context, listen: false);
        final supabase = container.read(supabaseClientProvider);
        // Intento 1: función con esquema 'config'
        try {
          final cfg = await supabase.rpc(
            'config.get_public_ai_settings',
            params: {'env_name': 'production'},
          );
          if (cfg is List && cfg.isNotEmpty && cfg.first is Map) {
            aiCfg = Map<String, dynamic>.from(cfg.first as Map);
          } else if (cfg is Map) {
            aiCfg = Map<String, dynamic>.from(cfg as Map);
          }
        } catch (_) {
          // Intento 2: función en esquema 'public'
          try {
            final cfg2 = await supabase.rpc(
              'get_public_ai_settings',
              params: {'env_name': 'production'},
            );
            if (cfg2 is List && cfg2.isNotEmpty && cfg2.first is Map) {
              aiCfg = Map<String, dynamic>.from(cfg2.first as Map);
            } else if (cfg2 is Map) {
              aiCfg = Map<String, dynamic>.from(cfg2 as Map);
            }
          } catch (_) {}
        }
      } catch (_) {
        // Si falla la lectura, continuamos con valores por defecto
      }

      // Si no hay cfg pero tienes API key, permitimos análisis en cliente
      final enabled = aiCfg == null ? true : aiCfg['enabled'] == true;
      final modelOverride = aiCfg?['model']?.toString();
      final apiKey =
          dotenv.maybeGet('GOOGLE_API_KEY') ??
          const String.fromEnvironment('GEMINI_API_KEY');

      // Procede si hay API key en el cliente; el RPC ajusta modelo y overrides.
      if (apiKey.isNotEmpty) {
        // Hoist navigator & messenger to avoid use of BuildContext across async gaps
        final navigator = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);
        // Overrides opcionales desde configuración pública
        final systemPrompt = aiCfg?['system_prompt']?.toString();
        final baseUrlOverride = aiCfg?['base_url']?.toString();
        final temperatureOverride = () {
          final t = aiCfg?['temperature'];
          if (t == null) return null;
          if (t is num) return t.toDouble();
          return double.tryParse(t.toString());
        }();
        final maxTokensOverride = () {
          final m = aiCfg?['max_output_tokens'];
          if (m == null) return null;
          if (m is int) return m;
          return int.tryParse(m.toString());
        }();

        final fb = await _callGeminiDirectFallback(
          body,
          apiKey,
          modelOverride: modelOverride,
          systemPrompt: systemPrompt,
          baseUrlOverride: baseUrlOverride,
          temperatureOverride: temperatureOverride,
          maxTokensOverride: maxTokensOverride,
        );
        final result = Map<String, dynamic>.from(fb['result'] as Map);
        final modelUsed = fb['model_used']?.toString();
        final rawText = fb['raw_text']?.toString();
        final notes = stripOptionsFromNotes(
          (result['notes']?.toString() ??
                  result['description']?.toString() ??
                  '')
              .trim(),
        );

        if (!mounted) {
          return;
        }
        // Persistir el análisis en la BD (si hay usuario autenticado)
        try {
          final container = ProviderScope.containerOf(context, listen: false);
          final supabase = container.read(supabaseClientProvider);
          final userId = supabase.auth.currentUser?.id;
          if (userId != null && userId.isNotEmpty) {
            // Subir la imagen al storage para poder mostrarla en el historial
            String? publicUrl;
            try {
              if (_imageBytes != null) {
                final safeName =
                    _imageName ??
                    'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final path =
                    'analyses/$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
                await supabase.storage
                    .from('images')
                    .uploadBinary(
                      path,
                      _imageBytes!,
                      fileOptions: FileOptions(
                        contentType:
                            _imageMimeType ?? 'application/octet-stream',
                        upsert: true,
                      ),
                    );
                publicUrl = supabase.storage.from('images').getPublicUrl(path);
              }
            } catch (_) {
              // Si falla la subida, continuamos guardando el análisis sin imagen
            }
            final createUC = container.read(createImageAnalysisUseCaseProvider);
            try {
              await createUC(
                ImageAnalysis(
                  id: '',
                  userId: userId,
                  imageName: _imageName,
                  mimeType: _imageMimeType,
                  imageUrl: publicUrl,
                  model: modelUsed,
                  notes: notes,
                  rawText: rawText,
                ),
                userId: userId,
              );
            } on PostgrestException catch (pg) {
              // Si el esquema de PostgREST aún no detecta 'image_url' (PGRST204),
              // intentamos guardar sin la URL para no bloquear la UX.
              final msg = pg.message.toLowerCase();
              if (pg.code == 'PGRST204' && msg.contains("image_url")) {
                await createUC(
                  ImageAnalysis(
                    id: '',
                    userId: userId,
                    imageName: _imageName,
                    mimeType: _imageMimeType,
                    imageUrl: null,
                    model: modelUsed,
                    notes: notes,
                    rawText: rawText,
                  ),
                  userId: userId,
                );
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Guardado sin imagen: refresca la caché de esquema en Supabase para habilitar image_url.',
                    ),
                  ),
                );
              } else {
                rethrow;
              }
            }
          }
        } catch (saveErr) {
          // No bloquear la navegación; mostrar aviso si falla el guardado
          // ignore: use_build_context_synchronously
          messenger.showSnackBar(
            SnackBar(content: Text('No se pudo guardar el análisis: $saveErr')),
          );
        }
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => AnalysisResultPage(
              source: 'IA',
              model: modelUsed,
              fields: {
                'name': result['name']?.toString() ?? 'Desconocido',
                'brand': result['brand']?.toString() ?? 'Desconocido',
                'model': result['model']?.toString() ?? 'Desconocido',
                'serial': result['serial']?.toString() ?? 'Desconocido',
                'location': 'Desconocido',
                'vendor': 'Desconocido',
                'notes': notes,
                'options_brand': result['brand']?.toString() ?? 'Desconocido',
                'options_model': result['model']?.toString() ?? 'Desconocido',
                'options_serial': result['serial']?.toString() ?? 'Desconocido',
              },
              rawText: rawText,
            ),
          ),
        );
        return;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'IA no disponible: verifica configuración en servidor.',
            ),
          ),
        );
        setState(() => _isAnalyzing = false);
        return;
      }
    } catch (e1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al analizar imagen con IA directa: $e1')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  Future<Map<String, dynamic>> _callGeminiDirectFallback(
    Map<String, dynamic> body,
    String apiKey, {
    String? modelOverride,
    String? systemPrompt,
    String? baseUrlOverride,
    double? temperatureOverride,
    int? maxTokensOverride,
  }) async {
    final prompt = (systemPrompt != null && systemPrompt.trim().isNotEmpty)
        ? systemPrompt.trim()
        : 'Eres un asistente técnico biomédico. Observa la imagen y determina el tipo genérico del equipo (no la marca ni el modelo). '
              'Escribe únicamente UN PÁRRAFO en español (120–180 palabras) que explique: 1) qué es y 2) para qué se usa. '
              'Apóyate explícitamente en lo que se ve: menciona al menos 3 rasgos visibles (por ejemplo, pantalla/controles, puertos/conectores, sondas/accesorios, textos legibles, formas o materiales) '
              'y cómo esos rasgos justifican la identificación y el uso. Describe brevemente cómo se opera en uso típico y el contexto clínico. '
              'Evita respuestas genéricas; personaliza la explicación a la imagen. NO incluyas marcas, modelos ni números de serie. '
              'Si la imagen NO muestra un equipo biomédico, responde exactamente: "No le puedo responder a eso".';

    final configuredModel = (modelOverride ?? '').trim();
    final models = (configuredModel.isNotEmpty)
        ? [configuredModel]
        : [
            'gemini-2.0-flash',
            'gemini-2.0-pro',
            'gemini-2.5-pro',
            'gemini-2.5-flash',
            'gemini-1.5-pro',
            'gemini-1.5-flash',
            'gemini-1.5-flash-8b',
            'gemini-pro-vision',
          ];

    String? base64;
    String mime = body['mime_type']?.toString() ?? 'image/jpeg';
    if (body['mode'] == 'base64') {
      base64 = body['image_base64']?.toString();
    }
    if (base64 == null || base64.isEmpty) {
      throw Exception('Imagen no disponible para IA');
    }

    final parts = [
      {'text': prompt},
      {
        'inline_data': {'mime_type': mime, 'data': base64},
      },
    ];
    final payload = {
      'contents': [
        {'role': 'user', 'parts': parts},
      ],
      'generationConfig': {
        'temperature': temperatureOverride ?? 0.3,
        'responseMimeType': 'text/plain',
        'maxOutputTokens': maxTokensOverride ?? 512,
      },
    };

    for (final model in models) {
      final baseUrl =
          (baseUrlOverride != null && baseUrlOverride.trim().isNotEmpty)
          ? baseUrlOverride.trim()
          : 'https://generativelanguage.googleapis.com';
      final apiBase = baseUrl.endsWith('/v1beta') ? baseUrl : '$baseUrl/v1beta';
      final url = Uri.parse(
        '$apiBase/models/$model:generateContent?key=$apiKey',
      );
      final resp = await http.post(
        url,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(payload),
      );
      Map<String, dynamic> data;
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        String? extractText(Map<String, dynamic> d) {
          final candidates = d['candidates'];
          if (candidates is List && candidates.isNotEmpty) {
            final c0 = candidates.first;
            if (c0 is Map) {
              final content = c0['content'];
              if (content is Map) {
                final parts = content['parts'];
                if (parts is List && parts.isNotEmpty) {
                  final p0 = parts.first;
                  if (p0 is Map) {
                    final t = p0['text'];
                    if (t is String) return t;
                    final j = p0['json'];
                    if (j is Map) {
                      try {
                        return jsonEncode(j);
                      } catch (_) {}
                    }
                  }
                }
              }
              final outText = c0['output_text'];
              if (outText is String) return outText;
            }
          }
          return null;
        }

        final raw = extractText(data);
        if (raw == null || raw.toString().trim().isEmpty) continue;
        final clean = raw
            .toString()
            .trim()
            .replaceAll(RegExp(r'^```json\s*'), '')
            .replaceAll(RegExp(r'^```\s*'), '')
            .replaceAll(RegExp(r'```$'), '');
        final onlyParagraph = stripOptionsFromNotes(clean);
        return {
          'result': {'notes': onlyParagraph},
          'model_used': model,
          'raw_text': raw,
        };
      }
    }
    throw Exception('No se pudo obtener respuesta de IA');
  }
}

void showImageAnalyzerSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: const ImageAnalyzerSheet(),
      );
    },
  );
}
