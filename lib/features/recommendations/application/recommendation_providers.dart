import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result/result.dart';
import '../../../data/repositories/recommendation_repository.dart';
import '../../../data/repositories/rule_based_recommendation_repository.dart';
import '../../catalog/application/catalog_providers.dart';
import '../../library/application/library_providers.dart';
import '../domain/recommendation_rail.dart';

final recommendationRepositoryProvider =
    Provider<RecommendationRepository>((ref) {
  return RuleBasedRecommendationRepository(
    catalog: ref.watch(catalogRepositoryProvider),
    library: ref.watch(libraryRepositoryProvider),
  );
});

/// Home rails. Failures degrade to no rails — Home never blocks on the
/// catalog being reachable.
final homeRailsProvider =
    FutureProvider.autoDispose<List<RecommendationRail>>((ref) async {
  final result =
      await ref.watch(recommendationRepositoryProvider).getHomeRecommendationRails();
  return switch (result) {
    Ok(value: final rails) => rails,
    Err() => const <RecommendationRail>[],
  };
});
