import '../entities/image_analysis.dart';

abstract class ImageAnalysisRepository {
  Future<ImageAnalysis> create(ImageAnalysis analysis, {required String userId});
  Future<List<ImageAnalysis>> listByUser(String userId, {int limit = 20});
}