// The server refuses a print player's normal bet with P0155. All four games must
// recognise it, never retry it, and say why.
import 'package:best_smart_game/models/lucky16_models.dart';
import 'package:best_smart_game/models/lucky_card_models.dart';
import 'package:best_smart_game/models/spin2win_models.dart';
import 'package:best_smart_game/providers/lucky16_provider.dart';
import 'package:best_smart_game/providers/lucky_card_provider.dart';
import 'package:best_smart_game/providers/spin2win_provider.dart';
import 'package:best_smart_game/services/api_contract.dart';
import 'package:best_smart_game/services/lucky16_api_service.dart';
import 'package:best_smart_game/services/lucky_card_api_service.dart';
import 'package:best_smart_game/services/round_api_service.dart';
import 'package:best_smart_game/services/spin2win_api_service.dart';
import 'package:best_smart_game/widgets/lucky16/lucky16_messages.dart';
import 'package:best_smart_game/widgets/lucky_card/lucky_card_messages.dart';
import 'package:best_smart_game/widgets/spin2win/spin2win_messages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _refusal = PostgrestException(message: 'PRINT_REQUIRED', code: 'P0155');
const _title = 'USE THE DESKTOP APP';
const _message = 'Your account plays with printed tickets. Please open BSG on your Windows computer.';

void main() {
  test('Triple Chance', () {
    expect(RoundApiService.mapError(_refusal), BetError.printRequired);
  });

  test('Lucky 16', () {
    final error = Lucky16ApiService.mapError(_refusal);
    expect(error, Lucky16Error.printRequired);
    expect(error.isRetryable, isFalse);
    final dialog = lucky16ProblemDialog(const Lucky16Problem(Lucky16ProblemKind.betRejected, Lucky16Error.printRequired));
    expect(dialog.title, _title);
    expect(dialog.message, _message);
  });

  test('Lucky Card', () {
    final error = LuckyCardApiService.mapError(_refusal);
    expect(error, LuckyCardError.printRequired);
    expect(error.isRetryable, isFalse);
    final dialog = luckyCardProblemDialog(const LuckyCardProblem(LuckyCardProblemKind.betRejected, LuckyCardError.printRequired));
    expect(dialog.title, _title);
    expect(dialog.message, _message);
  });

  test('Spin2Win', () {
    final error = Spin2WinApiService.mapError(_refusal);
    expect(error, Spin2WinError.printRequired);
    expect(error.isRetryable, isFalse);
    final dialog = spin2WinProblemDialog(const Spin2WinProblem(Spin2WinProblemKind.betRejected, Spin2WinError.printRequired));
    expect(dialog.title, _title);
    expect(dialog.message, _message);
  });
}
