import '../entities/image_analysis.dart';
import '../repositories/image_analysis_repository.dart';

class CreateImageAnalysisUseCase {
  final ImageAnalysisRepository _repo;
  CreateImageAnalysisUseCase(this._repo);

  Future<ImageAnalysis> call(ImageAnalysis analysis, {required String userId}) {
    return _repo.create(analysis, userId: userId);
  }
}