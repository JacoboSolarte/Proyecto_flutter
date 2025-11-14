import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'analysis_result_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/maintenance_providers.dart';
import '../widgets/image_analyzer_sheet.dart';
import '../utils/notes_utils.dart';
import '../widgets/summary_bar.dart';
import '../widgets/status_filter_bar.dart';
import '../widgets/skeleton_card.dart';
import '../widgets/empty_state.dart';

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
    final countMantenimiento = items
        .where((e) => e.status == 'mantenimiento')
        .length;
    final countFueraServicio = items
        .where((e) => e.status == 'fuera_de_servicio')
        .length;
    final countSeguimiento = items
        .where((e) => e.status == 'requiere_seguimiento')
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipos biomédicos'),
        actions: [
          IconButton(
            tooltip: 'Analizar imagen (IA)',
            icon: const Icon(Icons.smart_toy_outlined),
            onPressed: _openImageAnalyzerSheet,
          ),
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
            child: SummaryBar(
              total: total,
              countOperativo: countOperativo,
              countMantenimiento: countMantenimiento,
              countFueraServicio: countFueraServicio,
              countSeguimiento: countSeguimiento,
            ),
          ),
          StatusFilterBar(
            selectedStatus: _selectedStatus,
            total: total,
            countOperativo: countOperativo,
            countMantenimiento: countMantenimiento,
            countFueraServicio: countFueraServicio,
            countSeguimiento: countSeguimiento,
            onStatusSelected: (value) {
              setState(() {
                _selectedStatus = value;
              });
              _triggerSearch();
            },
          ),
          // Analizador movido a bottom sheet desde navbar inferior
          Expanded(
            child: state.when(
              loading: () => ListView.builder(
                itemCount: 6,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemBuilder: (context, index) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: SkeletonCard(),
                ),
              ),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => items.isEmpty
                  ? EmptyState(
                      onAdd: () async {
                        final created = await Navigator.of(context).push<Equipment?>(
                          MaterialPageRoute(builder: (_) => const EquipmentFormPage()),
                        );
                        if (created != null && mounted) {
                          await ref
                              .read(equipmentListControllerProvider.notifier)
                              .loadInitial();
                        }
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref
                            .read(equipmentListControllerProvider.notifier)
                            .loadInitial(
                              query: EquipmentQuery(
                                search: _searchController.text.trim(),
                                status: _selectedStatus,
                              ),
                            );
                      },
                      child: (MediaQuery.of(context).size.width >= 900)
                          ? GridView.builder(
                              controller: _scrollController,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 2.8,
                                  ),
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final eq = items[index];
                                return EquipmentCard(
                                  equipment: eq,
                                  onTap: () {
                                    () async {
                                      final result = await Navigator.of(context)
                                          .push<Equipment?>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  EquipmentDetailPage(
                                                    id: eq.id,
                                                  ),
                                            ),
                                          );
                                      if (result != null && mounted) {
                                        ref
                                            .read(
                                              equipmentListControllerProvider
                                                  .notifier,
                                            )
                                            .replaceItem(result);
                                      }
                                    }();
                                  },
                                  onHeader: () {
                                    ref.invalidate(
                                      maintenancesByEquipmentProvider(eq.id),
                                    );
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EquipmentHeaderPage(
                                          equipmentId: eq.id,
                                        ),
                                      ),
                                    );
                                  },
                                  onAddMaintenance: () async {
                                    final result = await Navigator.of(context)
                                        .push<bool?>(
                                          MaterialPageRoute(
                                            builder: (_) => MaintenanceFormPage(
                                              equipmentId: eq.id,
                                            ),
                                          ),
                                        );
                                    if (result == true && mounted) {
                                      ref.invalidate(
                                        maintenancesByEquipmentProvider(eq.id),
                                      );
                                      ref
                                          .read(
                                            equipmentListControllerProvider
                                                .notifier,
                                          )
                                          .loadInitial(
                                            query: EquipmentQuery(
                                              search: _searchController.text
                                                  .trim(),
                                              status: _selectedStatus,
                                            ),
                                          );
                                    }
                                  },
                                  onEdit: () async {
                                    final updated = await Navigator.of(context)
                                        .push<Equipment?>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                EquipmentFormPage(existing: eq),
                                          ),
                                        );
                                    if (updated != null && mounted) {
                                      ref
                                          .read(
                                            equipmentListControllerProvider
                                                .notifier,
                                          )
                                          .replaceItem(updated);
                                    }
                                  },
                                  onDelete: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Eliminar equipo'),
                                        content: const Text(
                                          '¿Deseas eliminar este equipo?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final useCase = ref.read(
                                        deleteEquipmentUseCaseProvider,
                                      );
                                      await useCase(eq.id);
                                      if (mounted) {
                                        ref
                                            .read(
                                              equipmentListControllerProvider
                                                  .notifier,
                                            )
                                            .loadInitial(
                                              query: EquipmentQuery(
                                                search: _searchController.text
                                                    .trim(),
                                                status: _selectedStatus,
                                              ),
                                            );
                                      }
                                    }
                                  },
                                );
                              },
                            )
                          : ListView.separated(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final eq = items[index];
                                return EquipmentCard(
                                  equipment: eq,
                                  onTap: () {
                                    () async {
                                      final result = await Navigator.of(context)
                                          .push<Equipment?>(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  EquipmentDetailPage(
                                                    id: eq.id,
                                                  ),
                                            ),
                                          );
                                      if (result != null && mounted) {
                                        // Refleja el cambio del detalle inmediatamente en la lista
                                        ref
                                            .read(
                                              equipmentListControllerProvider
                                                  .notifier,
                                            )
                                            .replaceItem(result);
                                      }
                                    }();
                                  },
                                  onHeader: () {
                                    // Invalida cache del historial para forzar recarga al abrir encabezado
                                    ref.invalidate(
                                      maintenancesByEquipmentProvider(eq.id),
                                    );
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => EquipmentHeaderPage(
                                          equipmentId: eq.id,
                                        ),
                                      ),
                                    );
                                  },
                                  onAddMaintenance: () async {
                                    final result = await Navigator.of(context)
                                        .push<bool?>(
                                          MaterialPageRoute(
                                            builder: (_) => MaintenanceFormPage(
                                              equipmentId: eq.id,
                                            ),
                                          ),
                                        );
                                    if (result == true && mounted) {
                                      // Invalida historial para que el encabezado muestre el nuevo mantenimiento
                                      ref.invalidate(
                                        maintenancesByEquipmentProvider(eq.id),
                                      );
                                      ref
                                          .read(
                                            equipmentListControllerProvider
                                                .notifier,
                                          )
                                          .loadInitial(
                                            query: EquipmentQuery(
                                              search: _searchController.text
                                                  .trim(),
                                              status: _selectedStatus,
                                            ),
                                          );
                                    }
                                  },
                                  onEdit: () async {
                                    final updated = await Navigator.of(context)
                                        .push<Equipment?>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                EquipmentFormPage(existing: eq),
                                          ),
                                        );
                                    if (updated != null && mounted) {
                                      // Refleja el cambio inmediatamente en la lista actual, sin reiniciar la lista
                                      ref
                                          .read(
                                            equipmentListControllerProvider
                                                .notifier,
                                          )
                                          .replaceItem(updated);
                                    }
                                  },
                                  onDelete: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Eliminar equipo'),
                                        content: const Text(
                                          '¿Deseas eliminar este equipo?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancelar'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Eliminar'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final useCase = ref.read(
                                        deleteEquipmentUseCaseProvider,
                                      );
                                      await useCase(eq.id);
                                      if (mounted) {
                                        ref
                                            .read(
                                              equipmentListControllerProvider
                                                  .notifier,
                                            )
                                            .loadInitial(
                                              query: EquipmentQuery(
                                                search: _searchController.text
                                                    .trim(),
                                                status: _selectedStatus,
                                              ),
                                            );
                                      }
                                    }
                                  },
                                );
                              },
                            ),
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
                .loadInitial(
                  query: EquipmentQuery(
                    search: _searchController.text.trim(),
                    status: _selectedStatus,
                  ),
                );
          }
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              mainAxisAlignment: _isSearchOpen
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.spaceEvenly,
              children: [
                if (_isSearchOpen)
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText:
                            'Buscar por nombre, marca, modelo, serie o ubicación',
                        isDense: true,
                        filled: true,
                        fillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        prefixIcon: const Icon(Icons.search),
                        // Limito el ancho del sufijo para evitar overflow dentro del TextField
                        suffixIconConstraints: const BoxConstraints(
                          maxWidth: 120,
                        ),
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

  void _openImageAnalyzerSheet() {
    showImageAnalyzerSheet(context);
  }

  void _debouncedSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _triggerSearch);
  }

  void _triggerSearch() {
    ref
        .read(equipmentListControllerProvider.notifier)
        .loadInitial(
          query: EquipmentQuery(
            search: _searchController.text.trim(),
            status: _selectedStatus,
          ),
        );
  }

  // Eliminado: hoja de analizador IA

  

  

  

  
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
                'notes': stripOptionsFromNotes(
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
        final onlyParagraph = stripOptionsFromNotes(clean);
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

 

  

}
