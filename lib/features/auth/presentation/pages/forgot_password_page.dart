import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../constants/auth_constants.dart';
import '../widgets/auth_layout.dart';
import '../providers/auth_providers.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isLoading =
        authState.isLoading; // usamos para deshabilitar si hay otra operación
    return AuthLayout(
      title: 'Recuperar contraseña',
      subtitle: 'Te enviaremos un enlace para restablecerla.',
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
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!(_formKey.currentState?.validate() ?? false)) return;
                      try {
                        final email = _emailController.text.trim();
                        // Usar URL fija desde .env si está definida; si no, origin actual
                        final fixed = dotenv.env['RESET_REDIRECT_URL'];
                        final redirect =
                            fixed ??
                            '${Uri.base.origin}${AuthConstants.defaultResetPath}';
                        // Hoist messenger/navigator to avoid using context after await
                        // ignore: use_build_context_synchronously
                        final messenger = ScaffoldMessenger.of(context);
                        // ignore: use_build_context_synchronously
                        final navigator = Navigator.of(context);
                        await ref
                            .read(authControllerProvider.notifier)
                            .sendPasswordResetEmail(
                              email,
                              redirectTo: redirect,
                            );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Revisa tu correo para continuar'),
                          ),
                        );
                        navigator.pop();
                      } catch (e) {
                        if (!mounted) return;
                        // ignore: use_build_context_synchronously
                        final messenger = ScaffoldMessenger.of(context);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    },
              child: const Text('Enviar instrucciones'),
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
