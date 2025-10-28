import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
                      if (mounted) Navigator.pop(context, created);
                    } else {
                      final useCase = ref.read(updateEquipmentUseCaseProvider);
                      final updated = await useCase(widget.existing!.id, equipment);
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
}