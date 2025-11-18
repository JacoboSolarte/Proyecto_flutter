import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnalysisResultPage extends StatelessWidget {
  final String source;
  final String? model;
  final Map<String, String> fields;
  final String? rawText;

  const AnalysisResultPage({
    super.key,
    required this.source,
    required this.fields,
    this.model,
    this.rawText,
  });

  @override
  Widget build(BuildContext context) {
    final description = (fields['notes'] ?? '').trim();
    // Mostrar únicamente el párrafo de respuesta (notes). Si está vacío, mostrar mensaje genérico.
    final contentText = description.isNotEmpty
        ? description
        : 'Sin descripción disponible';

    return Scaffold(
      appBar: AppBar(title: const Text('Resultados de IA')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: Text('Fuente: $source'),
                  // Ocultamos el modelo para no exponer detalles del proveedor/implementación.
                  // Antes: mostraba "Modelo: <model>" si estaba definido.
                  subtitle: null,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Respuesta',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        contentText,
                        style: const TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy),
                          label: const Text('Copiar'),
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: contentText),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Respuesta copiada'),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}