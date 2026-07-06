import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/user_settings_provider.dart';
import '../services/api_client.dart';
import 'home_screen.dart';
import 'transazioni_screen.dart';
import 'salvadanaio_screen.dart';
import 'impostazioni_screen.dart';
import 'analisi_screen.dart';
import '../theme.dart';

// MainScreen = equivalente di App.vue con Toolbar + RouterView
// È il contenitore principale dopo il login
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Indice della tab attiva — equivalente di quale route è attiva in Vue Router
  int _currentIndex = 0;

  // Lista delle schermate — in base a _currentIndex mostra quella giusta
  // Equivalente del <RouterView> che cambia componente al cambio di route
  late final List<Widget> _schermate;

  // Indici delle tab (devono restare allineati a _schermate e ai 5 slot della nav)
  static const int _idxDashboard = 0;
  static const int _idxSalvadanaio = 1;
  static const int _idxTransazioni = 2;
  static const int _idxAnalisi = 3;
  static const int _idxImpostazioni = 4;

  @override
  void initState() {
    super.initState();
    // Ordine: Dashboard · Salvadanaio · Transazioni · Analisi · Impostazioni
    // Il bottone Transazioni nella nav viene reso come FAB centrale sporgente.
    _schermate = [
      const HomeScreen(),
      const SalvadanaiScreen(),
      TransazioniScreen(onSalvato: () => setState(() => _currentIndex = _idxDashboard)),
      const AnalisiScreen(),
      const ImpostazioniScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _caricaWallets();
    });
  }

  Future<void> _caricaWallets() async {
    final token = requireToken(context);
    if (token == null) return;

    final walletProvider = context.read<WalletProvider>();
    final userSettings = context.read<UserSettingsProvider>();

    // Prima carica i dati utente per avere userId, poi i wallet filtrati
    if (userSettings.userId == null) {
      await userSettings.load(token);
    }
    if (!mounted) return;
    await walletProvider.loadWallets(token, userId: userSettings.userId);
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final auth = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: Colors.white,
        title: const Text(
          'BudgetApp',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Bottone logout in alto a destra
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Esci',
            onPressed: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: walletProvider.wallets.map((wallet) {
                  final isSelected =
                      walletProvider.selectedWallet?.documentId ==
                      wallet.documentId;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => walletProvider.setSelectedWallet(wallet),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accent.withValues(alpha: 0.15)
                              : AppColors.input,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.border,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          wallet.nome,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),

      // body mostra la schermata corrispondente alla tab attiva
      // Equivalente di <RouterView> in Vue
      body: _schermate[_currentIndex],

      // Bottom nav custom: 4 tab piatti + un FAB centrale sporgente per "Transazioni".
      // L'altezza extra in alto serve a far rientrare il FAB senza clipping.
      extendBody: true,
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

/// Nav inferiore custom: 5 slot, quello centrale (index 2 = Transazioni)
/// è un bottone circolare in rilievo che sporge sopra la barra.
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const navHeight = 64.0;
    const fabProtrusion = 22.0;
    // Inset di sistema in basso (barra gesti / home indicator). Senza tenerne
    // conto le etichette finiscono appiccicate al bordo sui telefoni a gesti.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return SizedBox(
      // Spazio extra in alto per il FAB sporgente + inset di sistema in basso.
      height: navHeight + fabProtrusion + bottomInset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Barra piatta in basso con i 4 tab + uno slot vuoto al centro
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: navHeight + bottomInset,
            child: Container(
              // Il padding bottom spinge icone/label sopra la barra di sistema.
              padding: EdgeInsets.only(bottom: bottomInset),
              decoration: const BoxDecoration(
                color: AppColors.card,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: Row(
                children: [
                  Expanded(child: _NavTab(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Dashboard',
                    selected: currentIndex == _MainScreenState._idxDashboard,
                    onTap: () => onTap(_MainScreenState._idxDashboard),
                  )),
                  Expanded(child: _NavTab(
                    icon: Icons.savings_outlined,
                    activeIcon: Icons.savings,
                    label: 'Salvadanaio',
                    selected: currentIndex == _MainScreenState._idxSalvadanaio,
                    onTap: () => onTap(_MainScreenState._idxSalvadanaio),
                  )),
                  // Slot centrale: spazio occupato dal FAB sovrapposto; mostriamo solo la label
                  Expanded(child: _FabLabel(
                    selected: currentIndex == _MainScreenState._idxTransazioni,
                  )),
                  Expanded(child: _NavTab(
                    icon: Icons.auto_awesome_outlined,
                    activeIcon: Icons.auto_awesome,
                    label: 'Analisi',
                    selected: currentIndex == _MainScreenState._idxAnalisi,
                    onTap: () => onTap(_MainScreenState._idxAnalisi),
                  )),
                  Expanded(child: _NavTab(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: 'Impostazioni',
                    selected: currentIndex == _MainScreenState._idxImpostazioni,
                    onTap: () => onTap(_MainScreenState._idxImpostazioni),
                  )),
                ],
              ),
            ),
          ),

          // FAB centrale: sporge in alto, perfettamente centrato.
          // Posizionato in modo che metà sopra la barra.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _FabTransazioni(
                onTap: () => onTap(_MainScreenState._idxTransazioni),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? activeIcon : icon, size: 22, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Solo la label "Transazioni" sotto al FAB centrale.
/// Il bottone vero e proprio è gestito da [_FabTransazioni] sovrapposto.
class _FabLabel extends StatelessWidget {
  final bool selected;
  const _FabLabel({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Transazioni',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: selected ? AppColors.accent : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _FabTransazioni extends StatefulWidget {
  final VoidCallback onTap;
  const _FabTransazioni({required this.onTap});

  @override
  State<_FabTransazioni> createState() => _FabTransazioniState();
}

class _FabTransazioniState extends State<_FabTransazioni> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.accent;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        width: 62,
        height: 62,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Bordo dello stesso colore della barra: effetto "incastonato".
          border: Border.all(color: AppColors.card, width: 4),
          // Gradiente radiale per dare profondità 3D.
          gradient: const RadialGradient(
            center: Alignment(-0.36, -0.44),
            radius: 0.95,
            colors: [
              Color(0xFF60A5FA), // highlight (accent più chiaro)
              accent,
              Color(0xFF2563EB), // ombra (accent più scuro)
            ],
            stops: [0.0, 0.48, 1.0],
          ),
          boxShadow: _pressed
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.33),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  const BoxShadow(
                    color: Color(0x66000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.33),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                  const BoxShadow(
                    color: Color(0x73000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                  const BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: const Icon(Icons.add, size: 30, color: Colors.white),
      ),
    );
  }
}
