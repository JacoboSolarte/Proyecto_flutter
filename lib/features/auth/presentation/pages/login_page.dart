import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_providers.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import '../widgets/auth_layout.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;
    return AuthLayout(
      title: 'Iniciar sesión',
      subtitle: 'Accede para gestionar tus equipos biomédicos.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                  );
                },
                child: const Text('Olvidé mi contraseña'),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (_formKey.currentState?.validate() ?? false) {
                        try {
                          await ref
                              .read(authControllerProvider.notifier)
                              .signIn(
                                _emailController.text.trim(),
                                _passwordController.text.trim(),
                              );
                          if (mounted) {
                            Navigator.of(context).pop();
                          }
                        } catch (_) {}
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entrar'),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¿No tienes cuenta? '),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RegisterPage()),
                    );
                  },
                  child: const Text('Regístrate'),
                ),
              ],
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
    );
  }
}
