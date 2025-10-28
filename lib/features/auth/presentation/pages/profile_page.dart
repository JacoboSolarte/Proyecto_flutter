import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/auth_providers.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).value;
    _nameController.text = user?.name ?? '';
    _emailController.text = user?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de usuario')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: authState.isLoading
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).updateName(_nameController.text.trim());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
                      }
                    },
              child: authState.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar cambios'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: authState.isLoading
                  ? null
                  : () async {
                      await ref.read(authControllerProvider.notifier).signOut();
                      if (mounted) Navigator.pop(context);
                    },
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}