import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
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
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'operativo', child: Text('Operativo')),
                    DropdownMenuItem(value: 'mantenimiento', child: Text('Mantenimiento')),
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
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _existingImageUrl!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
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
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sesión no válida')));
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

  Future<void> _pickFromCamera() async {
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      final name = xfile.name;
      final mime = lookupMimeType(name, headerBytes: bytes) ?? 'image/jpeg';
      setState(() {
        _imageBytes = bytes;
        _imageName = name;
        _imageMimeType = mime;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al tomar foto: $e')));
      }
    }
  }

  Future<void> _pickFromFiles() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true, allowMultiple: false);
      final file = (res != null && res.files.isNotEmpty) ? res.files.first : null;
      final bytes = file?.bytes;
      if (bytes == null || file == null) return;
      final name = file.name;
      final mime = lookupMimeType(name, headerBytes: bytes) ?? 'application/octet-stream';
      setState(() {
        _imageBytes = bytes;
        _imageName = name;
        _imageMimeType = mime;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al seleccionar imagen: $e')));
      }
    }
  }

  Future<void> _uploadImage({required String equipmentId}) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Debes iniciar sesión para subir imágenes')),
          );
        }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Imagen subida correctamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir imagen: $e')));
      }
    }
  }

  Future<void> _loadExistingImageUrl() async {
    try {
      final id = widget.existing?.id;
      if (id == null) return;
      final client = Supabase.instance.client;
      final files = await client.storage.from('images').list(path: 'equipment/$id');
      if (files.isEmpty) return;
      DateTime _parse(dynamic v) {
        if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
        if (v is DateTime) return v;
        return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      files.sort((a, b) => _parse(b.createdAt).compareTo(_parse(a.createdAt)));
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