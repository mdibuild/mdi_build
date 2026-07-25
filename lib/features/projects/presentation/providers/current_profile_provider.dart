import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/app_user.dart';
import '../../../../core/services/supabase_service.dart';

final currentProfileProvider = FutureProvider<AppUser?>((ref) async {
  final authUser = SupabaseService.client.auth.currentUser;
  if (authUser == null) {
    debugPrint('CURRENT PROFILE: aucun utilisateur connecté');
    return null;
  }

  debugPrint('CURRENT PROFILE AUTH ID = ${authUser.id}');
  debugPrint('CURRENT PROFILE AUTH EMAIL = ${authUser.email}');

  final row = await SupabaseService.client
      .from('profiles')
      .select('id, company_id, full_name, email, role')
      .eq('id', authUser.id)
      .maybeSingle();

  if (row == null) {
    debugPrint(
        'CURRENT PROFILE: aucune ligne trouvée dans profiles pour ${authUser.id}');
    return null;
  }

  debugPrint('CURRENT PROFILE ROW = $row');

  return AppUser.fromMap(row);
});
