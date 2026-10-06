// A stand-in for the player's wallet in tests. It behaves like the real one
// (the shared AuthProvider) where it matters: a server balance is applied only
// if its version is at least as new as the last one applied.

import 'package:best_smart_game/services/lucky_card_wallet.dart';

class FakeWallet implements LuckyCardWallet {
  FakeWallet(this._balance);

  int _balance;
  int _version = 0;

  /// Every local balance set, in order.
  final List<int> localSets = [];

  /// Every authoritative balance the provider handed over, with its version.
  final List<({int balance, int version})> synced = [];

  int? Function()? uncommittedGetter;
  bool Function()? spinningGetter;

  @override
  int get balance => _balance;

  @override
  void setLocalBalance(int newBalance) {
    _balance = newBalance;
    localSets.add(newBalance);
  }

  @override
  void syncAuthoritativeBalance(int newBalance, int ledgerVersion) {
    synced.add((balance: newBalance, version: ledgerVersion));
    if (ledgerVersion >= _version) {
      _version = ledgerVersion;
      _balance = newBalance;
    }
  }

  @override
  void setUncommittedStakeGetter(int? Function()? getter) => uncommittedGetter = getter;

  @override
  void setIsSpinningGetter(bool Function()? getter) => spinningGetter = getter;
}
