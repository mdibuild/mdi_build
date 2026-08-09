import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/project_quote.dart';
import '../../../../core/models/quote_line_item.dart';
import '../../data/devis_repository.dart';

final devisRepositoryProvider = Provider<DevisRepository>((ref) {
  return DevisRepository();
});

final projectQuotesProvider =
    FutureProvider.family<List<ProjectQuote>, String>((ref, projectId) async {
  return ref.read(devisRepositoryProvider).fetchQuotesByProject(projectId);
});

final quoteItemsProvider =
    FutureProvider.family<List<QuoteLineItem>, String>((ref, quoteId) async {
  return ref.read(devisRepositoryProvider).fetchQuoteItems(quoteId);
});
