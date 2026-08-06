/// The signed-in player.
///
/// v2 renames `balance` -> `coin_balance` to match the database column and the
/// dashboard. The old model also carried `agentName`, which was never populated:
/// login emitted camelCase `agentName` while this class read snake_case
/// `agent_name`, so it silently resolved to null on every login. The field is
/// gone rather than left broken — RLS does not let a player read their agent's
/// profile row, so the app cannot obtain it anyway.
class UserModel {
  final String id;
  final String username;

  /// Always 'player' for app sessions. session_login refuses other roles.
  final String role;

  /// Whole coins. The database column is BIGINT with a CHECK that it is never
  /// negative and never fractional, so int is exact here.
  final int coinBalance;

  /// Monotonic counter bumped by the database on every balance change. Used to
  /// discard stale responses; see AuthProvider.updateBalanceWithVersion.
  final int ledgerVersion;

  final bool isActive;
  final String? token;

  const UserModel({
    required this.id,
    required this.username,
    this.role = 'player',
    required this.coinBalance,
    this.ledgerVersion = 0,
    this.isActive = true,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['user_id']?.toString() ?? json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        role: json['role']?.toString() ?? 'player',
        coinBalance: (json['coin_balance'] as num?)?.toInt() ?? 0,
        ledgerVersion: (json['ledger_version'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
        token: json['token']?.toString(),
      );

  UserModel copyWith({
    int? coinBalance,
    int? ledgerVersion,
    String? token,
    bool? isActive,
  }) =>
      UserModel(
        id: id,
        username: username,
        role: role,
        coinBalance: coinBalance ?? this.coinBalance,
        ledgerVersion: ledgerVersion ?? this.ledgerVersion,
        isActive: isActive ?? this.isActive,
        token: token ?? this.token,
      );

  /// Persisted to SharedPreferences. The token is deliberately excluded — it is
  /// stored separately, and duplicating it here meant the raw JWT sat in a
  /// second plaintext key (audit finding S-1).
  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'role': role,
        'coin_balance': coinBalance,
        'ledger_version': ledgerVersion,
        'is_active': isActive,
      };
}
