// lib/models/domain/user.dart

// --- UserInDB (Output para GET /auth/me y GET /users/) ---
class UserInDB {
  final String id;
  final String username;
  final bool isActive;
  final int roleId;
  final String roleName;
  final String? companyId;
  final String? branchId;

  UserInDB({
    required this.id,
    required this.username,
    required this.isActive,
    required this.roleId,
    required this.roleName,
    this.companyId,
    this.branchId,
  });

  factory UserInDB.fromJson(Map<String, dynamic> json) {
    return UserInDB(
      id: json['id'] as String,
      username: json['username'] as String,
      isActive: json['is_active'] as bool? ?? true,
      roleId: json['role_id'] as int,
      roleName: json['role_name'] as String,
      companyId: json['company_id'] as String?,
      branchId: json['branch_id'] as String?,
    );
  }
}

// --- UserCreate (Input para POST /users/) ---
class UserCreate {
  final String username;
  final bool isActive;
  final int roleId;
  final String password;
  final String? companyId; // ✅ AÑADIDO: companyId para la creación
  final String? branchId;

  UserCreate({
    required this.username,
    required this.roleId,
    required this.password,
    this.isActive = true,
    this.companyId, // ✅ AÑADIDO: companyId en el constructor
    this.branchId,
  });

  Map<String, dynamic> toJson() => {
    'username': username,
    'is_active': isActive,
    'role_id': roleId,
    'password': password,
    'company_id': companyId,
    'branch_id': branchId,
  };
}

// --- UserUpdate (Input para PATCH /users/{id}) ---
class UserUpdate {
  final String? username;
  final bool? isActive;
  final int? roleId; // ✅ AÑADIDO: roleId para permitir la actualización de rol
  final String?
  companyId; // ✅ AÑADIDO: companyId para permitir la actualización de compañía
  final String? branchId;
  final String? password;

  UserUpdate({
    this.username,
    this.isActive,
    this.roleId, // ✅ AÑADIDO en el constructor
    this.companyId, // ✅ AÑADIDO en el constructor
    this.branchId,
    this.password,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (username != null) data['username'] = username;
    if (isActive != null) data['is_active'] = isActive;
    if (roleId != null) data['role_id'] = roleId; // ✅ AÑADIDO al toJson
    if (companyId != null)
      data['company_id'] = companyId; // ✅ AÑADIDO al toJson
    if (branchId != null) data['branch_id'] = branchId;
    if (password != null) data['password'] = password;
    return data;
  }
}
