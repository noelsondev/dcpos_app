// dcpos_app/lib/pages/users_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dcpos_app/providers/app_state_provider.dart';
import 'package:dcpos_app/models/domain/user.dart';
import 'package:dcpos_app/models/domain/platform.dart';

class UsersPage extends StatelessWidget {
  const UsersPage({super.key});

  // Muestra el modal unificado para CREAR o EDITAR
  void _showUserFormDialog(BuildContext context, {UserInDB? userToEdit}) {
    showDialog(
      context: context,
      builder: (ctx) => UserFormDialog(userToEdit: userToEdit),
    );
  }

  // Lógica para alternar el estado (activar/desactivar)
  Future<void> _toggleUserActive(BuildContext context, UserInDB user) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final newState = !user.isActive;

    final confirmation = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newState ? 'Activar Usuario' : 'Desactivar Usuario'),
        content: Text(
          '¿Está seguro que desea ${newState ? 'activar' : 'desactivar'} a ${user.username}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              newState ? 'Activar' : 'Desactivar',
              style: TextStyle(color: newState ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmation == true) {
      try {
        final updateData = UserUpdate(isActive: newState);
        await appState.updateUser(user.id, updateData);
        await appState.fetchUsers();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Usuario ${user.username} ${newState ? 'activado' : 'desactivado'} correctamente.',
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cambiar el estado: $e')),
          );
        }
      }
    }
  }

  // -------------------------------------------------------------------
  // Widget Build (Estructura de la Página)
  // -------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppStateProvider>(context);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Botón de Acción (Crear Usuario)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gestión de Usuarios',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              ElevatedButton.icon(
                onPressed: () => _showUserFormDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('CREAR USUARIO'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),

          // 2. Estado de Carga / Error
          if (appState.isUsersLoading)
            const Center(child: CircularProgressIndicator())
          else if (appState.usersError != null)
            Center(
              child: Column(
                children: [
                  Text(
                    appState.usersError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: appState.fetchUsers,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            )
          else
            // 3. Lista de Usuarios
            Expanded(
              child: ListView.builder(
                itemCount: appState.users.length,
                itemBuilder: (context, index) {
                  final user = appState.users[index];
                  return _UserListTile(
                    user: user,
                    onEdit: () =>
                        _showUserFormDialog(context, userToEdit: user),
                    onToggleActive: () => _toggleUserActive(context, user),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------
// WIDGET AUXILIAR: List Tile de Usuario
// -------------------------------------------------------------------
class _UserListTile extends StatelessWidget {
  final UserInDB user;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _UserListTile({
    required this.user,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListTile(
        leading: CircleAvatar(child: Text(user.username[0].toUpperCase())),
        title: Text(
          user.username,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Rol: ${user.roleName}'),
            Text('Compañía: ${user.companyId ?? 'N/A'}'),
            if (user.branchId != null) Text('Sucursal: ${user.branchId}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Botón de Modificar (Editar)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
              tooltip: 'Modificar Usuario',
            ),
            // Botón de Suprimir/Activar (Toggle)
            IconButton(
              icon: Icon(
                user.isActive ? Icons.toggle_on : Icons.toggle_off,
                color: user.isActive ? Colors.green : Colors.red,
              ),
              onPressed: onToggleActive,
              tooltip: user.isActive ? 'Desactivar Usuario' : 'Activar Usuario',
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------
// WIDGET AUXILIAR: Modal de Creación/Edición (CORREGIDO)
// -------------------------------------------------------------------
class UserFormDialog extends StatefulWidget {
  final UserInDB? userToEdit;
  const UserFormDialog({super.key, this.userToEdit});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;

  String? _selectedRole;
  String? _selectedCompanyId;
  String? _selectedBranchId;

  List<CompanyInDB> _availableCompanies = [];
  List<BranchInDB> _availableBranches = [];

  bool _isCompaniesLoading = true;
  bool _isBranchesLoading = true;
  String? _companiesError;
  String? _branchesError;

  // Lista de roles de ejemplo y su mapeo a ID
  final Map<String, int> _roleMap = {
    'global_admin': 1,
    'company_admin': 2,
    'cashier': 3,
    'accountant': 4,
  };
  List<String> get _mockRoles => _roleMap.keys.toList();

  int _mapRoleNameToId(String roleName) {
    return _roleMap[roleName] ?? 99;
  }

  @override
  void initState() {
    super.initState();
    final user = widget.userToEdit;

    _usernameController = TextEditingController(text: user?.username);
    _passwordController = TextEditingController();
    _selectedRole = user?.roleName;
    _selectedCompanyId = user?.companyId;
    _selectedBranchId = user?.branchId;

    // Iniciar la carga de compañías. La carga de sucursales se encadena dentro
    _loadAvailableCompanies();
  }

  // Carga y filtra las compañías según el rol logueado
  Future<void> _loadAvailableCompanies() async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final currentUserRole = appState.currentUserRoleName;
    final currentUserCompanyId = appState.currentUserCompanyId;

    setState(() {
      _isCompaniesLoading = true;
      _companiesError = null;
      _availableCompanies = []; // Limpiar antes de cargar
    });

    try {
      // 🛑 CORRECCIÓN: Forzar la carga de compañías si la lista del provider está vacía.
      if (appState.companies.isEmpty) {
        await appState.fetchCompanies();
      }

      // La lista de compañías cargada está en appState.companies

      if (currentUserRole == 'global_admin') {
        _availableCompanies = appState.companies;
      } else if (currentUserRole == 'company_admin' &&
          currentUserCompanyId != null) {
        // Un company_admin solo puede ver su propia compañía.
        final selfCompany = appState.companies.firstWhere(
          (c) => c.id == currentUserCompanyId,
          orElse: () => throw Exception('Compañía propia no encontrada.'),
        );
        _availableCompanies = [selfCompany];

        if (widget.userToEdit == null || _selectedCompanyId == null) {
          // Asignar automáticamente la compañía si se está creando o si no tenía una asignada
          _selectedCompanyId = currentUserCompanyId;
        }
      } else {
        _availableCompanies = [];
      }

      // Si hay una compañía seleccionada al inicio, la usamos para cargar las sucursales.
      if (_selectedCompanyId != null) {
        await _loadAvailableBranches(_selectedCompanyId!);
      } else {
        setState(() {
          _isBranchesLoading = false;
        });
      }
    } catch (e) {
      _companiesError = 'Error al cargar compañías: ${e.toString()}';
    } finally {
      setState(() {
        _isCompaniesLoading = false;
      });
    }
  }

  // FUNCIÓN MODIFICADA: Resuelve el problema del Dropdown al validar el ID
  Future<void> _loadAvailableBranches(String companyId) async {
    final appState = Provider.of<AppStateProvider>(context, listen: false);

    setState(() {
      _isBranchesLoading = true;
      _branchesError = null;
      _availableBranches = [];
    });

    try {
      // Llamamos a fetchBranches con el companyId requerido
      final branches = await appState.fetchBranches(companyId);

      // Asignamos la lista de sucursales devueltas.
      _availableBranches = branches;

      // CORRECCIÓN CLAVE: Si el ID de sucursal del usuario (al editar) no está
      // en la lista recién cargada, lo establecemos a null.
      if (_selectedBranchId != null &&
          !_availableBranches.any((b) => b.id == _selectedBranchId)) {
        // El ID guardado ya no es válido para esta compañía, lo limpiamos.
        _selectedBranchId = null;
      }
    } catch (e) {
      _branchesError = 'Error al cargar sucursales: ${e.toString()}';
    } finally {
      setState(() {
        _isBranchesLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe seleccionar un Rol.')),
        );
      }
      return;
    }

    final isCashier = _selectedRole == 'cashier';
    if (isCashier && _selectedBranchId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El rol Cashier requiere una sucursal asignada.'),
          ),
        );
      }
      return;
    }

    if (_selectedRole != 'global_admin' && _selectedCompanyId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Debe asignar una compañía a un usuario que no es global_admin.',
            ),
          ),
        );
      }
      return;
    }

    final appState = Provider.of<AppStateProvider>(context, listen: false);
    final int roleId = _mapRoleNameToId(_selectedRole!);

    // Definición final de IDs a enviar
    final companyIdToSubmit = _selectedRole == 'global_admin'
        ? null
        : _selectedCompanyId;
    final branchIdToSubmit = isCashier ? _selectedBranchId : null;

    try {
      if (widget.userToEdit == null) {
        // --- CREAR USUARIO ---
        final newUser = UserCreate(
          username: _usernameController.text,
          password: _passwordController.text,
          roleId: roleId,
          companyId: companyIdToSubmit,
          branchId: branchIdToSubmit,
        );
        await appState.createUser(newUser);
      } else {
        // --- EDITAR USUARIO ---
        final updateData = UserUpdate(
          password: _passwordController.text.isNotEmpty
              ? _passwordController.text
              : null,
          roleId: roleId,
          companyId: companyIdToSubmit,
          branchId: branchIdToSubmit,
        );
        await appState.updateUser(widget.userToEdit!.id, updateData);
      }

      await appState.fetchUsers();

      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Usuario ${_usernameController.text} ${widget.userToEdit == null ? 'creado' : 'actualizado'} con éxito.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar usuario: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCreating = widget.userToEdit == null;
    final appState = Provider.of<AppStateProvider>(context);
    final currentUserRole = appState.currentUserRoleName;

    final bool isCompanySelectionEditable = currentUserRole == 'global_admin';
    final bool isRoleSelectionEditable = currentUserRole == 'global_admin';
    final bool isBranchSelectionVisible = _selectedRole != 'global_admin';
    final bool isBranchSelectionRequired = _selectedRole == 'cashier';

    // Se calcula el nombre de la compañía seleccionada para el modo no editable
    final String? currentCompanyName =
        !isCompanySelectionEditable &&
            _selectedCompanyId != null &&
            _availableCompanies.isNotEmpty
        ? _availableCompanies
              .firstWhere(
                (c) => c.id == _selectedCompanyId,
                orElse: () =>
                    _availableCompanies.first, // Fallback si no lo encuentra
              )
              .name
        : null;

    // -------------------------------------------------------------------
    // Widget: Selector Dinámico de Compañía
    // -------------------------------------------------------------------
    Widget companySelector;
    if (_isCompaniesLoading) {
      companySelector = const Center(child: LinearProgressIndicator());
    } else if (_companiesError != null) {
      companySelector = Text(
        _companiesError!,
        style: const TextStyle(color: Colors.red),
      );
    } else if (!isCompanySelectionEditable && currentCompanyName != null) {
      // Caso Company Admin o rol inferior: Mostrar solo el nombre de la compañía
      companySelector = TextFormField(
        decoration: const InputDecoration(labelText: 'Compañía'),
        initialValue: currentCompanyName,
        enabled: false,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      );
    } else {
      // Caso Global Admin: Dropdown con las opciones disponibles (todas)
      companySelector = DropdownButtonFormField<String>(
        // *** CORRECCIÓN DE DROP-DOWN ***
        // Si no hay compañías disponibles, el valor debe ser null.
        value: _availableCompanies.isEmpty ? null : _selectedCompanyId,
        // ******************************
        decoration: const InputDecoration(labelText: 'Compañía'),
        isExpanded: true,
        items: [
          // Item para Global Admin
          if (currentUserRole == 'global_admin')
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Global (Sin Compañía)'),
            ),

          // Items de Compañías
          ..._availableCompanies.map((company) {
            return DropdownMenuItem<String>(
              value: company.id,
              child: Text(company.name),
            );
          }).toList(),
        ],
        onChanged: (value) {
          setState(() {
            _selectedCompanyId = value;
            _selectedBranchId = null;
            // CARGAR SUCURSALES usando el ID de la compañía
            if (value != null) {
              _loadAvailableBranches(value);
            } else {
              _isBranchesLoading = false;
              _availableBranches = [];
            }
          });
        },
        validator: (v) {
          if (_selectedRole != 'global_admin' && v == null) {
            return 'Seleccione una compañía.';
          }
          return null;
        },
      );
    }
    // -------------------------------------------------------------------

    // -------------------------------------------------------------------
    // Selector de Sucursal
    // -------------------------------------------------------------------
    Widget branchSelector = Container();

    if (isBranchSelectionVisible && _selectedCompanyId != null) {
      if (_isBranchesLoading) {
        branchSelector = const Center(child: LinearProgressIndicator());
      } else if (_branchesError != null) {
        branchSelector = Text(
          _branchesError!,
          style: const TextStyle(color: Colors.red),
        );
      } else if (_availableBranches.isEmpty) {
        branchSelector = const Text(
          'No hay sucursales disponibles para esta compañía.',
          style: TextStyle(color: Colors.orange),
        );
      } else {
        // DropdownButtonFormField de Sucursal
        branchSelector = DropdownButtonFormField<String>(
          // _selectedBranchId es validado en _loadAvailableBranches para no causar el error
          value: _selectedBranchId,
          decoration: const InputDecoration(labelText: 'Sucursal'),
          isExpanded: true,
          items: [
            // Opcional: Permitir null/ninguna sucursal (si no es Cashier)
            if (!isBranchSelectionRequired)
              const DropdownMenuItem<String>(
                value: null,
                child: Text('(Ninguna/Opcional)'),
              ),

            ..._availableBranches.map((branch) {
              return DropdownMenuItem<String>(
                value: branch.id,
                child: Text(branch.name),
              );
            }).toList(),
          ],
          onChanged: (value) {
            setState(() {
              _selectedBranchId = value;
            });
          },
          validator: (v) {
            if (isBranchSelectionRequired && v == null) {
              return 'Debe seleccionar una sucursal para este rol.';
            }
            return null;
          },
        );
      }
    }
    // -------------------------------------------------------------------

    return AlertDialog(
      title: Text(
        isCreating
            ? 'Crear Nuevo Usuario'
            : 'Editar Usuario: ${widget.userToEdit!.username}',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de Usuario',
                  ),
                  enabled: isCreating,
                  validator: (v) => v!.isEmpty
                      ? 'El nombre de usuario es obligatorio.'
                      : null,
                ),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: isCreating
                        ? 'Contraseña'
                        : 'Nueva Contraseña (Dejar vacío para mantener)',
                  ),
                  obscureText: true,
                  validator: (v) {
                    if (isCreating && v!.isEmpty) {
                      return 'La contraseña es obligatoria para nuevos usuarios.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Selector de Rol
                DropdownButtonFormField<String>(
                  value: _selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Rol',
                    enabled: isRoleSelectionEditable,
                  ),
                  items: _mockRoles.map((role) {
                    return DropdownMenuItem(value: role, child: Text(role));
                  }).toList(),
                  onChanged: isRoleSelectionEditable
                      ? (value) {
                          setState(() {
                            _selectedRole = value;

                            // Lógica de compañía al cambiar el rol:
                            if (value == 'global_admin') {
                              _selectedCompanyId = null;
                              _selectedBranchId = null;
                            } else if (value != 'global_admin' &&
                                currentUserRole != 'global_admin') {
                              _selectedCompanyId =
                                  appState.currentUserCompanyId;
                            }

                            // Si hay una compañía seleccionada, recargar las sucursales.
                            if (_selectedCompanyId != null) {
                              _loadAvailableBranches(_selectedCompanyId!);
                            } else {
                              // Si no hay compañía, limpiar la lista de sucursales.
                              _isBranchesLoading = false;
                              _availableBranches = [];
                              _selectedBranchId = null;
                            }
                          });
                        }
                      : null,
                  validator: (v) => v == null ? 'Seleccione un rol.' : null,
                ),
                const SizedBox(height: 15),

                // Selector Dinámico de Compañía
                companySelector,

                // Selector Dinámico de Sucursal (Solo si no es Global Admin)
                if (isBranchSelectionVisible &&
                    branchSelector is! Container) ...[
                  const SizedBox(height: 15),
                  branchSelector,
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: Text(isCreating ? 'Crear' : 'Guardar Cambios'),
        ),
      ],
    );
  }
}
