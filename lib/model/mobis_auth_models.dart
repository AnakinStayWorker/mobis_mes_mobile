class TokenResponse {
  final String accessToken;
  final String refreshToken;

  const TokenResponse({required this.accessToken, required this.refreshToken});

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
    accessToken: (json['accessToken'] ?? '') as String,
    refreshToken: (json['refreshToken'] ?? '') as String,
  );
}

class UserProfile {
  final String userId;
  final String? userName;
  final String? email;
  final String? department;
  final String? departmentName;
  final String userType;
  final bool isActive;

  const UserProfile({
    required this.userId,
    required this.userType,
    required this.isActive,
    this.userName,
    this.email,
    this.department,
    this.departmentName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    userId: (json['userId'] ?? '') as String,
    userName: json['userName'] as String?,
    email: json['email'] as String?,
    department: json['department'] as String?,
    departmentName: json['departmentName'] as String?,
    userType: (json['userType'] ?? 'User') as String,
    isActive: (json['isActive'] ?? false) as bool,
  );
}

/// 호출 성공 시 token & user가 채워지고, 실패 시 error가 채워짐
class MobisLoginResult {
  final TokenResponse? token;
  final UserProfile? user;
  final String? error;

  const MobisLoginResult({this.token, this.user, this.error});

  bool get isSuccess => error == null && token != null && user != null;
}
