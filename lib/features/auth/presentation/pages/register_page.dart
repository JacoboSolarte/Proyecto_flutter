import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_providers.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Nombre obligatorio';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
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
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Contraseña obligatoria';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (_formKey.currentState?.validate() ?? false) {
                            try {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .signUp(
                                    _emailController.text.trim(),
                                    _passwordController.text.trim(),
                                    _nameController.text.trim(),
                                  );
                              if (mounted) Navigator.pop(context);
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
        ),
      ),
    );
  }
}