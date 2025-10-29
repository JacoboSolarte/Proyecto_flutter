import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// 'Uint8List' está disponible vía foundation en versiones recientes; evitamos import redundante
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'analysis_result_page.dart';
import '../../domain/entities/equipment.dart';
import '../providers/equipment_providers.dart';

class EquipmentFormPage extends ConsumerStatefulWidget {
  final Equipment? existing;
  const EquipmentFormPage({super.key, this.existing});

  @override
  ConsumerState<EquipmentFormPage> createState() => _EquipmentFormPageState();
}

class _EquipmentFormPageState extends ConsumerState<EquipmentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _serialCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _status = 'operativo';
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMimeType;
  String? _existingImageUrl;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _brandCtrl.text = e.brand ?? '';
      _modelCtrl.text = e.model ?? '';
      _serialCtrl.text = e.serial ?? '';
      _locationCtrl.text = e.location ?? '';
      _vendorCtrl.text = e.vendor ?? '';
      _notesCtrl.text = e.notes ?? '';
      _status = e.status;
      _loadExistingImageUrl();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _serialCtrl.dispose();
    _locationCtrl.dispose();
    _vendorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar equipo' : 'Agregar equipo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nombre*'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Nombre obligatorio';
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _brandCtrl,
                  decoration: const InputDecoration(labelText: 'Marca'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _modelCtrl,
                  decoration: const InputDecoration(labelText: 'Modelo'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _serialCtrl,
                  decoration: const InputDecoration(labelText: 'Serie'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(labelText: 'Ubicación'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  items: const [
                    DropdownMenuItem(value: 'operativo', child: Text('Operativo')),
                    DropdownMenuItem(value: 'mantenimiento', child: Text('Mantenimiento')),
                    DropdownMenuItem(value: 'requiere_seguimiento', child: Text('Requiere seguimiento')),
                    DropdownMenuItem(value: 'fuera_de_servicio', child: Text('Fuera de servicio')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'operativo'),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _vendorCtrl,
                  decoration: const InputDecoration(labelText: 'Proveedor'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Imagen (opcional)', style: Theme.of(context).textTheme.titleMedium),
                ),
                const SizedBox(height: 8),
                if (isEdit && _existingImageUrl != null) ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Imagen actual', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Image.network(
                        _existingImageUrl!,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Seleccionar imagen'),
                      onPressed: _pickFromFiles,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Tomar foto'),
                      onPressed: kIsWeb ? null : _pickFromCamera,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(_isAnalyzing ? 'Analizando…' : 'Analizar con IA'),
                      onPressed: (_isAnalyzing || (_imageBytes == null && _existingImageUrl == null))
                          ? null
                          : _analyzeImageWithAI,
                    ),
                  ],
                ),
                if (_imageBytes != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    child: Card(
                      elevation: 4,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(_imageName ?? 'imagen', overflow: TextOverflow.ellipsis)),
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    final equipment = Equipment(
                      id: widget.existing?.id ?? 'temp',
                      name: _nameCtrl.text.trim(),
                      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
                      model: _modelCtrl.text.trim().isEmpty ? null : _modelCtrl.text.trim(),
                      serial: _serialCtrl.text.trim().isEmpty ? null : _serialCtrl.text.trim(),
                      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
                      status: _status,
                      vendor: _vendorCtrl.text.trim().isEmpty ? null : _vendorCtrl.text.trim(),
                      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                    );
                    if (widget.existing == null) {
                      final useCase = ref.read(createEquipmentUseCaseProvider);
                      final userId = Supabase.instance.client.auth.currentUser?.id;
                      if (userId == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión no válida')));
                        return;
                      }
                      final created = await useCase(
                        equipment,
                        userId: userId,
                      );
                      if (_imageBytes != null) {
                        await _uploadImage(equipmentId: created.id);
                      }
                      if (mounted) Navigator.pop(context, created);
                    } else {
                      final useCase = ref.read(updateEquipmentUseCaseProvider);
                      final updated = await useCase(widget.existing!.id, equipment);
                      if (_imageBytes != null) {
                        await _uploadImage(equipmentId: widget.existing!.id);
                      }
                      if (mounted) Navigator.pop(context, updated);
                    }
                  },
                  child: Text(isEdit ? 'Guardar cambios' : 'Crear equipo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    } else if (_existingImageUrl != null) {
      body = {
        'mode': 'url',
        'image_url': _existingImageUrl,
      };
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona o toma una imagen para analizar')));
      if (mounted) setState(() => _isAnalyzing = false);
      return;
    }

    try {
      // 1) Si hay API key, preferir Gemini directo (evita error visible por función caída)
      final apiKey = dotenv.maybeGet('GOOGLE_API_KEY') ?? const String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isNotEmpty) {
        final fb = await _callGeminiDirectFallback(body, apiKey);
        final result = Map<String, dynamic>.from(fb['result'] as Map);
        final modelUsed = fb['model_used']?.toString();
        final rawText = fb['raw_text']?.toString();

        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AnalysisResultPage(
            source: 'IA',
              model: modelUsed,
              fields: {
                'name': result['name']?.toString() ?? '',
                'brand': result['brand']?.toString() ?? '',
                'model': result['model']?.toString() ?? '',
                'serial': result['serial']?.toString() ?? '',
                'location': ((result['location']?.toString() ?? '').trim().isNotEmpty
                    ? result['location']!.toString().trim()
                    : 'Desconocido'),
                'vendor': ((result['vendor']?.toString() ?? '').trim().isNotEmpty
                    ? result['vendor']!.toString().trim()
                    : 'Desconocido'),
                'notes': result['notes']?.toString() ?? '',
                'options_brand': result['options_brand']?.toString() ?? (result['brand']?.toString() ?? 'Desconocido'),
                'options_model': result['options_model']?.toString() ?? (result['model']?.toString() ?? 'Desconocido'),
                'options_serial': result['options_serial']?.toString() ?? (result['serial']?.toString() ?? 'Desconocido'),
              },
              rawText: rawText,
            ),
          ),
        );
        return; // mostramos resultados y no intentamos la función
      }

      // 2) Sin API key en cliente: no usar Supabase; informar configuración
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configura GOOGLE_API_KEY para usar análisis 100% IA.')),
      );
      setState(() => _isAnalyzing = false);
      return;
    } catch (e1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al analizar imagen con IA directa: $e1')),
      );
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  // Fallback directo al API REST de IA (modelo configurable)
  Future<Map<String, dynamic>> _callGeminiDirectFallback(Map<String, dynamic> body, String apiKey) async {
    String mime = body['mime_type']?.toString() ?? 'image/jpeg';
    String? base64Image;

    final mode = body['mode']?.toString();
    if (mode == 'base64') {
      base64Image = body['image_base64']?.toString();
      if (base64Image == null || base64Image.isEmpty) {
        throw Exception('Imagen base64 vacía');
      }
    } else if (mode == 'url') {
      final imageUrl = body['image_url']?.toString();
      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('URL de imagen inválida');
      }
      final r = await http.get(Uri.parse(imageUrl));
      if (r.statusCode < 200 || r.statusCode >= 300) {
        throw Exception('No se pudo descargar la imagen (${r.statusCode})');
      }
      mime = r.headers['content-type'] ?? mime;
      base64Image = base64Encode(r.bodyBytes);
    } else {
      throw Exception('Modo de imagen no soportado');
    }

    const prompt =
        'Eres un asistente técnico biomédico. Observa la imagen y determina el tipo genérico del equipo (no la marca ni el modelo). '
        'Escribe únicamente UN PÁRRAFO en español (120–180 palabras) que explique: 1) qué es y 2) para qué se usa. '
        'Apóyate explícitamente en lo que se ve: menciona al menos 3 rasgos visibles (por ejemplo, pantalla/controles, puertos/conectores, sondas/accesorios, textos legibles, formas o materiales) '
        'y cómo esos rasgos justifican la identificación y el uso. Describe brevemente cómo se opera en uso típico y el contexto clínico. '
        'Evita respuestas genéricas; personaliza la explicación a la imagen. NO incluyas marcas, modelos ni números de serie. '
        'Si la imagen NO muestra un equipo biomédico, responde exactamente: "No le puedo responder a eso".';

    final payload = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mime,
                'data': base64Image,
              }
            }
          ],
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'responseMimeType': 'text/plain',
        'maxOutputTokens': 512,
      }
    };

    final configuredModel =
        dotenv.maybeGet('GEMINI_MODEL') ?? const String.fromEnvironment('GEMINI_MODEL');
    final models = (configuredModel != null && configuredModel.trim().isNotEmpty)
        ? [configuredModel.trim()]
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

    Object? lastError;
    for (final m in models) {
      final uri = Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/' + m + ':generateContent?key=' + apiKey);
      try {
        final resp = await http.post(
          uri,
          headers: {'content-type': 'application/json'},
          body: jsonEncode(payload),
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final data = jsonDecode(resp.body);
          final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
              data['candidates']?[0]?['output_text'];

          if (text is String && text.trim().isNotEmpty) {
            final cleaned = text
                .toString()
                .trim()
                .replaceAll(RegExp(r'^```json\s*'), '')
                .replaceAll(RegExp(r'^```\s*'), '')
                .replaceAll(RegExp(r'```$'), '');
            return {'result': {'notes': _stripOptionsFromNotes(cleaned)}, 'model_used': m, 'raw_text': text};
          }

          lastError = 'Salida vacía';
        } else {
          lastError = 'HTTP ${resp.statusCode}: ${resp.body}';
        }
      } catch (err) {
        lastError = err;
      }
    }

    throw Exception('Análisis IA falló: $lastError');
  }

  String _extractJsonString(String s) {
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return s.substring(start, end + 1);
    }
    return s.trim();
  }

  Map<String, String> _extractOptionsFromNotes(String notes) {
    final brandMatch = RegExp(r'Marca posibles:\s*([^;]+)', caseSensitive: false).firstMatch(notes);
    final modelMatch = RegExp(r'Modelo posibles:\s*([^;]+)', caseSensitive: false).firstMatch(notes);
    final serialMatch = RegExp(r'Serie posible:\s*([^.;]+)', caseSensitive: false).firstMatch(notes);
    return {
      'brand': brandMatch?.group(1)?.trim() ?? '',
      'model': modelMatch?.group(1)?.trim() ?? '',
      'serial': serialMatch?.group(1)?.trim() ?? '',
    };
  }
  
  String _stripOptionsFromNotes(String notes) {
    var s = notes;
    s = s.replaceAll(RegExp(r'(Marca|Marcas) posibles?:\s*[^;\n]+(;)?', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'Modelo(s)? posibles?:\s*[^;\n]+(;)?', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'(Serie|Serial)(s)? posible(s)?:\s*[^.;\n]+(;|\.)?', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return s;
  }

  Map<String, String> _normalizeFieldsFromMap(Map<String, dynamic> src) {
    final kv = <String, String>{};
    String? getKey(List<String> names) {
      for (final k in src.keys) {
        final lk = k.toString().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        for (final n in names) {
          final ln = n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (lk == ln) return k;
        }
      }
      return null;
    }

    String pick(List<String> names) {
      final k = getKey(names);
      final v = (k != null ? src[k] : null)?.toString() ?? '';
      return v.trim();
    }

    final brand = pick(['brand', 'marca', 'manufacturer', 'fabricante', 'maker']);
    final model = pick(['model', 'modelo', 'modelnumber', 'model_no', 'mod', 'modelname']);
    var serial = pick(['serial', 'serialnumber', 'serie', 'sn', 's/n', 'no_serie']);
    var name = pick(['name', 'nombre', 'equipmentname', 'equipo', 'product', 'producto']);
    var notes = pick(['notes', 'descripcion', 'description', 'desc']);

    if (name.isEmpty) {
      name = [brand, model].where((e) => e.isNotEmpty).join(' ');
    }

    // No generar descripciones locales: mantener notas vacías si la IA no provee contenido

    String _safe(String s) => s.trim().isEmpty ? 'Desconocido' : s.trim();

    // Extraer opciones desde notes si vienen en el formato esperado
    final opts = _extractOptionsFromNotes(notes);
    final optionsBrand = opts['brand'] ?? '';
    final optionsModel = opts['model'] ?? '';
    final optionsSerial = opts['serial'] ?? '';

    return {
      'name': _safe(name),
      'brand': _safe(brand),
      'model': _safe(model),
      'serial': _safe(serial),
      'notes': _stripOptionsFromNotes(notes),
      'options_brand': optionsBrand.isNotEmpty ? optionsBrand : _safe(brand),
      'options_model': optionsModel.isNotEmpty ? optionsModel : _safe(model),
      'options_serial': optionsSerial.isNotEmpty ? optionsSerial : _safe(serial),
    };
  }

  Map<String, String> _normalizeFieldsFromText(String parsed) {
    // Eliminado: sin generación desde OCR ni heurísticas locales.
    return {
      'name': '',
      'brand': '',
      'model': '',
      'serial': '',
      'notes': '',
      'options_brand': 'Desconocido',
      'options_model': 'Desconocido',
      'options_serial': 'Desconocido',
    };
  }

  int _applyFieldsToForm(Map<String, String> fields, {bool overwriteName = false}) {
    int updated = 0;
    setState(() {
      final name = fields['name']?.trim() ?? '';
      final brand = fields['brand']?.trim() ?? '';
      final model = fields['model']?.trim() ?? '';
      final serial = fields['serial']?.trim() ?? '';
      final location = fields['location']?.trim() ?? '';
      final vendor = fields['vendor']?.trim() ?? '';
      final notes = fields['notes']?.trim() ?? '';

      if (name.isNotEmpty && (overwriteName || _nameCtrl.text.trim().isEmpty)) {
        _nameCtrl.text = name;
        updated++;
      }
      if (brand.isNotEmpty) {
        _brandCtrl.text = brand;
        updated++;
      }
      if (model.isNotEmpty) {
        _modelCtrl.text = model;
        updated++;
      }
      if (serial.isNotEmpty) {
        _serialCtrl.text = serial;
        updated++;
      }
      if (location.isNotEmpty) {
        _locationCtrl.text = location;
        updated++;
      }
      if (vendor.isNotEmpty) {
        _vendorCtrl.text = vendor;
        updated++;
      }
      if (notes.isNotEmpty) {
        _notesCtrl.text = notes;
        updated++;
      }
    });
    return updated;
  }

  // Fallback OCR básico sin clave (usa API demo de OCR.space y heurísticas)
  Future<Map<String, String>> _ocrHeuristicFallback(Map<String, dynamic> body) async {
    // OCR deshabilitado: forzar uso de IA.
    throw Exception('OCR deshabilitado. Configura GOOGLE_API_KEY para usar análisis 100% IA.');
    String? base64Image;
    String mimeForOcr = body['mime_type']?.toString() ?? 'image/jpeg';
    if (body['mode'] == 'base64') {
      base64Image = body['image_base64']?.toString();
    } else if (body['mode'] == 'url') {
      final imageUrl = body['image_url']?.toString();
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final r = await http.get(Uri.parse(imageUrl));
        if (r.statusCode >= 200 && r.statusCode < 300) {
          base64Image = base64Encode(r.bodyBytes);
          mimeForOcr = r.headers['content-type'] ?? mimeForOcr;
        }
      }
    }
    if (base64Image == null || base64Image.isEmpty) {
      throw Exception('Imagen no disponible para OCR');
    }

    final parsed = await _runOcrSpace(base64Image, mimeType: mimeForOcr, languages: const ['spa', 'eng']);
    if (parsed.isEmpty) {
      throw Exception('Sin texto OCR');
    }

    // Heurísticas simples para extraer campos
    final lower = parsed.toLowerCase();
    String? brand;
    String? model;
    String? serial;

    final serialRegexes = [
      RegExp(r'(s/?n|serial|serie|serial number)[:\s]*([a-z0-9\-_/]+)', caseSensitive: false),
      RegExp(r'(no\.? de serie)[:\s]*([a-z0-9\-_/]+)', caseSensitive: false),
    ];
    for (final re in serialRegexes) {
      final m = re.firstMatch(parsed);
      if (m != null && m.groupCount >= 2) {
        serial = m.group(2);
        break;
      }
    }

    final modelRegexes = [
      RegExp(r'(model|modelo|mod\.)[:\s]*([a-z0-9\-_/]+)', caseSensitive: false),
    ];
    for (final re in modelRegexes) {
      final m = re.firstMatch(parsed);
      if (m != null && m.groupCount >= 2) {
        model = m.group(2);
        break;
      }
    }

    // Marca: buscar en diccionario de marcas comunes
    final commonBrands = [
      'Philips','Siemens','GE','GE Healthcare','Mindray','Dräger','Draeger','Nihon','Nihon Kohden',
      'Medtronic','Welch Allyn','Contec','Omron','Abbott','Baxter','Fresenius','Hillrom','Maquet',
      'Zeiss','Stryker','Terumo','B. Braun','Braun','Schiller','Hewlett Packard','HP'
    ];
    for (final b in commonBrands) {
      if (parsed.contains(RegExp('\\b' + RegExp.escape(b) + '\\b', caseSensitive: false))) {
        brand = b;
        break;
      }
    }
    // Si no se detecta por diccionario, intenta con heurística de palabras capitalizadas
    if (brand == null || brand!.isEmpty) {
      final words = parsed.split(RegExp(r'\s+'));
      for (final w in words) {
        final clean = w.replaceAll(RegExp(r'[^A-Za-z]'), '');
        if (clean.length >= 3 && RegExp(r'^[A-Z][a-zA-Z]+$').hasMatch(clean)) {
          brand = clean;
          break;
        }
      }
    }

    // Modelo: también buscar patrones frecuentes letra+numero (p.e. MP20, PM-7000, C3, Dash3000)
    if (model == null || model!.isEmpty) {
      final m = RegExp(r'\b([A-Za-z]{1,4}[\- ]?[0-9]{1,4}[A-Za-z0-9]{0,4})\b')
          .allMatches(parsed)
          .map((e) => e.group(1))
          .whereType<String>()
          .toList();
      if (m.isNotEmpty) {
        // Elegir el token con más mezcla alfanumérica
        m.sort((a, b) => b.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length.compareTo(
            a.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length));
        model = m.first;
      }
    }

    String name = [brand, model].where((e) => e != null && e!.isNotEmpty).join(' ');
    if (name.isEmpty) {
      final guess = _guessDeviceType(parsed);
      if (guess.isNotEmpty) name = guess + (brand != null && brand!.isNotEmpty ? ' $brand' : '');
    }

    // Notas: construir un párrafo más específico usando rasgos visibles del texto OCR
    final type = _guessDeviceType(parsed);
    final features = _visibleFeaturesFromText(parsed, type);
    final desc = _paragraphFromOcr(type, features);

    final modelTokens = RegExp(r'\b([A-Za-z]{1,4}[\- ]?[0-9]{1,4}[A-Za-z0-9]{0,4})\b')
        .allMatches(parsed)
        .map((e) => e.group(1))
        .whereType<String>()
        .toSet()
        .toList();
    final serialCandidates = serial != null && serial!.isNotEmpty
        ? [serial!]
        : RegExp(r'(s/?n|serial|serie|serial number|n\.? de serie)[:\s]*([a-z0-9\-_/]+)', caseSensitive: false)
            .allMatches(parsed)
            .map((m) => m.group(2))
            .whereType<String>()
            .toSet()
            .toList();

    String safe(String? v) => (v == null || v.trim().isEmpty) ? 'Desconocido' : v.trim();
    final opciones = 'Marca posibles: ' +
        (brand != null && brand!.isNotEmpty ? brand! + (commonBrands.isNotEmpty ? ' / ' : '') : '') +
        ('Desconocido') +
        '; Modelo posibles: ' +
        (model != null && model!.isNotEmpty ? model! + (modelTokens.isNotEmpty ? ' / ' : '') : '') +
        (modelTokens.take(3).join(' / ').isNotEmpty ? modelTokens.take(3).join(' / ') : 'Desconocido') +
        '; Serie posible: ' +
        (serialCandidates.isNotEmpty ? serialCandidates.first : 'Desconocido') + '.';
    final notes = desc;
    return {
      'name': safe(name),
      'brand': safe(brand),
      'model': safe(model),
      'serial': safe(serial),
      'notes': notes,
      'options_brand': (brand != null && brand!.isNotEmpty) ? brand! : 'Desconocido',
      'options_model': (modelTokens.take(3).join(' / ').isNotEmpty ? modelTokens.take(3).join(' / ') : (model ?? 'Desconocido')),
      'options_serial': (serialCandidates.isNotEmpty ? serialCandidates.first : 'Desconocido'),
    };
  }

  // Intenta inferir el tipo de equipo a partir de palabras clave del texto OCR
  String _guessDeviceType(String parsed) {
    final t = parsed.toLowerCase();
    bool containsAny(List<String> kws) => kws.any((k) => t.contains(k));

    if (containsAny([
      'monitor', 'multiparametro', 'multiparámetro', 'oximeter', 'oxímetro', 'saturación', 'spo2', 'sp02', 'nibp',
      'ibp', 'etco2', 'capnografia', 'capnografía', 'resp', 'rr', 'hr', 'fc', 'pulse', 'bp', 'temp', 'temperatura'
    ])) {
      return 'Monitor de paciente';
    }
    if (containsAny([
      'ventilator', 'ventilador', 'respirador', 'pip', 'pplat', 'vt', 'tidal volume', 'tv', 'fio2', 'peep', 'rr',
      'inspiración', 'espiración', 'modo vent'
    ])) {
      return 'Ventilador';
    }
    if (containsAny(['defibrillator', 'desfibrilador', 'aed', 'shock', 'joules', 'j', 'sync', 'palas', 'pads'])) {
      return 'Desfibrilador';
    }
    if (containsAny([
      'infusion pump', 'syringe pump', 'bomba', 'jeringa', 'ml/h', 'mL/h', 'rate', 'dose', 'bolus', 'bolo', 'drug'
    ])) {
      return 'Bomba de infusión';
    }
    if (containsAny([
      'ultrasound', 'ultrasonido', 'ecografo', 'ecógrafo', 'probe', 'transducer', 'mhz', 'doppler', 'b-mode', 'freeze',
      'gain', 'depth'
    ])) {
      return 'Ecógrafo';
    }
    if (containsAny(['x-ray', 'rayos x', 'radiografía', 'radiography', 'kv', 'kvp', 'mas', 'exposure', 'colimador'])) {
      return 'Equipo de rayos X';
    }
    if (containsAny(['anesthesia', 'anestesia', 'sevoflurane', 'sevo', 'isoflurane', 'iso', 'vaporizador', 'o2', 'air', 'fgf'])) {
      return 'Máquina de anestesia';
    }
    if (containsAny(['electrobisturí', 'electrocirugía', 'esu', 'coag', 'cut', 'bipolar', 'monopolar'])) {
      return 'Electrobisturí';
    }
    return 'Equipo médico';
  }

  // Genera una descripción breve del funcionamiento del equipo (1–2 frases)
  String _briefDescriptionFor(String nameOrType) {
    final t = nameOrType.toLowerCase();
    bool has(String kw) => t.contains(kw);

    if (has('monitor')) {
      return 'Es un monitor de paciente que supervisa signos vitales como ECG, saturación de oxígeno (SpO2), presión arterial no invasiva (NIBP) y respiración. '
          'Se utiliza para vigilancia continua en áreas clínicas y quirúrgicas. '
          'Opera conectando sensores apropiados al paciente y configurando alarmas; el equipo adquiere y procesa las señales, muestra curvas y tendencias y alerta ante valores fuera de rango.';
    }
    if (has('ventilador')) {
      return 'Es un ventilador mecánico que asiste o sustituye la respiración controlando parámetros como volumen o presión, frecuencia, PEEP y FiO2. '
          'Se usa en UCI y quirófano para soporte ventilatorio. '
          'Opera mediante un circuito respiratorio que entrega respiraciones programadas; regula el flujo y la presión, monitoriza el intercambio y alerta ante eventos o desconexiones.';
    }
    if (has('desfibrilador') || has('aed')) {
      return 'Es un desfibrilador externo que administra descargas eléctricas controladas para revertir arritmias potencialmente letales. '
          'Se utiliza en emergencias y áreas críticas. '
          'Opera colocando paletas o parches en el tórax, analizando el ritmo, cargando una energía específica y aplicando la descarga para despolarizar el miocardio y restablecer el ritmo.';
    }
    if (has('bomba') && has('infusión')) {
      return 'Es una bomba de infusión que administra fármacos y fluidos con precisión a través de una vía. '
          'Se usa en hospitalización y UCI para terapias continuas o intermitentes. '
          'Opera programando el caudal y volumen (p. ej., mL/h) y accionando un mecanismo peristáltico o de jeringa que impulsa el fluido, con sensores que detectan oclusión y fin de infusión.';
    }
    if (has('ecógrafo') || has('ultrasound')) {
      return 'Es un ecógrafo que genera imágenes diagnósticas mediante ultrasonido. '
          'Se utiliza en múltiples especialidades clínicas para valoración anatómica y funcional. '
          'Opera aplicando gel y apoyando una sonda sobre el paciente; el transductor emite ondas de alta frecuencia, recibe los ecos y el equipo reconstruye imágenes (modo B, Doppler), ajustando ganancia y profundidad.';
    }
    if (has('rayos x') || has('x-ray')) {
      return 'Es un equipo de rayos X que produce imágenes radiográficas usando radiación ionizante. '
          'Se usa en diagnóstico por imagen. '
          'Opera posicionando al paciente y colimando el haz; el generador ajusta kVp y mAs, emite radiación y el detector capta la señal para formar la imagen, siguiendo protocolos de protección radiológica.';
    }
    if (has('anestesia')) {
      return 'Es una máquina de anestesia que administra gases y anestésicos inhalados y monitoriza parámetros durante procedimientos. '
          'Se usa en quirófano. '
          'Opera mezclando oxígeno/aire con anestésico mediante vaporizadores, regulando flujos; el circuito respiratorio y los monitores permiten ventilación controlada y seguimiento continuo del paciente.';
    }
    if (has('electrobisturí') || has('electrocirugía')) {
      return 'Es un electrobisturí que corta y coagula tejido mediante energía eléctrica controlada. '
          'Se utiliza en procedimientos quirúrgicos. '
          'Opera conectando una placa de retorno y un lápiz o punta activa; se seleccionan modos de corte/coagulación y potencias adecuadas para lograr hemostasia y disección segura.';
    }
    return 'Es un equipo biomédico destinado a diagnóstico o soporte terapéutico. '
        'Se emplea en contexto clínico bajo protocolos establecidos. '
        'Opera conectando los accesorios adecuados y configurando parámetros de uso según la aplicación, asegurando monitoreo y alarmas conforme a normas de seguridad.';
  }

  // Rasgos visibles derivados del texto OCR según el tipo inferido
  List<String> _visibleFeaturesFromText(String t, String deviceType) {
    final lower = t.toLowerCase();
    bool hasAny(List<String> kws) => kws.any((k) => lower.contains(k));
    final f = <String>[];

    if (deviceType.toLowerCase().contains('monitor')) {
      if (hasAny(['ecg'])) f.add('ECG');
      if (hasAny(['spo2','saturación'])) f.add('SpO₂');
      if (hasAny(['nibp','bp','presión'])) f.add('NIBP (presión no invasiva)');
      if (hasAny(['resp','etco2','co2','capno'])) f.add('respiración/EtCO₂');
      if (hasAny(['temp','temperatura'])) f.add('temperatura');
      if (hasAny(['ibp','p1','p2','map'])) f.add('presión invasiva');
    } else if (deviceType.toLowerCase().contains('ventilador')) {
      if (hasAny(['fio2'])) f.add('FiO₂');
      if (hasAny(['peep'])) f.add('PEEP');
      if (hasAny(['tidal volume','vt','tv'])) f.add('volumen tidal');
      if (hasAny(['rate','frecuencia','rr'])) f.add('frecuencia respiratoria');
      if (hasAny(['pip','pplat'])) f.add('PIP/Pplat');
    } else if (deviceType.toLowerCase().contains('desfibrilador')) {
      if (hasAny(['aed'])) f.add('modo AED');
      if (hasAny(['joules','j'])) f.add('selección de energía (J)');
      if (hasAny(['shock'])) f.add('botón de choque');
      if (hasAny(['sync'])) f.add('sincronización');
    } else if (deviceType.toLowerCase().contains('bomba')) {
      if (hasAny(['ml/h','mL/h'])) f.add('tasa en mL/h');
      if (hasAny(['syringe','jeringa'])) f.add('módulo jeringa');
      if (hasAny(['bolus','bolo'])) f.add('función de bolo');
      if (hasAny(['dose','drug'])) f.add('dosificación/programación');
    } else if (deviceType.toLowerCase().contains('ecógrafo')) {
      if (hasAny(['probe','sonda','transducer'])) f.add('sonda/transductor');
      if (hasAny(['mhz'])) f.add('frecuencia en MHz');
      if (hasAny(['doppler'])) f.add('modo Doppler');
      if (hasAny(['gain'])) f.add('ajuste de ganancia');
      if (hasAny(['freeze'])) f.add('congelación de imagen');
    } else if (deviceType.toLowerCase().contains('rayos x')) {
      if (hasAny(['kv','kvp'])) f.add('kVp');
      if (hasAny(['mas'])) f.add('mAs');
      if (hasAny(['detector','cassette'])) f.add('detector/cassette');
      if (hasAny(['exposure'])) f.add('control de exposición');
    } else if (deviceType.toLowerCase().contains('anestesia')) {
      if (hasAny(['isoflurane','sevoflurane','vaporizador','sevo','iso'])) f.add('vaporizador');
      if (hasAny(['o2','oxígeno','air'])) f.add('flujo de oxígeno/aire');
      if (hasAny(['ventilación','peep'])) f.add('ventilación controlada');
    } else if (deviceType.toLowerCase().contains('electrobisturí')) {
      if (hasAny(['cut'])) f.add('modo corte');
      if (hasAny(['coag'])) f.add('modo coagulación');
      if (hasAny(['bipolar'])) f.add('salida bipolar');
      if (hasAny(['monopolar'])) f.add('salida monopolar');
    }

    // Rasgos generales visibles
    final general = <Map<String,String>>[
      {'k':'screen','l':'pantalla'},
      {'k':'display','l':'pantalla'},
      {'k':'menu','l':'menú'},
      {'k':'alarm','l':'alarmas'},
      {'k':'start','l':'botón START'},
      {'k':'stop','l':'botón STOP'},
      {'k':'power','l':'encendido'},
      {'k':'usb','l':'puerto USB'},
      {'k':'ethernet','l':'puerto Ethernet'},
      {'k':'printer','l':'impresora'},
      {'k':'probe','l':'sonda'},
      {'k':'sensor','l':'sensor'},
      {'k':'lead','l':'derivaciones'},
    ];
    for (final g in general) {
      if (lower.contains(g['k']!)) f.add(g['l']!);
    }

    final abbrevMatches = RegExp(r'\b([A-Z]{2,6})(?:\b|\s|\d)').allMatches(t);
    final seen = <String>{};
    for (final m in abbrevMatches) {
      final token = m.group(1) ?? '';
      if (token.isEmpty) continue;
      final norm = token.toUpperCase();
      if ({'ECG','SPO2','NIBP','IBP','RR','HR','BP','VT','PEEP','FIO2','KV','KVP','MAS','AED','CO2','ETCO2'}.contains(norm)) {
        if (seen.add(norm)) f.add(norm);
      }
    }

    return f.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().take(4).toList();
  }

  // Párrafo descriptivo basado en rasgos detectados
  String _paragraphFromOcr(String deviceType, List<String> features) {
    final feats = features.isNotEmpty
        ? 'En la imagen se aprecian ' + features.join(', ') + ', lo que orienta la identificación y su función.'
        : 'En la imagen se distinguen elementos del panel y controles; sin texto técnico claro, se describe su uso genérico.';
    switch (deviceType.toLowerCase()) {
      case 'monitor de paciente':
        return 'Es un monitor de paciente utilizado para la vigilancia continua de signos vitales en hospitalización, UCI y quirófano. '
            'Mide parámetros y gestiona alarmas en tiempo real para apoyar decisiones clínicas. '
            '$feats '
            'Opera conectando sensores al paciente y configurando límites y modos; la pantalla muestra curvas y valores numéricos con alarmas visuales/sonoras.';
      case 'ventilador':
        return 'Es un ventilador mecánico destinado a soporte respiratorio en pacientes que requieren asistencia. '
            'Administra mezclas de gas y controla presión/volumen y tiempos de inspiración/espiración según el modo seleccionado. '
            '$feats '
            'Se usa en UCI y quirófano; el operador ajusta parámetros como FiO₂, PEEP y volumen tidal para adecuarse a la condición clínica.';
      case 'desfibrilador':
        return 'Es un desfibrilador para tratar arritmias potencialmente letales mediante la aplicación de una descarga eléctrica controlada. '
            'Evalúa el ritmo y permite seleccionar energía y sincronización cuando corresponde. '
            '$feats '
            'Se utiliza en emergencias y áreas críticas; el operador coloca las palas/pads y administra el choque siguiendo protocolos de seguridad.';
      case 'bomba de infusión':
        return 'Es una bomba de infusión diseñada para administrar fármacos o fluidos a una tasa precisa y constante. '
            'Permite configurar parámetros de flujo y volumen, con alarmas ante oclusiones o fin de infusión. '
            '$feats '
            'Se usa en hospitalización y UCI; el clínico programa la tasa y supervisa el tratamiento según las órdenes médicas.';
      case 'ecógrafo':
        return 'Es un ecógrafo utilizado para diagnóstico por ultrasonido en múltiples aplicaciones clínicas. '
            'Genera imágenes en tiempo real a partir de ecos de alta frecuencia reflejados por los tejidos. '
            '$feats '
            'Se opera seleccionando la sonda y los modos (B/Doppler), ajustando ganancia y profundidad para evaluar estructuras anatómicas.';
      case 'equipo de rayos x':
        return 'Es un equipo de rayos X empleado para obtención de imágenes radiográficas, útil en diagnóstico óseo y torácico, entre otros. '
            'Produce radiación ionizante controlada y utiliza detectores o chasis para registrar la imagen. '
            '$feats '
            'El operador ajusta kVp y mAs, posiciona al paciente y activa la exposición cumpliendo normas de protección.';
      case 'máquina de anestesia':
        return 'Es una máquina de anestesia que mezcla gases y vapores anestésicos para mantener al paciente bajo anestesia durante procedimientos. '
            'Integra ventilación y monitorización básica, con control de flujos y vaporizadores. '
            '$feats '
            'Se utiliza en quirófano; el anestesiólogo regula flujos y ventilación, vigilando parámetros y alarmas de seguridad.';
      default:
        return 'Es un equipo biomédico de aplicación clínica. '
            '$feats '
            'Su operación implica conectar accesorios apropiados, ajustar parámetros según el procedimiento y vigilar alarmas para un uso seguro.';
    }
  }

  Future<String> _runOcrSpace(String base64Image, {required String mimeType, List<String> languages = const ['eng']}) async {
    for (final lang in languages) {
      final uri = Uri.parse('https://api.ocr.space/parse/image');
      final req = http.MultipartRequest('POST', uri)
        ..fields['apikey'] = 'helloworld'
        ..fields['language'] = lang
        ..fields['isOverlayRequired'] = 'false'
        ..fields['scale'] = 'true'
        ..fields['detectOrientation'] = 'true'
        ..fields['OCREngine'] = '2'
        ..fields['base64Image'] = 'data:' + (mimeType.isNotEmpty ? mimeType : 'image/jpeg') + ';base64,' + base64Image;

      final resp = await req.send();
      final bodyText = await resp.stream.bytesToString();
      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        final data = jsonDecode(bodyText);
        final parsed = data['ParsedResults']?[0]?['ParsedText']?.toString() ?? '';
        if (parsed.trim().isNotEmpty) {
          return parsed;
        }
      }
      // Si falló o vacío, intenta siguiente idioma
    }
    return '';
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final name = xfile.name;
      final mime = lookupMimeType(name, headerBytes: bytes) ?? 'image/jpeg';
      if (!context.mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = name;
        _imageMimeType = mime;
      });
    } catch (e) {
      if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al tomar foto: $e')));
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      // Permitir archivos de imagen de todo tipo; algunos formatos (p.ej. HEIC) no muestran preview en web
      final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true, allowMultiple: false);
      final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
      final bytes = file?.bytes;
      if (bytes == null || file == null) return;
      final name = file.name;
      var mime = lookupMimeType(name, headerBytes: bytes) ?? 'application/octet-stream';
      // Si no se puede inferir, intenta usar tipos comunes de imagen
      if (mime == 'application/octet-stream') {
        final header = bytes.take(12).toList();
        final asHex = header.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        if (asHex.startsWith('89504e47')) mime = 'image/png';
        else if (asHex.startsWith('ffd8ff')) mime = 'image/jpeg';
        else if (asHex.startsWith('52494646') && asHex.contains('57454250')) mime = 'image/webp';
        else if (asHex.startsWith('424d')) mime = 'image/bmp';
      }
      if (!context.mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = name;
        _imageMimeType = mime;
      });
    } catch (e) {
      if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar imagen: $e')));
    }
  }

  Future<void> _uploadImage({required String equipmentId}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes iniciar sesión para subir imágenes')),
        );
        return;
      }
      if (_imageBytes == null) return;
      final path = 'equipment/$equipmentId/${DateTime.now().millisecondsSinceEpoch}_${_imageName ?? 'image'}';
      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(
            path,
            _imageBytes!,
            fileOptions: FileOptions(contentType: _imageMimeType ?? 'application/octet-stream', upsert: true),
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen subida correctamente')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
    }
  }

  Future<void> _loadExistingImageUrl() async {
    try {
      final id = widget.existing?.id;
      if (id == null) return;
      final client = Supabase.instance.client;
      final files = await client.storage.from('images').list(path: 'equipment/$id');
      if (files.isEmpty) return;
      DateTime parseDate(dynamic v) {
        if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
        if (v is DateTime) return v;
        return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      files.sort((a, b) => parseDate(b.createdAt).compareTo(parseDate(a.createdAt)));
      final latest = files.first;
      final path = 'equipment/$id/${latest.name}';
      final url = client.storage.from('images').getPublicUrl(path);
      if (mounted) {
        setState(() {
          _existingImageUrl = url;
        });
      }
    } catch (_) {
      // ignore errors silently for minimal UI impact
    }
  }
}