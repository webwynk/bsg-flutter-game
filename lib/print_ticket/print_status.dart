import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/desktop_window.dart';

/// True when this account uses Print and this device is not the Windows app, so
/// it must be sent to the desktop app. A failed read says false: this only
/// explains the block, and the server refuses the bet either way. Reads the
/// player's own row; RLS allows nothing else.
Future<bool> printRequiresDesktop() async {
  if (isWindowsApp) return false;
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return false;
    final row = await client.from('print_players').select('enabled').eq('user_id', userId).maybeSingle();
    return row?['enabled'] == true;
  } catch (e) {
    debugPrint('printRequiresDesktop: $e');
    return false;
  }
}
