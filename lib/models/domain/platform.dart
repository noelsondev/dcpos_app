// lib/models/domain/platform.dart

// --- CompanyInDB (Output) ---
class CompanyInDB {
  final String id;
  final String name;
  final String slug;
  final DateTime createdAt;

  CompanyInDB({
    required this.id,
    required this.name,
    required this.slug,
    required this.createdAt,
  });

  factory CompanyInDB.fromJson(Map<String, dynamic> json) {
    return CompanyInDB(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// --- CompanyCreate (Input) ---
class CompanyCreate {
  final String name;
  final String slug;

  CompanyCreate({required this.name, required this.slug});

  Map<String, dynamic> toJson() => {'name': name, 'slug': slug};
}

// --- BranchInDB (Output) ---
class BranchInDB {
  final String id;
  final String companyId;
  final String name;
  final String? address;

  BranchInDB({
    required this.id,
    required this.companyId,
    required this.name,
    this.address,
  });

  factory BranchInDB.fromJson(Map<String, dynamic> json) {
    return BranchInDB(
      id: json['id'] as String,
      companyId: json['company_id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
    );
  }
}

// --- BranchCreate (Input) ---
class BranchCreate {
  final String name;
  final String? address;

  BranchCreate({required this.name, this.address});

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {'name': name};
    if (address != null) data['address'] = address;
    return data;
  }
}
