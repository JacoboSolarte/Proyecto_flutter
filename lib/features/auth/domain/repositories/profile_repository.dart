import '../entities/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile?> getById(String userId);
  Future<void> upsert(UserProfile profile);
}