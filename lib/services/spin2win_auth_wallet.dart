// The real wallet of the Spin2Win screen: a thin wrapper that calls the shared
// AuthProvider's PUBLIC balance methods exactly as they are. It adds no behaviour and
// changes nothing in AuthProvider (the same call-only use as Lucky Card's wallet;
// RULE #21: shared objects are called, never edited).
//
//   balance                          -> AuthProvider.coinBalance
//   setLocalBalance                  -> AuthProvider.updateBalance
//   syncAuthoritativeBalance         -> AuthProvider.syncAuthoritativeBalance (which itself
//                                       ignores a confirmation older than what it holds)
//   setUncommittedStakeGetter        -> AuthProvider.setUncommittedStakeGetter
//   setIsSpinningGetter              -> AuthProvider.setIsSpinningGetter
//
// Belongs to Spin2Win only.

import '../providers/auth_provider.dart';
import 'spin2win_wallet.dart';

class AuthSpin2WinWallet implements Spin2WinWallet {
  const AuthSpin2WinWallet(this._auth);

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
