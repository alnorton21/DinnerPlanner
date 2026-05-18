import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/update_password_screen.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  runApp(const MyApp());
}

ThemeData _buildTheme(ColorScheme cs) {
  final radius12 = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
  );
  final radius12Focus = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: cs.primary, width: 2),
  );
  final radius12Variant = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: cs.outlineVariant),
  );

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,

    // ── AppBar ──────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      backgroundColor: cs.surface,
      foregroundColor: cs.onSurface,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: cs.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        color: cs.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: cs.onSurface, size: 22),
    ),

    // ── Cards ───────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),

    // ── Input fields ────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.45),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: radius12,
      enabledBorder: radius12Variant,
      focusedBorder: radius12Focus,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.error, width: 2),
      ),
      floatingLabelStyle: TextStyle(
          color: cs.primary, fontWeight: FontWeight.w600, fontSize: 13),
      labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
      hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.45)),
      isDense: true,
    ),

    // ── Buttons ─────────────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 44),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: cs.outline.withValues(alpha: 0.6)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    // ── Chips ───────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),

    // ── FAB ─────────────────────────────────────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
    ),

    // ── Divider ─────────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: cs.outlineVariant.withValues(alpha: 0.5),
      thickness: 1,
      space: 1,
    ),

    // ── ListTile ────────────────────────────────────────────────────────────
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),

    // ── BottomSheet ─────────────────────────────────────────────────────────
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: cs.surface,
      elevation: 4,
    ),

    // ── SnackBar ────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) {
        final lightCs = ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        );
        final darkCs = ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
        );
        return MaterialApp(
          title: 'Dinner Planner',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: _buildTheme(lightCs),
          darkTheme: _buildTheme(darkCs),
          home: const AuthGate(),
        );
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isPasswordRecovery = false;

  @override
  void initState() {
    super.initState();

    // If the user is already logged in from a previous session, load their
    // dark mode preference immediately — the signedIn event won't re-fire
    // for a restored session.
    if (Supabase.instance.client.auth.currentUser != null) {
      _loadDarkModePreference();
    }

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        setState(() => _isPasswordRecovery = true);
      } else if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.initialSession) {
        setState(() => _isPasswordRecovery = false);
        _loadDarkModePreference();
      } else if (data.event == AuthChangeEvent.signedOut) {
        setState(() => _isPasswordRecovery = false);
        themeNotifier.value = ThemeMode.light;
      }
    });
  }

  Future<void> _loadDarkModePreference() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client
          .from('user_profiles')
          .select('dark_mode')
          .eq('user_id', userId)
          .maybeSingle();
      final isDark = (data?['dark_mode'] as bool?) ?? false;
      themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (_isPasswordRecovery) return const UpdatePasswordScreen();
        final session = snapshot.data?.session;
        if (session != null) return const HomeScreen();
        return const AuthScreen();
      },
    );
  }
}
