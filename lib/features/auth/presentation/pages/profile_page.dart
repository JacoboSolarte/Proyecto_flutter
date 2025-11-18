import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/profile_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _organizationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _roleController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  bool _initializedFromProfile = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).value;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
    // Cargar perfil extendido
    Future.microtask(
      () => ref.read(profileControllerProvider.notifier).loadCurrent(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _organizationController.dispose();
    _departmentController.dispose();
    _roleController.dispose();
    _jobTitleController.dispose();
    _documentIdController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);
    final isSaving = authState.isLoading || profileState.isLoading;
    final profile = profileState.value;
    if (!_initializedFromProfile && profile != null) {
      _initializedFromProfile = true;
      _nameController.text = profile.fullName ?? _nameController.text;
      _phoneController.text = profile.phone ?? '';
      _organizationController.text = profile.organization ?? '';
      _departmentController.text = profile.department ?? '';
      _roleController.text = profile.role ?? '';
      _jobTitleController.text = profile.jobTitle ?? '';
      _documentIdController.text = profile.documentId ?? '';
      _addressController.text = profile.address ?? '';
      _bioController.text = profile.bio ?? '';
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: true,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _organizationController,
                decoration: const InputDecoration(labelText: 'Organización'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _departmentController,
                decoration: const InputDecoration(labelText: 'Departamento'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roleController,
                decoration: const InputDecoration(labelText: 'Rol'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _jobTitleController,
                decoration: const InputDecoration(labelText: 'Cargo/Puesto'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _documentIdController,
                decoration: const InputDecoration(
                  labelText: 'Documento de identidad',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Dirección'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio/Notas'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        await ref
                            .read(authControllerProvider.notifier)
                            .updateName(_nameController.text.trim());
                        await ref
                            .read(profileControllerProvider.notifier)
                            .upsertCurrent(
                              fullName: _nameController.text.trim(),
                              phone: _phoneController.text.trim().isEmpty
                                  ? null
                                  : _phoneController.text.trim(),
                              organization:
                                  _organizationController.text.trim().isEmpty
                                  ? null
                                  : _organizationController.text.trim(),
                              department:
                                  _departmentController.text.trim().isEmpty
                                  ? null
                                  : _departmentController.text.trim(),
                              role: _roleController.text.trim().isEmpty
                                  ? null
                                  : _roleController.text.trim(),
                              jobTitle: _jobTitleController.text.trim().isEmpty
                                  ? null
                                  : _jobTitleController.text.trim(),
                              documentId:
                                  _documentIdController.text.trim().isEmpty
                                  ? null
                                  : _documentIdController.text.trim(),
                              address: _addressController.text.trim().isEmpty
                                  ? null
                                  : _addressController.text.trim(),
                              bio: _bioController.text.trim().isEmpty
                                  ? null
                                  : _bioController.text.trim(),
                            );
                        if (mounted) {
                          // ignore: use_build_context_synchronously
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Perfil actualizado')),
                          );
                        }
                      },
                child: isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Guardar cambios'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: authState.isLoading
                    ? null
                    : () async {
                        // Hoist navigator before awaiting
                        // ignore: use_build_context_synchronously
                        final navigator = Navigator.of(context);
                        await ref
                            .read(authControllerProvider.notifier)
                            .signOut();
                        if (mounted) navigator.pop();
                      },
                child: const Text('Cerrar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}