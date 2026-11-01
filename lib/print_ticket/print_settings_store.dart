import 'dart:convert';
import 'dart:io';

import 'ticket_model.dart';

/// The printer and paper chosen on this computer.
class PrintSettingsStore {
  /// The settings file; replaced in tests.
  final File file;

  PrintSettingsStore({File? file})
      : file = file ?? File('${Platform.environment['APPDATA'] ?? '.'}\\BSG\\print_settings.json');

  Future<Map<String, dynamic>> _read() async {
    try {
      return Map<String, dynamic>.from(jsonDecode(await file.readAsString()) as Map);
    } catch (_) {
      return const {};
    }
  }

  Future<String?> printer() async => (await _read())['printer'] as String?;

  Future<TicketPaper> paper() async {
    final saved = (await _read())['paper'];
    return TicketPaper.values.firstWhere((p) => p.name == saved, orElse: () => TicketPaper.mm80);
  }

  Future<void> save(String printer, TicketPaper paper) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({'printer': printer, 'paper': paper.name}));
  }
}
