import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/equipment_repository_impl.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/repositories/equipment_repository.dart';
import '../../domain/usecases/create_equipment.dart';
import '../../domain/usecases/delete_equipment.dart';
import '../../domain/usecases/get_equipments.dart';
import '../../domain/usecases/get_equipment_detail.dart';
import '../../domain/usecases/update_equipment.dart';
import '../../domain/entities/equipment.dart';
import '../../constants/status.dart';

class EquipmentSummary {
  final int total;
  final int operativo;
  final int mantenimiento;
  final int fueraServicio;
  final int seguimiento;

  const EquipmentSummary({
    required this.total,
    required this.operativo,
    required this.mantenimiento,
    required this.fueraServicio,
    required this.seguimiento,
  });
}

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EquipmentRepositoryImpl(client);
});

class EquipmentListController extends StateNotifier<AsyncValue<List<Equipment>>> {
  EquipmentListController(this._get) : super(const AsyncValue.loading());

  final GetEquipmentsUseCase _get;

  static const int pageSize = 20;
  int _offset = 0;
  bool _hasMore = true;
  EquipmentQuery? _query;

  Future<void> loadInitial({EquipmentQuery? query}) async {
    _query = query;
    _offset = 0;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final items = await _get(limit: pageSize, offset: _offset, query: _query);
      _offset += items.length;
      _hasMore = items.length == pageSize;
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadNext() async {
    if (!_hasMore) return;
    final current = state.value ?? [];
    try {
      final items = await _get(limit: pageSize, offset: _offset, query: _query);
      _offset += items.length;
      _hasMore = items.length == pageSize;
      state = AsyncValue.data([...current, ...items]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // Optimiza la experiencia al reflejar cambios locales inmediatamente tras editar
  void replaceItem(Equipment updated) {
    final current = state.value;
    if (current == null) return;
    final idx = current.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    final newList = List<Equipment>.from(current);
    newList[idx] = updated;
    state = AsyncValue.data(newList);
  }
}

final equipmentListControllerProvider = StateNotifierProvider<EquipmentListController, AsyncValue<List<Equipment>>>((ref) {
  final repo = ref.watch(equipmentRepositoryProvider);
  return EquipmentListController(GetEquipmentsUseCase(repo));
});

final equipmentDetailProvider = FutureProvider.family<Equipment, String>((ref, id) {
  final repo = ref.watch(equipmentRepositoryProvider);
  return GetEquipmentDetailUseCase(repo)(id);
});

final createEquipmentUseCaseProvider = Provider<CreateEquipmentUseCase>((ref) {
  final repo = ref.watch(equipmentRepositoryProvider);
  return CreateEquipmentUseCase(repo);
});
final updateEquipmentUseCaseProvider = Provider<UpdateEquipmentUseCase>((ref) {
  final repo = ref.watch(equipmentRepositoryProvider);
  return UpdateEquipmentUseCase(repo);
});
final deleteEquipmentUseCaseProvider = Provider<DeleteEquipmentUseCase>((ref) {
  final repo = ref.watch(equipmentRepositoryProvider);
  return DeleteEquipmentUseCase(repo);
});

/// Resumen independiente del filtro actual: calcula métricas sobre el conjunto completo
final equipmentSummaryProvider = FutureProvider<EquipmentSummary>((ref) async {
  final repo = ref.watch(equipmentRepositoryProvider);
  // Cargar un conjunto amplio; si el dataset crece, conviene agregar un endpoint de conteo
  final all = await repo.list(limit: 10000, offset: 0);
  int operativo = 0, mantenimiento = 0, fuera = 0, seguimiento = 0;
  for (final e in all) {
    switch (e.status) {
      case EquipmentStatus.operativo:
        operativo++;
        break;
      case EquipmentStatus.mantenimiento:
        mantenimiento++;
        break;
      case EquipmentStatus.fueraDeServicio:
        fuera++;
        break;
      case EquipmentStatus.requiereSeguimiento:
        seguimiento++;
        break;
    }
  }
  return EquipmentSummary(
    total: all.length,
    operativo: operativo,
    mantenimiento: mantenimiento,
    fueraServicio: fuera,
    seguimiento: seguimiento,
  );
});