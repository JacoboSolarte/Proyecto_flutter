import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final client = Supabase.instance.client;
  return ProfileRepositoryImpl(client);
});

final profileControllerProvider =
    StateNotifierProvider<ProfileController, AsyncValue<UserProfile?>>((ref) {
      final repo = ref.watch(profileRepositoryProvider);
      return ProfileController(repo);
    });

class ProfileController extends StateNotifier<AsyncValue<UserProfile?>> {
  ProfileController(this._repo) : super(const AsyncValue.loading());

  final ProfileRepository _repo;

  Future<void> loadCurrent() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      state = const AsyncValue.data(null);
      return;
    }
    try {
      final profile = await _repo.getById(user.id);
      if (profile == null) {
        final nameMeta = user.userMetadata?['name']?.toString();
        state = AsyncValue.data(UserProfile(id: user.id, fullName: nameMeta));
      } else {
        state = AsyncValue.data(profile);
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> upsertCurrent({
    String? fullName,
    String? phone,
    String? organization,
    String? department,
    String? role,
    String? jobTitle,
    String? documentId,
    String? address,
    String? avatarUrl,
    String? bio,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      state = const AsyncValue.loading();
      final existing = await _repo.getById(user.id);
      final updated = UserProfile(
        id: user.id,
        fullName: fullName ?? existing?.fullName,
        phone: phone ?? existing?.phone,
        organization: organization ?? existing?.organization,
        department: department ?? existing?.department,
        role: role ?? existing?.role,
        jobTitle: jobTitle ?? existing?.jobTitle,
        documentId: documentId ?? existing?.documentId,
        address: address ?? existing?.address,
        avatarUrl: avatarUrl ?? existing?.avatarUrl,
        bio: bio ?? existing?.bio,
      );
      await _repo.upsert(updated);
      state = AsyncValue.data(updated);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
