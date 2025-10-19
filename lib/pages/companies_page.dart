// dcpos_app/lib/pages/companies_page.dart (CORREGIDO)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dcpos_app/providers/app_state_provider.dart';
import 'package:dcpos_app/models/domain/platform.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});

  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompaniesPageState extends State<CompaniesPage> {
  // ID de la compañía seleccionada para ver sus ramas
  String? _selectedCompanyId;
  // Bandera para asegurar que la inicialización solo ocurre una vez
  bool _initialLoadDone = false;

  @override
  void initState() {
    super.initState();
    // Iniciar la carga de compañías al entrar a la página
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).fetchCompanies();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final appState = Provider.of<AppStateProvider>(context);

    // Si el usuario es company_admin, forzar la selección a su propia compañía
    final isCompanyAdmin = appState.currentUserRoleName == 'company_admin';
    final userCompanyId = appState.currentUserCompanyId;

    if (isCompanyAdmin &&
        userCompanyId != null &&
        _selectedCompanyId != userCompanyId) {
      // 1. Si es Company Admin, su compañía es la única seleccionable/visible
      _selectedCompanyId = userCompanyId;
      _initialLoadDone = true;
      appState.fetchBranches(userCompanyId);
    } else if (!_initialLoadDone &&
        !appState.isCompaniesLoading &&
        appState.companies.isNotEmpty) {
      // 2. Si es Global Admin, seleccionar la primera compañía disponible
      _selectedCompanyId = appState.companies.first.id;
      _initialLoadDone = true;
      appState.fetchBranches(_selectedCompanyId!);
    }

    // Si la lista de compañías se vacía (ej: error de carga), reseteamos.
    if (appState.companies.isEmpty) {
      _selectedCompanyId = null;
      _initialLoadDone = false;
    }
  }

  // Nuevo método para manejar la lógica de selección y carga de sucursales
  void _selectCompany(String companyId, AppStateProvider appState) {
    // Si el usuario es company_admin, no debería poder seleccionar otra compañía
    final isCompanyAdmin = appState.currentUserRoleName == 'company_admin';
    final userCompanyId = appState.currentUserCompanyId;

    if (isCompanyAdmin && companyId != userCompanyId) return;

    if (_selectedCompanyId != companyId) {
      setState(() {
        _selectedCompanyId = companyId;
      });
      // Cargar las sucursales de la compañía seleccionada
      appState.fetchBranches(companyId);
    }
  }

  // ====================================================================
  // Métodos de Diálogo
  // ====================================================================

  void _showCreateCompanyDialog(
    BuildContext context,
    AppStateProvider appState,
  ) {
    if (appState.currentUserRoleName != 'global_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Acceso denegado. Solo Global Admin puede crear compañías.',
          ),
        ),
      );
      return;
    }
    // Llama a la función de diálogo definida al final del archivo
    _showCompanyFormDialog(context, appState);
  }

  void _showCreateBranchDialog(
    BuildContext context,
    AppStateProvider appState,
    String companyId,
  ) {
    // 🛑 RESTRICCIÓN DE ROL PARA CREAR SUCURSAL
    if (appState.currentUserRoleName != 'global_admin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Acceso denegado. Solo Global Admin puede crear sucursales.',
          ),
        ),
      );
      return;
    }
    // Llama a la función de diálogo definida al final del archivo
    _showBranchFormDialog(context, appState, companyId);
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    // El layout principal divide la vista entre la lista de compañías y la gestión de sucursales
    return Row(
      children: [
        // Columna 1: Lista de Compañías (CRUD Company)
        Expanded(
          flex: 2,
          child: _CompaniesListWidget(
            selectedCompanyId: _selectedCompanyId,
            onSelectCompany: (companyId) => _selectCompany(companyId, appState),
            onCreateCompany: () => _showCreateCompanyDialog(context, appState),
          ),
        ),

        // Columna 2: Sucursales de la Compañía Seleccionada (CRUD Branch)
        const VerticalDivider(width: 1),
        Expanded(
          flex: 3,
          child: _BranchesWidget(
            selectedCompanyId: _selectedCompanyId,
            onCreateBranch:
                _showCreateBranchDialog, // Pasar la función con restricción
          ),
        ),
      ],
    );
  }
}

// ====================================================================
// WIDGET 1: Lista de Compañías
// ====================================================================

class _CompaniesListWidget extends StatelessWidget {
  final String? selectedCompanyId;
  final Function(String) onSelectCompany;
  final VoidCallback onCreateCompany;

  const _CompaniesListWidget({
    required this.selectedCompanyId,
    required this.onSelectCompany,
    required this.onCreateCompany,
  });

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);
    final canCreateCompany = appState.currentUserRoleName == 'global_admin';
    final isCompanyAdmin = appState.currentUserRoleName == 'company_admin';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compañías (${appState.companies.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              // 🛑 RESTRICCIÓN: SOLO GLOBAL ADMIN PUEDE VER EL BOTÓN CREAR
              if (canCreateCompany)
                ElevatedButton.icon(
                  onPressed: onCreateCompany,
                  icon: const Icon(Icons.add_business),
                  label: const Text('Crear Compañía'),
                ),
            ],
          ),
        ),
        if (appState.isCompaniesLoading)
          const LinearProgressIndicator()
        else if (appState.companiesError != null)
          _ErrorState(
            error: appState.companiesError!,
            onRetry: appState.fetchCompanies,
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: appState.companies.length,
              itemBuilder: (context, index) {
                final company = appState.companies[index];

                // Si es company_admin, solo mostrar su compañía
                if (isCompanyAdmin &&
                    company.id != appState.currentUserCompanyId) {
                  return const SizedBox.shrink();
                }

                return Card(
                  color: company.id == selectedCompanyId
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : null,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: ListTile(
                    title: Text(company.name),
                    subtitle: Text('Slug: ${company.slug}'),
                    selected: company.id == selectedCompanyId,
                    onTap: () => onSelectCompany(company.id),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ====================================================================
// WIDGET 2: Lista de Sucursales
// ====================================================================

class _BranchesWidget extends StatelessWidget {
  final String? selectedCompanyId;
  final void Function(BuildContext, AppStateProvider, String) onCreateBranch;

  const _BranchesWidget({
    required this.selectedCompanyId,
    required this.onCreateBranch,
  });

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    // 🛑 RESTRICCIÓN: SOLO GLOBAL ADMIN PUEDE CREAR/GESTIONAR SUCURSALES (como se solicitó)
    final canCreateBranch = appState.currentUserRoleName == 'global_admin';

    if (selectedCompanyId == null || appState.companies.isEmpty) {
      return const Center(
        child: Text('Seleccione una compañía para ver sus sucursales.'),
      );
    }

    final selectedCompany = appState.companies.firstWhere(
      (c) => c.id == selectedCompanyId,
      orElse: () => CompanyInDB(
        id: '0',
        name: 'N/A',
        slug: 'n/a',
        createdAt: DateTime.now(),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sucursales de: ${selectedCompany.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              // 🛑 RESTRICCIÓN: SOLO GLOBAL ADMIN PUEDE VER EL BOTÓN CREAR
              if (canCreateBranch)
                ElevatedButton.icon(
                  onPressed: () =>
                      onCreateBranch(context, appState, selectedCompanyId!),
                  icon: const Icon(Icons.add_location),
                  label: const Text('Crear Sucursal'),
                ),
            ],
          ),
        ),
        if (appState.isBranchesLoading)
          const LinearProgressIndicator()
        else if (appState.branchesError != null)
          _ErrorState(
            error: appState.branchesError!,
            onRetry: () => appState.fetchBranches(selectedCompanyId!),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: appState.currentCompanyBranches.length,
              itemBuilder: (context, index) {
                final branch = appState.currentCompanyBranches[index];
                return ListTile(
                  title: Text(branch.name),
                  subtitle: Text(branch.address ?? 'Sin dirección'),
                  trailing: const Icon(Icons.edit),
                  onTap: () {
                    // TODO: Implementar edición de sucursal (también restringida a global_admin)
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

// ====================================================================
// MÓDALES DE CREACIÓN (Con Restricción de Rol en el Submit)
// ====================================================================

// Función auxiliar para el diálogo de Compañía
void _showCompanyFormDialog(BuildContext context, AppStateProvider appState) {
  final nameController = TextEditingController();
  final slugController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Crear Nueva Compañía'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Compañía',
              ),
              validator: (v) => v!.isEmpty ? 'El nombre es obligatorio' : null,
            ),
            TextFormField(
              controller: slugController,
              decoration: const InputDecoration(
                labelText: 'Slug (Identificador URL)',
              ),
              validator: (v) => v!.isEmpty ? 'El slug es obligatorio' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            // 🛑 RESTRICCIÓN DE ROL EN EL SUBMIT
            if (appState.currentUserRoleName != 'global_admin') {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Acceso denegado.')),
                );
                Navigator.pop(ctx);
              }
              return;
            }

            if (formKey.currentState!.validate()) {
              try {
                final companyCreate = CompanyCreate(
                  name: nameController.text,
                  slug: slugController.text,
                );
                await appState.createCompany(companyCreate);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al crear compañía: ${e.toString().split(':').last.trim()}',
                      ),
                    ),
                  );
                }
              }
            }
          },
          child: const Text('Crear'),
        ),
      ],
    ),
  );
}

// Función auxiliar para el diálogo de Sucursal
void _showBranchFormDialog(
  BuildContext context,
  AppStateProvider appState,
  String companyId,
) {
  final nameController = TextEditingController();
  final addressController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Crear Nueva Sucursal'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre de la Sucursal',
              ),
              validator: (v) => v!.isEmpty ? 'El nombre es obligatorio' : null,
            ),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección (Opcional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            // 🛑 RESTRICCIÓN DE ROL EN EL SUBMIT
            if (appState.currentUserRoleName != 'global_admin') {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Acceso denegado.')),
                );
                Navigator.pop(ctx);
              }
              return;
            }

            if (formKey.currentState!.validate()) {
              try {
                final branchCreate = BranchCreate(
                  name: nameController.text,
                  address: addressController.text.isNotEmpty
                      ? addressController.text
                      : null,
                );
                await appState.createBranch(companyId, branchCreate);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error al crear sucursal: ${e.toString().split(':').last.trim()}',
                      ),
                    ),
                  );
                }
              }
            }
          },
          child: const Text('Crear'),
        ),
      ],
    ),
  );
}

// Widget auxiliar para mostrar errores
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Error: ${error.split(':').last.trim()}',
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Reintentar Carga'),
          ),
        ],
      ),
    );
  }
}
