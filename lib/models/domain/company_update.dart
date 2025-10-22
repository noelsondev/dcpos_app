// /lib/models/domain/company_update.dart

/// Data Transfer Object (DTO) para actualizar un recurso Company.
/// Los campos son opcionales para permitir actualizaciones parciales (PATCH).
class CompanyUpdate {
  final String? name;
  final String? slug;
  final bool? isActive;

  CompanyUpdate({this.name, this.slug, this.isActive});

  /// Serializa solo los campos no nulos a un Map (para Dio/API).
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (name != null) {
      data['name'] = name;
    }
    if (slug != null) {
      data['slug'] = slug;
    }
    if (isActive != null) {
      data['is_active'] = isActive;
    }
    return data;
  }
}
