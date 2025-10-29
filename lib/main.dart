import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/supabase_config.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/auth/presentation/pages/welcome_page.dart';
import 'features/equipment/presentation/pages/equipment_list_page.dart';
import 'features/auth/presentation/pages/reset_password_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    return MaterialApp(
      title: 'Biomedic',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0.5,
          centerTitle: true,
          titleTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: colorScheme.surface,
          shadowColor: colorScheme.shadow,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
        chipTheme: ChipThemeData(
          selectedColor: colorScheme.primaryContainer,
          backgroundColor: colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.inverseSurface,
          contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        ),
      ),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _handledUrl = false;
  bool _forceRecovery = false;

  @override
  void initState() {
    super.initState();
    _processAuthUrlIfNeeded();
  }

  void _processAuthUrlIfNeeded() {
    final uri = Uri.base;
    final hasCode = uri.queryParameters.containsKey('code');
    final hasAccessTokenInFragment = uri.fragment.contains('access_token');
    final isRecoveryType = uri.queryParameters['type'] == 'recovery' || uri.fragment.contains('type=recovery');
    // Si la URL de retorno trae ?code, tokens en el fragmento o type=recovery, pedimos a Supabase que la procese.
    if (!_handledUrl && (hasCode || hasAccessTokenInFragment || isRecoveryType)) {
      _handledUrl = true;
      Future.microtask(() async {
        try {
          // Intento genérico: que Supabase detecte sesión desde la URL
          await Supabase.instance.client.auth.getSessionFromUrl(uri);
          setState(() {
            _forceRecovery = true;
          });
          // Emitirá signedIn y/o passwordRecovery según el tipo de enlace.
        } catch (_) {
          // Fallback para ?code si la detección genérica falla (p.ej. PKCE).
          if (hasCode) {
            try {
              final code = uri.queryParameters['code']!;
              await Supabase.instance.client.auth.exchangeCodeForSession(code);
              setState(() {
                _forceRecovery = true;
              });
            } catch (_) {
              // Ignoramos errores aquí; el flujo normal seguirá mostrando Welcome/Login.
            }
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final authState = snapshot.data;
        // En Flutter Web, Supabase coloca los parámetros en el fragmento (#) o en query
        // Ejemplos: #access_token=...&type=recovery o ?type=recovery
        final uri = Uri.base;
        final frag = uri.fragment;
        final fragParams = frag.isNotEmpty ? Uri.splitQueryString(frag) : <String, String>{};
        final isRecoveryFromUrl = frag.contains('type=recovery') ||
            fragParams['type'] == 'recovery' ||
            uri.queryParameters['type'] == 'recovery';
        // Permitir rutas dedicadas, por ejemplo /reset o #/reset
        final isResetPath = uri.pathSegments.contains('reset') ||
            uri.pathSegments.contains('reset-password') ||
            frag.contains('/reset') ||
            frag.contains('reset-password');
        if (_forceRecovery || authState?.event == AuthChangeEvent.passwordRecovery || isRecoveryFromUrl || isResetPath) {
          return const ResetPasswordPage();
        }
        final session = authState?.session ?? Supabase.instance.client.auth.currentSession;
        if (session != null) {
          return const EquipmentListPage();
        }
        return const WelcomePage();
      },
    );
  }
}
