import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/dashboard_provider.dart';
import 'providers/transazione_provider.dart';
import 'providers/salvadanaio_provider.dart';
import 'providers/impostazioni_provider.dart';
import 'providers/user_settings_provider.dart';
import 'providers/analisi_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'theme.dart';

// main() = punto di ingresso dell'app — equivalente di main.js in Vue
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Su web NotificationService è no-op internamente, niente if necessario qui
  await NotificationService.init();
  // Inizializza i dati di localizzazione italiani per intl (formattazione date/valute)
  await initializeDateFormatting('it_IT', null);
  runApp(
    // MultiProvider = registrare più store insieme — equivalente di app.use(pinia) in Vue
    // con tutti gli store registrati
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => TransazioneProvider()),
        ChangeNotifierProvider(create: (_) => SalvadanaiProvider()),
        ChangeNotifierProvider(create: (_) => ImpostazioniProvider()),
        ChangeNotifierProvider(create: (_) => UserSettingsProvider()),
        ChangeNotifierProvider(create: (_) => AnalisiProvider()),
      ],
      child: const BudgetApp(),
    ),
  );
}

// BudgetApp è il widget radice — equivalente di App.vue
class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ApiClient.navigatorKey,
      title: 'BudgetApp',
      debugShowCheckedModeBanner:
          false, // rimuove il banner "DEBUG" in alto a destra
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'DMSans', // font del design
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.dark(
          surface: AppColors.bg,
          primary: AppColors.accent,
          error: AppColors.error,
        ),
      ),
      // home: decide quale schermata mostrare all'avvio
      // _StartupScreen controlla se l'utente è già loggato
      home: const _StartupScreen(),
      // routes = vue-router — mappa path → schermata
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

// _StartupScreen — schermata invisibile che decide dove mandare l'utente
// Equivalente del navigation guard in Vue Router (beforeEach)
// Controlla se c'è un JWT salvato, poi reindirizza
class _StartupScreen extends StatefulWidget {
  const _StartupScreen();

  @override
  State<_StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<_StartupScreen> {
  @override
  void initState() {
    super.initState();
    // initState() = onMounted() in Vue
    // Chiamato una volta sola quando il widget viene creato
    _controlla();
  }

  Future<void> _controlla() async {
    final auth = context.read<AuthProvider>();
    await auth.init(); // legge flag biometria + eventuale JWT salvato

    if (!mounted) return;

    // JWT valido → home diretto. Altrimenti → login (dove scatta l'impronta,
    // se il login biometrico è attivo).
    if (auth.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mostra uno spinner mentre controlla il JWT
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
    );
  }
}
