import 'package:flutter/material.dart';

class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget>? bottomActions;
  final bool primaryBackground;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottomActions,
    this.primaryBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: primaryBackground ? scheme.primary : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 600;
            final content = Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: primaryBackground ? scheme.onPrimary : null,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: textTheme.bodyMedium?.copyWith(
                          color: primaryBackground
                              ? scheme.onPrimary.withValues(alpha: 0.85)
                              : scheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Diseño minimalista sin imagen/ilustración, centrado
                      const SizedBox(height: 8),
                      Card(
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: child,
                        ),
                      ),
                      if (bottomActions != null) ...[
                        const SizedBox(height: 16),
                        ...bottomActions!,
                      ],
                    ],
                  ),
                ),
              ),
            );
            // En escritorio mantén el contenido centrado sin columna lateral
            if (isWide) {
              return Center(child: content);
            }
            return content;
          },
        ),
      ),
    );
  }
}
