// The player's coin balance, as the Lucky Card provider needs to use it.
//
// The balance itself belongs to the whole app and is held by the shared
// AuthProvider. Lucky Card reaches it only through this small interface, so the
// betting logic can be tested with a fake wallet and never needs a signed-in
// user, and so the few calls it makes on the shared balance are all listed in
// one place. The real implementation, a thin wrapper that calls AuthProvider's
// public balance methods without changing them, is added with the screen.
//
// Belongs to Lucky Card only.

abstract class LuckyCardWallet {
  /// The balance as the screen shows it. It is ahead of the database while chips
  /// sit on the board: they are subtracted here the moment they are placed, but
  /// nothing reaches the database until the bet is sent at the lock mark.
  int get balance;

  /// Sets the balance for a purely local change, such as placing or removing a
  /// chip, which the server has not seen.
  void setLocalBalance(int newBalance);

  /// Applies a balance the server has just confirmed, together with its version
  /// counter. A confirmation older than what has already been applied must be
  /// ignored by the implementation (the real one does, through AuthProvider).
  void syncAuthoritativeBalance(int newBalance, int ledgerVersion);

  /// Tells the background balance check how many coins are sitting unsent on the
  /// board, so it does not overwrite the on-screen balance with a higher server
  /// figure. Pass null to remove it.
  void setUncommittedStakeGetter(int? Function()? getter);

  /// Tells the background balance check whether a result is being revealed, so
  /// it does not apply a balance ahead of the staged reveal. Pass null to remove
  /// it.
  void setIsSpinningGetter(bool Function()? getter);
}
