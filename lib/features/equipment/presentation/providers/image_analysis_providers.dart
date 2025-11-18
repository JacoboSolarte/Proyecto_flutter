import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/image_analysis_repository_impl.dart';
import '../../domain/entities/image_analysis.dart';
import '../../domain/repositories/image_analysis_repository.dart';
import '../../domain/usecases/create_image_analysis.dart';
import '../../domain/usecases/list_image_analyses_for_user.dart';
import 'equipment_providers.dart' show supabaseClientProvider; // reuse client

final imageAnalysisRepositoryProvider = Provider<ImageAnalysisRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return ImageAnalysisRepositoryImpl(client);
});

final createImageAnalysisUseCaseProvider = Provider<CreateImageAnalysisUseCase>(
  (ref) {
    final repo = ref.watch(imageAnalysisRepositoryProvider);
    return CreateImageAnalysisUseCase(repo);
  },
);

final listImageAnalysesForUserUseCaseProvider =
    Provider<ListImageAnalysesForUserUseCase>((ref) {
      final repo = ref.watch(imageAnalysisRepositoryProvider);
      return ListImageAnalysesForUserUseCase(repo);
    });

final imageAnalysesByUserProvider = FutureProvider.autoDispose
    .family<List<ImageAnalysis>, String>((ref, userId) {
      final uc = ref.watch(listImageAnalysesForUserUseCaseProvider);
      return uc(userId, limit: 20);
    });