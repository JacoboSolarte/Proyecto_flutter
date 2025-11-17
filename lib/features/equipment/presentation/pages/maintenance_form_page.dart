import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/maintenance.dart';
import '../providers/maintenance_providers.dart';
import '../providers/equipment_providers.dart';
import '../../domain/entities/equipment.dart';
import '../widgets/ui_components.dart';
import '../../constants/maintenance.dart';
import '../../constants/status.dart';
import '../../../../data/options.dart';

class MaintenanceFormPage extends ConsumerStatefulWidget {
  final String equipmentId;
  const MaintenanceFormPage({super.key, required this.equipmentId});

  @override
  ConsumerState<MaintenanceFormPage> createState() =>
      _MaintenanceFormPageState();
}

class _MaintenanceFormPageState extends ConsumerState<MaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _maintenanceDate = DateTime.now();
  String _maintenanceType = MaintenanceTypes.preventivo;
  String _finalStatus = EquipmentStatus.operativo;
  DateTime? _nextMaintenanceDate;
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _partsCtrl = TextEditingController();
  final TextEditingController _responsibleCtrl = TextEditingController();

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _partsCtrl.dispose();
    _responsibleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
    BuildContext context,
    DateTime initial,
    void Function(DateTime) onPicked, {
    DateTime? minDate,
    DateTime? maxDate,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: minDate ?? DateTime(now.year - 10),
      lastDate: maxDate ?? DateTime(now.year + 10),
    );
    if (picked != null) {
      onPicked(picked);
      setState(() {});
    }
  }

  Future<void> _save(BuildContext context, Equipment eq) async {
    if (!_formKey.currentState!.validate()) return;
    if (_nextMaintenanceDate != null &&
        _nextMaintenanceDate!.isBefore(_maintenanceDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La próxima fecha no puede ser anterior a la fecha del mantenimiento',
          ),
        ),
      );
      return;
    }
    final createMaint = ref.read(createMaintenanceUseCaseProvider);
    final updater = ref.read(updateEquipmentUseCaseProvider);

    final maint = Maintenance(
      id: 'new',
      equipmentId: eq.id,
      maintenanceDate: _maintenanceDate,
      maintenanceType: _maintenanceType,
      description: _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      partsUsed: _partsCtrl.text.trim().isEmpty ? null : _partsCtrl.text.trim(),
      responsible: _responsibleCtrl.text.trim().isEmpty
          ? null
          : _responsibleCtrl.text.trim(),
      finalStatus: _finalStatus,
      nextMaintenanceDate: _nextMaintenanceDate,
    );

    // ignore: use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    // ignore: use_build_context_synchronously
    final navigator = Navigator.of(context);
    try {
      await createMaint(maint);
      final updatedEq = Equipment(
        id: eq.id,
        name: eq.name,
        brand: eq.brand,
        model: eq.model,
        serial: eq.serial,
        location: eq.location,
        status: _finalStatus,
        purchaseDate: eq.purchaseDate,
        lastMaintenanceDate: _maintenanceDate,
        nextMaintenanceDate: _nextMaintenanceDate ?? eq.nextMaintenanceDate,
        vendor: eq.vendor,
        warrantyExpireDate: eq.warrantyExpireDate,
        notes: eq.notes,
        createdAt: eq.createdAt,
        updatedAt: eq.updatedAt,
        createdBy: eq.createdBy,
      );
      await updater(eq.id, updatedEq);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Mantenimiento registrado')),
      );
      navigator.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(equipmentDetailProvider(widget.equipmentId));
    return detail.when(
      loading: () => const Scaffold(
        appBar: _FormAppBar(),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        appBar: const _FormAppBar(),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Error cargando equipo: ${e.toString()}'),
        ),
      ),
      data: (eq) => Scaffold(
        appBar: const _FormAppBar(),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            eq.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(label: Text('ID: ${eq.id}')),
                              if (eq.location != null)
                                Chip(label: Text('Ubicación: ${eq.location}')),
                              Chip(label: Text('Estado actual: ${eq.status}')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _DateField(
                            label: 'Fecha del mantenimiento',
                            value: _maintenanceDate,
                            onPick: () => _pickDate(
                              context,
                              _maintenanceDate,
                              (d) => _maintenanceDate = d,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DropdownField(
                            label: 'Tipo de mantenimiento',
                            value: _maintenanceType,
                            items: maintenanceTypeOptions,
                            onChanged: (v) => setState(
                              () => _maintenanceType =
                                  v ?? MaintenanceTypes.preventivo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _TextField(
                            label: 'Descripción de la actividad realizada',
                            controller: _descriptionCtrl,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          _TextField(
                            label: 'Repuestos utilizados',
                            controller: _partsCtrl,
                          ),
                          const SizedBox(height: 12),
                          _TextField(
                            label: 'Responsable',
                            controller: _responsibleCtrl,
                            requiredField: true,
                          ),
                          const SizedBox(height: 12),
                          _DropdownField(
                            label: 'Estado final del equipo',
                            value: _finalStatus,
                            items: equipmentStatusOptions,
                            onChanged: (v) => setState(
                              () =>
                                  _finalStatus = v ?? EquipmentStatus.operativo,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _DateField(
                            label:
                                'Próxima fecha programada de mantenimiento (opcional)',
                            value: _nextMaintenanceDate,
                            onPick: () => _pickDate(
                              context,
                              _nextMaintenanceDate ?? _maintenanceDate,
                              (d) => _nextMaintenanceDate = d,
                              minDate: _maintenanceDate,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              icon: const Icon(Icons.save),
                              label: const Text('Guardar mantenimiento'),
                              onPressed: () => _save(context, eq),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _FormAppBar();
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
  @override
  Widget build(BuildContext context) {
    return AppBar(title: const Text('Registro de Mantenimiento'));
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null ? 'No definido' : formatDate(value!);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(text),
                ),
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: Text(label)),
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.calendar_today),
              label: Text(text),
            ),
          ],
        );
      },
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 6),
              DropdownButton<String>(
                value: value,
                isExpanded: true,
                items: items
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: onChanged,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: Text(label)),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: value,
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ],
        );
      },
    );
  }
}

class _TextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int maxLines;
  final bool requiredField;
  const _TextField({
    required this.label,
    required this.controller,
    this.maxLines = 1,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) {
        if (requiredField && (v == null || v.trim().isEmpty)) {
          return 'Campo requerido';
        }
        return null;
      },
    );
  }
}
