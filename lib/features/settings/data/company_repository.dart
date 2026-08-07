import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/company.dart';
import '../../../core/services/supabase_service.dart';

class CompanyRepository {
  CompanyRepository({
    SupabaseClient? client,
    String storageBucket = 'company-logos',
  })  : _client = client ?? SupabaseService.client,
        _storageBucket = storageBucket;

  final SupabaseClient _client;
  final String _storageBucket;

  Future<Company> fetchCompany(String companyId) async {
    final row = await _client
        .from('companies')
        .select()
        .eq('id', companyId)
        .single();

    return Company.fromMap(row);
  }

  Future<Company> updateCompany(Company company) async {
    final row = await _client
        .from('companies')
        .update(company.toUpdateMap())
        .eq('id', company.id)
        .select()
        .single();

    return Company.fromMap(row);
  }

  Future<String> uploadLogo({
    required String companyId,
    required Uint8List bytes,
    required String contentType,
    required String fileExtension,
  }) async {
    final path = 'logos/$companyId.$fileExtension';

    await _client.storage.from(_storageBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: true,
          ),
        );

    return path;
  }

  String publicLogoUrl(String logoPath) {
    return _client.storage.from(_storageBucket).getPublicUrl(logoPath);
  }
}
