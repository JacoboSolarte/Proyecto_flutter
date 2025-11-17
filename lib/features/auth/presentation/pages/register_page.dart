import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_providers.dart';
import '../../presentation/providers/profile_providers.dart';
import '../widgets/auth_layout.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _organizationController = TextEditingController();
  final _departmentController = TextEditingController();
  final _roleController = TextEditingController();
  final _jobTitleController = TextEditingController();
  final _documentIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
    final isLoading = authState.isLoading;
    return AuthLayout(
      title: 'Crear cuenta',
      subtitle: 'Regístrate para comenzar a gestionar tus equipos.',
      primaryBackground: true,
      // ignore: sort_child_properties_last
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Nombre obligatorio';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email obligatorio';
                if (!v.contains('@')) return 'Email inválido';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Contraseña obligatoria';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _organizationController,
              decoration: const InputDecoration(
                labelText: 'Organización (opcional)',
                prefixIcon: Icon(Icons.business_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _departmentController,
              decoration: const InputDecoration(
                labelText: 'Departamento (opcional)',
                prefixIcon: Icon(Icons.apartment_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _roleController,
              decoration: const InputDecoration(
                labelText: 'Rol (opcional)',
                prefixIcon: Icon(Icons.security_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _jobTitleController,
              decoration: const InputDecoration(
                labelText: 'Cargo/Puesto (opcional)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _documentIdController,
              decoration: const InputDecoration(
                labelText: 'Documento de identidad (opcional)',
                prefixIcon: Icon(Icons.credit_card_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Dirección (opcional)',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Bio/Notas (opcional)',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        // Hoist navigator to avoid using context after await
                        // ignore: use_build_context_synchronously
                        final navigator = Navigator.of(context);
                        try {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signUp(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                                _nameController.text.trim(),
                              );
                          // Guardar perfil extendido
                          await ref.read(profileControllerProvider.notifier).upsertCurrent(
                                fullName: _nameController.text.trim(),
                                phone: _phoneController.text.trim().isEmpty
                                    ? null
                                    : _phoneController.text.trim(),
                                organization: _organizationController.text.trim().isEmpty
                                    ? null
                                    : _organizationController.text.trim(),
                                department: _departmentController.text.trim().isEmpty
                                    ? null
                                    : _departmentController.text.trim(),
                                role: _roleController.text.trim().isEmpty ? null : _roleController.text.trim(),
                                jobTitle:
                                    _jobTitleController.text.trim().isEmpty ? null : _jobTitleController.text.trim(),
                                documentId: _documentIdController.text.trim().isEmpty
                                    ? null
                                    : _documentIdController.text.trim(),
                                address: _addressController.text.trim().isEmpty
                                    ? null
                                    : _addressController.text.trim(),
                                bio: _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
                              );
                          if (mounted) navigator.pop();
                        } catch (_) {}
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Registrarse'),
            ),
            if (authState.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Error: ${authState.toString()}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
      bottomActions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('Al registrarte aceptas nuestros términos y políticas.'),
          ],
        ),
      ],
    );
  }
}
