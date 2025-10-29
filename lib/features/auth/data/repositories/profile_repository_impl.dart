import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final SupabaseClient _client;
  static const String table = 'profiles';

  ProfileRepositoryImpl(this._client);

  @override
  Future<UserProfile?> getById(String userId) async {
    final res = await _client.from(table).select('*').eq('id', userId).maybeSingle();
    if (res == null) return null;
    return UserProfile.fromMap(res as Map<String, dynamic>);
  }

  @override
  Future<void> upsert(UserProfile profile) async {
    await _client.from(table).upsert(profile.toUpsertMap());
  }
}