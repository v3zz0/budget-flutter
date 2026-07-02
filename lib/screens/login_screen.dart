import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
    await auth.login(_emailController.text.trim(), _passwordController.text);

    // Se il login è andato a buon fine, naviga alla home
    // mounted: verifica che il widget sia ancora attivo (buona pratica in Flutter)
    if (auth.isLoggedIn && context.mounted) {
      Navigator.pushReplacementNamed(context, '/home');
    }
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
