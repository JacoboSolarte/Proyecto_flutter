import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/repositories/equipment_repository.dart';
import '../widgets/equipment_card.dart';
import 'dart:async';
import '../providers/equipment_providers.dart';
import 'equipment_form_page.dart';
import 'equipment_detail_page.dart';
import '../../../auth/presentation/pages/profile_page.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  int _currentIndex = 0;
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
              ],
            ),
          ),
          Expanded(
            child: state.when(
              loading: () => _buildLoadingList(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (_) => items.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.separated(
                      controller: _scrollController,
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
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
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: Row(
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
                    tooltip: 'Refrescar',
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      _triggerSearch();
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
            Container(height: 16, width: 160, decoration: BoxDecoration(color: scheme.surfaceVariant, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(height: 12, width: double.infinity, decoration: BoxDecoration(color: scheme.surfaceVariant, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(height: 12, width: 220, decoration: BoxDecoration(color: scheme.surfaceVariant, borderRadius: BorderRadius.circular(4))),
          ],
        ),
      ),
    );
  }
}