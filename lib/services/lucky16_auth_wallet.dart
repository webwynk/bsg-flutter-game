// The real wallet of the Lucky 16 Card screen: a thin wrapper that calls the shared
// AuthProvider's PUBLIC balance methods exactly as they are. It adds no behaviour and
// changes nothing in AuthProvider (Lucky Card spec §17AC; shared-object permission per RULE #21:
// call only).
//
//   balance                          -> AuthProvider.coinBalance
//   setLocalBalance                  -> AuthProvider.updateBalance
//   syncAuthoritativeBalance         -> AuthProvider.syncAuthoritativeBalance (which itself
//                                       ignores a confirmation older than what it holds)
//   setUncommittedStakeGetter        -> AuthProvider.setUncommittedStakeGetter
//   setIsSpinningGetter              -> AuthProvider.setIsSpinningGetter
//
// Copied from lib/services/lucky_card_auth_wallet.dart (Lucky Card); only the
// names changed. Belongs to Lucky 16 Card only.

import '../providers/auth_provider.dart';
import 'lucky16_wallet.dart';

class AuthLucky16Wallet implements Lucky16Wallet {
  const AuthLucky16Wallet(this._auth);

  final AuthProvider _auth;

  @override
  int get balance => _auth.coinBalance;

  @override
  void setLocalBalance(int newBalance) => _auth.updateBalance(newBalance);

  @override
  void syncAuthoritativeBalance(int newBalance, int ledgerVersion) =>
      _auth.syncAuthoritativeBalance(newBalance, ledgerVersion);

  @override
  void setUncommittedStakeGetter(int? Function()? getter) => _auth.setUncommittedStakeGetter(getter);

  @override
  void setIsSpinningGetter(bool Function()? getter) => _auth.setIsSpinningGetter(getter);
}
