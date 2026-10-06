// Tests for lib/services/lucky_card_auth_wallet.dart: each wallet call reaches the right
// public method of the shared AuthProvider, with the same values, and does nothing else.
// A stand-in with the same public methods is used because the real AuthProvider cannot be
// built without a Supabase connection.

import 'package:best_smart_game/providers/auth_provider.dart';
import 'package:best_smart_game/services/lucky_card_auth_wallet.dart';
import 'package:best_smart_game/services/lucky_card_wallet.dart';
import 'package:flutter_test/flutter_test.dart';

class StandInAuth extends Fake implements AuthProvider {
  int balance = 1000;
  final List<String> calls = [];
  int? Function()? stakeGetter;
  bool Function()? spinningGetter;

  @override
  int get coinBalance => balance;

  @override
  void updateBalance(int newBalance) {
    calls.add('updateBalance $newBalance');
    balance = newBalance;
  }

  @override
  void syncAuthoritativeBalance(int newBalance, int version) {
    calls.add('syncAuthoritativeBalance $newBalance $version');
    balance = newBalance;
  }

  @override
  void setUncommittedStakeGetter(int? Function()? getter) {
    calls.add('stakeGetter ${getter == null ? 'cleared' : 'set'}');
    stakeGetter = getter;
  }

  @override
  void setIsSpinningGetter(bool Function()? getter) {
    calls.add('spinningGetter ${getter == null ? 'cleared' : 'set'}');
    spinningGetter = getter;
  }
}

void main() {
  test('it is a LuckyCardWallet', () {
    expect(AuthLuckyCardWallet(StandInAuth()), isA<LuckyCardWallet>());
  });

  test('the balance is the shared balance, read fresh each time', () {
    final auth = StandInAuth();
    final wallet = AuthLuckyCardWallet(auth);
    expect(wallet.balance, 1000);
    auth.balance = 742;
    expect(wallet.balance, 742);
  });

  test('a local change goes to updateBalance, and only that', () {
    final auth = StandInAuth();
    AuthLuckyCardWallet(auth).setLocalBalance(970);
    expect(auth.calls, ['updateBalance 970']);
    expect(auth.balance, 970);
  });

  test('a server balance goes to syncAuthoritativeBalance with its version in the right order', () {
    final auth = StandInAuth();
    AuthLuckyCardWallet(auth).syncAuthoritativeBalance(1280, 57);
    expect(auth.calls, ['syncAuthoritativeBalance 1280 57']);
    expect(auth.balance, 1280);
  });

  test('the two getters are handed over as they are, and can be taken away', () {
    final auth = StandInAuth();
    final wallet = AuthLuckyCardWallet(auth);
    wallet.setUncommittedStakeGetter(() => 120);
    wallet.setIsSpinningGetter(() => true);
    expect(auth.stakeGetter!(), 120);
    expect(auth.spinningGetter!(), isTrue);
    wallet.setUncommittedStakeGetter(null);
    wallet.setIsSpinningGetter(null);
    expect(auth.stakeGetter, isNull);
    expect(auth.spinningGetter, isNull);
    expect(auth.calls, ['stakeGetter set', 'spinningGetter set', 'stakeGetter cleared', 'spinningGetter cleared']);
  });

  test('nothing is called when the wallet is only created or read', () {
    final auth = StandInAuth();
    final wallet = AuthLuckyCardWallet(auth);
    wallet.balance;
    expect(auth.calls, isEmpty);
  });
}
