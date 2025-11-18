import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/image_analysis.dart';
import '../../domain/repositories/image_analysis_repository.dart';

class ImageAnalysisRepositoryImpl implements ImageAnalysisRepository {
  final SupabaseClient _client;
  static const String table = 'image_analyses';

  ImageAnalysisRepositoryImpl(this._client);

  @override
  Future<ImageAnalysis> create(
    ImageAnalysis analysis, {
    required String userId,
  }) async {
    final inserted = await _client
        .from(table)
        .insert(analysis.toInsertMap(userId))
        .select()
        .single();
    return ImageAnalysis.fromMap(inserted);
  }

  @override
  Future<List<ImageAnalysis>> listByUser(
    String userId, {
    int limit = 20,
  }) async {
    final data = await _client
        .from(table)
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    final list = (data as List)
        .map((e) => ImageAnalysis.fromMap(e as Map<String, dynamic>))
        .toList();
    return list;
  }
}
