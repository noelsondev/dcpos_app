// dcpos_app/lib/models/user.dart

class User {
  final String username;
  final String email;
  final String roleName;
  final String companyId; // Usamos String para flexibilidad
  final bool isActive;
  // Añade más campos (e.g., full_name, user_id) si tu API los devuelve

  User({
    required this.username,
    required this.email,
    required this.roleName,
    required this.companyId,
    required this.isActive,
  });

  // Constructor de fábrica para crear una instancia a partir de un mapa JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] as String,
      email: json['email'] as String,
      roleName: json['role_name'] as String,
      // Manejar el company_id: debe ser convertido a String
      companyId: json['company_id']?.toString() ?? 'N/A',
      isActive: json['is_active'] as bool,
    );
  }

  // Opcional: Para facilitar la depuración
  @override
  String toString() {
    return 'User{username: $username, roleName: $roleName, isActive: $isActive}';
  }
}
