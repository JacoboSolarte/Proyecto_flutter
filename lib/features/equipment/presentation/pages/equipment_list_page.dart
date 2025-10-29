import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/repositories/equipment_repository.dart';
import '../widgets/equipment_card.dart';
import 'dart:async';
import '../providers/equipment_providers.dart';
import 'equipment_form_page.dart';
import 'equipment_detail_page.dart';
import 'equipment_header_page.dart';
import 'maintenance_form_page.dart';
import 'qr_scan_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'analysis_result_page.dart';
import '../providers/maintenance_providers.dart';

class EquipmentListPage extends ConsumerStatefulWidget {
  const EquipmentListPage({super.key});

  @override
  ConsumerState<EquipmentListPage> createState() => _EquipmentListPageState();
}

class _EquipmentListPageState extends ConsumerState<EquipmentListPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String? _selectedStatus;
  Timer? _debounce;
  // Eliminado índice no utilizado para evitar warnings
  bool _isSearchOpen = false;

  @override
  void initState() {
    super.initState();
    ref.read(equipmentListControllerProvider.notifier).loadInitial();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(equipmentListControllerProvider.notifier).loadNext();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(equipmentListControllerProvider);
    final items = state.value ?? [];
    // Métricas de resumen para el encabezado
    final total = items.length;
    final countOperativo = items.where((e) => e.status == 'operativo').length;
    final countMantenimiento = items.where((e) => e.status == 'mantenimiento').length;
    final countFueraServicio = items.where((e) => e.status == 'fuera_de_servicio').length;
    final countSeguimiento = items.where((e) => e.status == 'requiere_seguimiento').length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipos biomédicos'),
        actions: [
          IconButton(
            tooltip: 'Salir',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 4),
          // Resumen de métricas
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _summaryChip(context, label: 'Total', icon: Icons.list_alt, count: total, color: Theme.of(context).colorScheme.primary),
                    _summaryChip(context, label: 'Operativo', icon: Icons.check_circle, count: countOperativo, color: Colors.green),
                    _summaryChip(context, label: 'Mantenimiento', icon: Icons.build_circle, count: countMantenimiento, color: Colors.amber),
                    _summaryChip(context, label: 'Fuera de servicio', icon: Icons.report, count: countFueraServicio, color: Colors.red),
                    _summaryChip(context, label: 'Seguimiento', icon: Icons.track_changes, count: countSeguimiento, color: Colors.blueGrey),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildStatusChip(null, 'Todos'),
                _buildStatusChip('operativo', 'Operativo'),
                _buildStatusChip('mantenimiento', 'Mantenimiento'),
                _buildStatusChip('fuera_de_servicio', 'Fuera de servicio'),
                _buildStatusChip('requiere_seguimiento', 'Requiere seguimiento'),
              ],
            ),
          ),
          // Analizador movido a bottom sheet desde navbar inferior
          Expanded(
            child: state.when(
              loading: () => _buildLoadingList(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => items.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final eq = items[index];
                        return EquipmentCard(
                          equipment: eq,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EquipmentDetailPage(id: eq.id),
                              ),
                            );
                          },
                          onHeader: () {
                            // Invalida cache del historial para forzar recarga al abrir encabezado
                            ref.invalidate(maintenancesByEquipmentProvider(eq.id));
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EquipmentHeaderPage(equipmentId: eq.id),
                              ),
                            );
                          },
                          onAddMaintenance: () async {
                            final result = await Navigator.of(context).push<bool?>(
                              MaterialPageRoute(
                                builder: (_) => MaintenanceFormPage(equipmentId: eq.id),
                              ),
                            );
                            if (result == true && mounted) {
                              // Invalida historial para que el encabezado muestre el nuevo mantenimiento
                              ref.invalidate(maintenancesByEquipmentProvider(eq.id));
                              ref.read(equipmentListControllerProvider.notifier).loadInitial(
                                    query: EquipmentQuery(search: _searchController.text.trim(), status: _selectedStatus),
                                  );
                            }
                          },
                          onEdit: () async {
                            final updated = await Navigator.of(context).push<Equipment?>(
                              MaterialPageRoute(
                                builder: (_) => EquipmentFormPage(existing: eq),
                              ),
                            );
                            if (updated != null && mounted) {
                              ref.read(equipmentListControllerProvider.notifier).loadInitial(
                                    query: EquipmentQuery(search: _searchController.text.trim(), status: _selectedStatus),
                                  );
                            }
                          },
                          onDelete: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Eliminar equipo'),
                                content: const Text('¿Deseas eliminar este equipo?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Eliminar'),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              final useCase = ref.read(deleteEquipmentUseCaseProvider);
                              await useCase(eq.id);
                              if (mounted) {
                                ref
                                    .read(equipmentListControllerProvider.notifier)
                                    .loadInitial(
                                      query: EquipmentQuery(search: _searchController.text.trim(), status: _selectedStatus),
                                    );
                              }
                            }
                          },
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Agregar equipo',
        onPressed: () async {
          final created = await Navigator.of(context).push<Equipment?>(
            MaterialPageRoute(builder: (_) => const EquipmentFormPage()),
          );
          if (created != null && mounted) {
            ref
                .read(equipmentListControllerProvider.notifier)
                .loadInitial(query: EquipmentQuery(search: _searchController.text.trim(), status: _selectedStatus));
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              mainAxisAlignment:
                  _isSearchOpen ? MainAxisAlignment.start : MainAxisAlignment.spaceEvenly,
              children: [
                if (_isSearchOpen)
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, marca, modelo, serie o ubicación',
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                        prefixIcon: const Icon(Icons.search),
                        // Limito el ancho del sufijo para evitar overflow dentro del TextField
                        suffixIconConstraints: const BoxConstraints(maxWidth: 120),
                        suffixIcon: SizedBox(
                          width: 110,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_searchController.text.isNotEmpty)
                                IconButton(
                                  tooltip: 'Limpiar',
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    _triggerSearch();
                                  },
                                ),
                              IconButton(
                                tooltip: 'Cerrar búsqueda',
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() => _isSearchOpen = false);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      onChanged: (_) => _debouncedSearch(),
                      onSubmitted: (_) => _triggerSearch(),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: 'Inicio',
                    icon: const Icon(Icons.home),
                    onPressed: () {
                      if (_scrollController.hasClients) {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Analizador IA',
                    icon: const Icon(Icons.smart_toy),
                    onPressed: _openImageAnalyzerSheet,
                  ),
                  IconButton(
                    tooltip: 'Escanear',
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QrScanPage()),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Buscar',
                    icon: const Icon(Icons.search),
                    onPressed: () {
                      setState(() => _isSearchOpen = true);
                    },
                  ),
                  IconButton(
                    tooltip: 'Perfil',
                    icon: const Icon(Icons.person),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfilePage()),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _debouncedSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _triggerSearch);
  }

  void _triggerSearch() {
    ref.read(equipmentListControllerProvider.notifier).loadInitial(
          query: EquipmentQuery(search: _searchController.text.trim(), status: _selectedStatus),
        );
  }

  void _openImageAnalyzerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          child: SingleChildScrollView(
            child: const _ImageAnalyzerInline(),
          ),
        );
      },
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      itemCount: 6,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: _SkeletonCard(),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
                    Icon(Icons.inventory_2, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No hay equipos registrados', style: t.titleMedium),
            const SizedBox(height: 8),
            Text('Agrega tu primer equipo con el botón +', style: t.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? value, String label) {
    final selected = _selectedStatus == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (isSelected) {
          setState(() {
            _selectedStatus = isSelected ? value : null;
          });
          _triggerSearch();
        },
      ),
    );
  }

  Widget _summaryChip(
    BuildContext context, {
    required String label,
    required IconData icon,
    required int count,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color.withOpacity(0.10);
    final border = color.withOpacity(0.25);
    return Chip(
      avatar: Icon(icon, color: color, size: 18),
      label: Text('$label: $count', style: TextStyle(color: scheme.onSurface)),
      backgroundColor: bg,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Container(height: 16, width: 160, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
              Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
              Container(height: 12, width: 220, decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }
}

class _ImageAnalyzerInline extends StatefulWidget {
  const _ImageAnalyzerInline();

  @override
  State<_ImageAnalyzerInline> createState() => _ImageAnalyzerInlineState();
}

class _ImageAnalyzerInlineState extends State<_ImageAnalyzerInline> {
  Uint8List? _imageBytes;
  String? _imageName;
  String? _imageMimeType;
  bool _isAnalyzing = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Analizador de imágenes'),
              subtitle: const Text('Toma una foto o súbela y analiza con IA'),
            ),
            const SizedBox(height: 8),
            // Acciones responsivas para evitar overflow horizontal
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
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al tomar foto: $e')));
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true, allowMultiple: false);
      final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
      final bytes = file?.bytes;
      if (bytes == null || file == null) return;
      final name = file.name;
      var mime = lookupMimeType(name, headerBytes: bytes) ?? 'application/octet-stream';
      if (mime == 'application/octet-stream') {
        final header = bytes.take(12).toList();
        final asHex = header.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
        if (asHex.startsWith('89504e47')) mime = 'image/png';
        else if (asHex.startsWith('ffd8ff')) mime = 'image/jpeg';
        else if (asHex.startsWith('52494646') && asHex.contains('57454250')) mime = 'image/webp';
        else if (asHex.startsWith('424d')) mime = 'image/bmp';
      }
      if (!mounted) return;
      setState(() {
        _imageBytes = bytes;
        _imageName = name;
        _imageMimeType = mime;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar imagen: $e')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Selecciona o toma una imagen para analizar')));
      setState(() => _isAnalyzing = false);
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

        if (!mounted) return;
        await Navigator.of(context).push(
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
                'notes': _stripOptionsFromNotes(
                  (result['notes']?.toString() ?? result['description']?.toString() ?? '').trim(),
                ),
              'options_brand': result['brand']?.toString() ?? 'Desconocido',
              'options_model': result['model']?.toString() ?? 'Desconocido',
              'options_serial': result['serial']?.toString() ?? 'Desconocido',
            },
            rawText: rawText,
          ),
        ),
      );
      return; // mostramos resultados y no intentamos la función
      } else {
        // 2) Sin API key en cliente: no usar Supabase; informar configuración requerida
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configura GOOGLE_API_KEY para usar análisis 100% IA.')),
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
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<Map<String, dynamic>> _callGeminiDirectFallback(Map<String, dynamic> body, String apiKey) async {
    // Prompt descriptivo: un único párrafo sustentado en rasgos visibles de la imagen.
    const prompt =
        'Eres un asistente técnico biomédico. Observa la imagen y determina el tipo genérico del equipo (no la marca ni el modelo). '
        'Escribe únicamente UN PÁRRAFO en español (120–180 palabras) que explique: 1) qué es y 2) para qué se usa. '
        'Apóyate explícitamente en lo que se ve: menciona al menos 3 rasgos visibles (por ejemplo, pantalla/controles, puertos/conectores, sondas/accesorios, textos legibles, formas o materiales) '
        'y cómo esos rasgos justifican la identificación y el uso. Describe brevemente cómo se opera en uso típico y el contexto clínico. '
        'Evita respuestas genéricas; personaliza la explicación a la imagen. NO incluyas marcas, modelos ni números de serie. '
        'Si la imagen NO muestra un equipo biomédico, responde exactamente: "No le puedo responder a eso".';

    final configuredModel =
        dotenv.maybeGet('GEMINI_MODEL') ?? const String.fromEnvironment('GEMINI_MODEL');
    final models = (configuredModel != null && configuredModel.trim().isNotEmpty)
        ? [configuredModel.trim()]
        : [
            // Prioriza modelos más recientes y luego retrocede a versiones estables.
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
    if (body['mode'] == 'base64') base64 = body['image_base64']?.toString();
    if (base64 == null || base64.isEmpty) {
    throw Exception('Imagen no disponible para IA');
    }

    final parts = [
      {'text': prompt},
      {'inline_data': {'mime_type': mime, 'data': base64}},
    ];
    final payload = {
      'contents': [
        {'role': 'user', 'parts': parts}
      ],
      'generationConfig': {'temperature': 0.3, 'responseMimeType': 'text/plain', 'maxOutputTokens': 512},
    };

    for (final model in models) {
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey');
      final resp = await http.post(url, headers: {'content-type': 'application/json'}, body: jsonEncode(payload));
      Map<String, dynamic> data;
      try {
        data = jsonDecode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        continue; // intenta siguiente modelo
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
                    // A veces la salida es JSON directo
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
        final onlyParagraph = _stripOptionsFromNotes(clean);
        return {
          'result': {
            'notes': onlyParagraph,
          },
          'model_used': model,
          'raw_text': raw,
        };
      }
    }
    throw Exception('No se pudo obtener respuesta de IA');
  }

  // (OCR y descripciones heurísticas eliminadas para garantizar respuesta 100% IA)

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
}