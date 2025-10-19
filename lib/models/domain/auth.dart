// lib/models/domain/auth.dart

// --- UserLogin (Input para POST /auth/login) ---
class UserLogin {
  final String username;
  final String password;

  UserLogin({required this.username, required this.password});

  Map<String, dynamic> toJson() => {'username': username, 'password': password};
}

// --- Token (Output de POST /auth/login) ---
class Token {
  final String accessToken;
  final String tokenType;
  final String role; // El rol se devuelve en la respuesta del token

  Token({
    required this.accessToken,
    required this.tokenType,
    required this.role,
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
      role: json['role'] as String,
    );
  }
}
