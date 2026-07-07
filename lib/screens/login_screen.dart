import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/biometric_service.dart';
import '../theme.dart';

// StatefulWidget perché abbiamo i TextEditingController da gestire
// Equivalente di un componente Vue con data() che contiene email e password
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Lo "State" è la parte con i dati e la logica — come data() + methods in Vue
class _LoginScreenState extends State<LoginScreen> {
  // TextEditingController = v-model in Vue
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Controlla se la password è visibile — equivalente di ref(false) in Vue
  bool _passwordVisibile = false;
  bool _biometricTentato = false;

  @override
  void initState() {
    super.initState();
    // Se il login biometrico è attivo, propone subito l'impronta.
    // Copre sia l'avvio a freddo sia il ritorno dopo un logout.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _tentaBiometria(automatico: true));
  }

  // Prova l'accesso con impronta; se OK rifà il login con le credenziali salvate.
  Future<void> _tentaBiometria({bool automatico = false}) async {
    if (automatico && _biometricTentato) return;
    _biometricTentato = true;
    final auth = context.read<AuthProvider>();
    if (!auth.biometriaAbilitata) return;
    if (!await BiometricService.disponibile()) return;
    if (!mounted) return;
    final ok = await BiometricService.autentica(motivo: 'Accedi a BudgetApp');
    if (!ok) return;
    final loggato = await auth.loginConBiometria();
    if (loggato && mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // dispose() = onUnmounted() in Vue — pulizia memoria quando il widget viene distrutto
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Metodo chiamato al click del bottone — equivalente di un method in Vue
  Future<void> _login(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    await auth.login(email, password);

    if (!auth.isLoggedIn || !context.mounted) return;

    // Login riuscito: se il device supporta la biometria e non è già attiva,
    // proponi di abilitare l'accesso con impronta per la prossima volta.
    if (!auth.biometriaAbilitata && await BiometricService.disponibile()) {
      if (!context.mounted) return;
      final vuole = await _chiediAttivaBiometria(context);
      if (vuole == true) {
        await auth.abilitaBiometria(email, password);
      }
    }

    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  // Dialog: chiede se attivare il login con impronta.
  Future<bool?> _chiediAttivaBiometria(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Accesso con impronta',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Vuoi usare l\'impronta per accedere più velocemente la prossima volta?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No, grazie'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Attiva'),
          ),
        ],
      ),
    );
  }

  // build() = <template> in Vue — descrive come appare il widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold è il layout base di una schermata Material Design
      // Fornisce sfondo, padding, e struttura base
      backgroundColor: AppColors.bg,
      body: SafeArea(
        // SafeArea evita che il contenuto finisca sotto la barra di stato del telefono
        child: Center(
          child: SingleChildScrollView(
            // SingleChildScrollView = overflow-y: auto — permette lo scroll se la tastiera spinge su il contenuto
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              // Column = display: flex; flex-direction: column in CSS
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo e titolo
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16), // equivalente di margin-bottom
                const Text(
                  'BudgetApp',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accedi al tuo account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 48),

                // Campo email — equivalente di <input type="email" v-model="email">
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.input,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Campo password con toggle visibilità
                TextField(
                  controller: _passwordController,
                  obscureText: !_passwordVisibile,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.lock_outlined, color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.input,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.accent),
                    ),
                    // Bottone occhio per mostrare/nascondere password
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisibile
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        // setState() = equivalente di modificare un ref() in Vue
                        // Dice a Flutter di ricostruire il widget con il nuovo valore
                        setState(() {
                          _passwordVisibile = !_passwordVisibile;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Consumer ascolta AuthProvider — si ricostruisce quando cambia lo stato
                // Equivalente di const auth = useAuthStore() nel template Vue
                Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Messaggio di errore — visibile solo se auth.errore != null
                        if (auth.errore != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              auth.errore!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Bottone login — mostra spinner se isLoading è true
                        ElevatedButton(
                          onPressed: auth.isLoading
                              ? null // null = bottone disabilitato
                              : () => _login(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: auth.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Accedi',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),

                        // Bottone impronta — solo se il login biometrico è attivo
                        if (auth.biometriaAbilitata) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed:
                                auth.isLoading ? null : () => _tentaBiometria(),
                            icon: const Icon(Icons.fingerprint,
                                color: AppColors.accent),
                            label: const Text('Accedi con impronta',
                                style: TextStyle(color: AppColors.accent)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: AppColors.accent),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
