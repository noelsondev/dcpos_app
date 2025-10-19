// /lib/data_sources/local_platform_data_source.dart

import 'package:isar/isar.dart';
import 'package:dcpos_app/isar_service.dart';
import 'package:dcpos_app/models/local/platform_local.dart';

class LocalPlatformDataSource {
  final IsarService _isarService;

  LocalPlatformDataSource(this._isarService);

  // ==========================================================
  // Compañías (CompanyLocal)
  // ==========================================================

  Future<List<CompanyLocal>> getAllCompanies() async {
    final isar = await _isarService.db;
    return isar.companyLocals.where().findAll();
  }

  Future<void> saveCompanies(List<CompanyLocal> companies) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.companyLocals.putAll(companies);
    });
  }

  // ==========================================================
  // Sucursales (BranchLocal)
  // ==========================================================

  Future<List<BranchLocal>> getBranchesByCompanyId(String companyId) async {
    final isar = await _isarService.db;
    return isar.branchLocals.filter().companyIdEqualTo(companyId).findAll();
  }

  Future<void> saveBranches(List<BranchLocal> branches) async {
    final isar = await _isarService.db;
    await isar.writeTxn(() async {
      await isar.branchLocals.putAll(branches);
    });
  }
}
