import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mdi_build/core/providers/module_refresh_provider.dart';

import '../../../../core/models/project_quote.dart';
import '../../../../core/models/quote_line_item.dart';
import '../../data/devis_repository.dart';

final devisRepositoryProvider = Provider<DevisRepository>((ref) {
  return DevisRepository();
});

final projectQuotesProvider =
    FutureProvider.family<List<ProjectQuote>, String>((ref, projectId) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(devisRepositoryProvider).fetchQuotesByProject(projectId);
});

final quoteItemsProvider =
    FutureProvider.family<List<QuoteLineItem>, String>((ref, quoteId) async {
  ref.watch(moduleRefreshRevisionProvider);
  return ref.read(devisRepositoryProvider).fetchQuoteItems(quoteId);
});
