import '../entities/image_analysis.dart';
import '../repositories/image_analysis_repository.dart';

class ListImageAnalysesForUserUseCase {
  final ImageAnalysisRepository _repo;
  ListImageAnalysesForUserUseCase(this._repo);

  Future<List<ImageAnalysis>> call(String userId, {int limit = 20}) {
    return _repo.listByUser(userId, limit: limit);
  }
}
