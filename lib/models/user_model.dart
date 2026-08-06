class UserModel {
  final String id;
  final String username;
  final String role;
  final int balance;
  final String? agentId;
  final String? agentName;
  final bool isActive;
  final String? token;
  final String? refreshToken;

  const UserModel({
    required this.id,
    required this.username,
    this.role = 'user',
    required this.balance,
    this.agentId,
    this.agentName,
    this.isActive = true,
    this.token,
    this.refreshToken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id:           json['id']?.toString() ?? '',
    username:     json['username']?.toString() ?? '',
    role:         json['role']?.toString() ?? 'user',
    balance:      (json['balance'] as num?)?.toInt() ?? 0,
    agentId:      json['agent_id']?.toString(),
    agentName:    json['agent_name']?.toString(),
    isActive:     json['is_active'] as bool? ?? true,
    token:        json['token']?.toString(),
    refreshToken: json['refresh_token']?.toString(),
  );

  UserModel copyWith({int? balance, String? token, String? refreshToken, bool? isActive}) => UserModel(
    id:           id,
    username:     username,
    role:         role,
    balance:      balance ?? this.balance,
    agentId:      agentId,
    agentName:    agentName,
    isActive:     isActive ?? this.isActive,
    token:        token ?? this.token,
    refreshToken: refreshToken ?? this.refreshToken,
  );

  Map<String, dynamic> toJson() => {
    'id':            id,
    'username':      username,
    'role':          role,
    'balance':       balance,
    'agent_id':      agentId,
    'agent_name':    agentName,
    'is_active':     isActive,
    'token':         token,
    'refresh_token': refreshToken,
  };
}
