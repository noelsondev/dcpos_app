// /lib/models/domain/branch_update.dart

/// Data Transfer Object (DTO) para actualizar un recurso Branch.
/// Los campos son opcionales (nullable) para permitir la actualización parcial (PATCH).
class BranchUpdate {
  final String? name;
  final String? address;
  final bool? isActive;

  BranchUpdate({this.name, this.address, this.isActive});

  /// Serializa solo los campos no nulos a un Map (para Dio/API).
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) {
      data['name'] = name;
    }
    if (address != null) {
      data['address'] = address;
    }
    if (isActive != null) {
      // Usamos el nombre de la clave de la API
      data['is_active'] = isActive;
    }
    return data;
  }
}
