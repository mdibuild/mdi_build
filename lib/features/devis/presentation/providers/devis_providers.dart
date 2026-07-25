import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project_quote.dart';
import '../../data/devis_repository.dart';

final devisRepositoryProvider = Provider<DevisRepository>((ref) {
  return DevisRepository();
});

final currentProjectQuoteProvider =
    FutureProvider.family<ProjectQuote?, String>((ref, projectId) async {
  return ref.read(devisRepositoryProvider).fetchQuoteByProject(projectId);
});
