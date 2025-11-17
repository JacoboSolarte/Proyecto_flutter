import 'package:flutter/material.dart';
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
import '../providers/maintenance_providers.dart';
import '../widgets/image_analyzer_sheet.dart';
import '../widgets/summary_bar.dart';
import '../widgets/status_filter_bar.dart';
import '../widgets/skeleton_card.dart';
import '../widgets/empty_state.dart';
import '../../constants/status.dart';

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
    final countOperativo = items.where((e) => e.status == EquipmentStatus.operativo).length;
    final countMantenimiento = items.where((e) => e.status == EquipmentStatus.mantenimiento).length;
    final countFueraServicio = items.where((e) => e.status == EquipmentStatus.fueraDeServicio).length;
    final countSeguimiento = items.where((e) => e.status == EquipmentStatus.requiereSeguimiento).length;
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
                        final created = await Navigator.of(context)
                            .push<Equipment?>(
                              MaterialPageRoute(
                                builder: (_) => const EquipmentFormPage(),
                              ),
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
