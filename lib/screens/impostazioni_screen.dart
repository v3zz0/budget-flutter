import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/impostazioni_provider.dart';
import '../providers/user_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../services/ai_settings_service.dart';
import '../services/api_client.dart';
import '../services/notification_service.dart';
import '../services/soglia_service.dart';
import '../models/category.dart';
import '../models/wallet.dart';
import '../theme.dart';
import 'ricorrenti_screen.dart';

// Impostazioni in modalità lista: una voce per area, ognuna apre la sua pagina.
// Prima era un unico scroll con dentro tutto; aggiungendo opzioni diventava
// illeggibile e "aggiungi categoria" spariva dietro un FAB poco scopribile.
class ImpostazioniScreen extends StatelessWidget {
  const ImpostazioniScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>().selectedWallet;
    final settings = context.watch<UserSettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        children: [
          const Text(
            'CONFIGURA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const Text(
            'Impostazioni',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          _VoceImpostazioni(
            icona: Icons.person_outline,
            titolo: 'Profilo utente',
            sottotitolo: settings.username.isEmpty
                ? 'Nome, email e password'
                : settings.username,
            apri: () => const _PaginaProfilo(),
          ),
          _VoceImpostazioni(
            icona: Icons.account_balance_wallet_outlined,
            titolo: 'Portafogli e budget',
            sottotitolo: wallet == null
                ? 'Nessun portafoglio'
                : 'Budget mensile di ${wallet.nome}',
            apri: () => const _PaginaPortafogli(),
          ),
          _VoceImpostazioni(
            icona: Icons.category_outlined,
            titolo: 'Categorie di spesa',
            sottotitolo: 'Aggiungi, rinomina o elimina categorie',
            apri: () => const _PaginaCategorie(),
          ),
          _VoceImpostazioni(
            icona: Icons.repeat,
            titolo: 'Transazioni ricorrenti',
            sottotitolo: 'Cosa viene registrato in automatico ogni mese',
            apri: () => const RicorrentiScreen(),
          ),
          _VoceImpostazioni(
            icona: Icons.notifications_outlined,
            titolo: 'Notifiche',
            sottotitolo: 'Orario degli avvisi per gli addebiti ricorrenti',
            apri: () => const _PaginaNotifiche(),
          ),
          _VoceImpostazioni(
            icona: Icons.lock_outline,
            titolo: 'Sicurezza',
            sottotitolo: 'Accesso con impronta',
            apri: () => const _PaginaSicurezza(),
          ),
          _VoceImpostazioni(
            icona: Icons.auto_awesome_outlined,
            titolo: 'Analisi AI',
            sottotitolo: 'Quale modello analizza gli estratti conto',
            apri: () => const _PaginaAnalisiAi(),
          ),
        ],
      ),
    );
  }
}

/// Riga della lista impostazioni: icona, titolo, sottotitolo, chevron.
class _VoceImpostazioni extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String sottotitolo;
  final Widget Function() apri;

  const _VoceImpostazioni({
    required this.icona,
    required this.titolo,
    required this.sottotitolo,
    required this.apri,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Icon(icona, color: AppColors.accent),
        title: Text(
          titolo,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          sottotitolo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textSecondary,
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => apri()),
        ),
      ),
    );
  }
}

/// Scaffold comune delle sottopagine: AppBar con back + sfondo.
class _Sottopagina extends StatelessWidget {
  final String titolo;
  final Widget child;
  final Widget? fab;

  const _Sottopagina({required this.titolo, required this.child, this.fab});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          titolo,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      floatingActionButton: fab,
      body: child,
    );
  }
}

/// Selettore orizzontale dei wallet, condiviso fra le sottopagine.
class _TabWallet extends StatelessWidget {
  final VoidCallback? onCambio;
  const _TabWallet({this.onCambio});

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final selezionato = walletProvider.selectedWallet;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: walletProvider.wallets.map((w) {
          final isSelected = selezionato?.documentId == w.documentId;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                walletProvider.setSelectedWallet(w);
                onCambio?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Text(
                  w.nome,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ───────────────────────── Profilo utente ─────────────────────────

class _PaginaProfilo extends StatefulWidget {
  const _PaginaProfilo();

  @override
  State<_PaginaProfilo> createState() => _PaginaProfiloState();
}

class _PaginaProfiloState extends State<_PaginaProfilo> {
  late final TextEditingController _nomeCtrl;
  late final TextEditingController _emailCtrl;
  final _attualeCtrl = TextEditingController();
  final _nuovaCtrl = TextEditingController();
  bool _salvandoProfilo = false;
  bool _salvandoPassword = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<UserSettingsProvider>();
    _nomeCtrl = TextEditingController(text: settings.username);
    _emailCtrl = TextEditingController(text: settings.email);

    // Se l'utente non è ancora stato caricato, i campi partono vuoti: li
    // riempiamo appena arriva la risposta di /users/me.
    if (settings.userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final token = requireToken(context);
        if (token == null) return;
        await settings.load(token);
        if (!mounted) return;
        _nomeCtrl.text = settings.username;
        _emailCtrl.text = settings.email;
      });
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _emailCtrl.dispose();
    _attualeCtrl.dispose();
    _nuovaCtrl.dispose();
    super.dispose();
  }

  void _avvisa(String messaggio, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messaggio),
        backgroundColor: ok ? AppColors.positivo : AppColors.error,
      ),
    );
  }

  Future<void> _salvaProfilo() async {
    final nome = _nomeCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    // Validazione lato client: Strapi rifiuta comunque, ma così l'errore è
    // immediato e in italiano.
    if (nome.isEmpty) {
      _avvisa('Il nome utente non può essere vuoto');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _avvisa('Indirizzo email non valido');
      return;
    }

    final token = requireToken(context);
    if (token == null) return;

    setState(() => _salvandoProfilo = true);
    final errore = await context.read<UserSettingsProvider>().updateProfilo(
      token,
      nome,
      email,
    );
    if (!mounted) return;
    setState(() => _salvandoProfilo = false);
    _avvisa(errore ?? 'Profilo aggiornato', ok: errore == null);
  }

  Future<void> _cambiaPassword() async {
    final attuale = _attualeCtrl.text;
    final nuova = _nuovaCtrl.text;

    if (attuale.isEmpty || nuova.isEmpty) {
      _avvisa('Compila entrambi i campi password');
      return;
    }
    // Minimo imposto da Strapi users-permissions.
    if (nuova.length < 6) {
      _avvisa('La nuova password deve avere almeno 6 caratteri');
      return;
    }
    if (nuova == attuale) {
      _avvisa('La nuova password è uguale a quella attuale');
      return;
    }

    final token = requireToken(context);
    if (token == null) return;

    setState(() => _salvandoPassword = true);
    final errore = await context.read<UserSettingsProvider>().cambiaPassword(
      token,
      attuale,
      nuova,
    );
    if (!mounted) return;
    setState(() => _salvandoPassword = false);
    if (errore == null) {
      _attualeCtrl.clear();
      _nuovaCtrl.clear();
    }
    _avvisa(errore ?? 'Password aggiornata', ok: errore == null);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<UserSettingsProvider>();

    return _Sottopagina(
      titolo: 'Profilo utente',
      child: settings.isLoading && settings.userId == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _BloccoImpostazioni(
                  titolo: 'DATI ACCOUNT',
                  figli: [
                    _CampoTesto(
                      etichetta: 'Nome utente',
                      controller: _nomeCtrl,
                      icona: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    _CampoTesto(
                      etichetta: 'Email',
                      controller: _emailCtrl,
                      icona: Icons.mail_outline,
                      tipo: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _BottonePieno(
                      testo: 'Salva dati account',
                      inCorso: _salvandoProfilo,
                      onPressed: _salvaProfilo,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _BloccoImpostazioni(
                  titolo: 'PASSWORD',
                  figli: [
                    _CampoTesto(
                      etichetta: 'Password attuale',
                      controller: _attualeCtrl,
                      icona: Icons.lock_outline,
                      password: true,
                    ),
                    const SizedBox(height: 12),
                    _CampoTesto(
                      etichetta: 'Nuova password',
                      controller: _nuovaCtrl,
                      icona: Icons.lock_reset,
                      password: true,
                    ),
                    const SizedBox(height: 16),
                    _BottonePieno(
                      testo: 'Cambia password',
                      inCorso: _salvandoPassword,
                      onPressed: _cambiaPassword,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

/// Card con titolo in maiuscolo — il contenitore usato in tutte le sottopagine.
class _BloccoImpostazioni extends StatelessWidget {
  final String titolo;
  final List<Widget> figli;

  const _BloccoImpostazioni({required this.titolo, required this.figli});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titolo,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          ...figli,
        ],
      ),
    );
  }
}

class _CampoTesto extends StatelessWidget {
  final String etichetta;
  final TextEditingController controller;
  final IconData icona;
  final bool password;
  final TextInputType? tipo;

  const _CampoTesto({
    required this.etichetta,
    required this.controller,
    required this.icona,
    this.password = false,
    this.tipo,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: password,
      keyboardType: tipo,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: etichetta,
        labelStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icona, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.input,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

class _BottonePieno extends StatelessWidget {
  final String testo;
  final bool inCorso;
  final VoidCallback onPressed;

  const _BottonePieno({
    required this.testo,
    required this.inCorso,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: inCorso ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: inCorso
          ? const SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              testo,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
    );
  }
}

// ───────────────────────── Portafogli e budget ─────────────────────────

class _PaginaPortafogli extends StatefulWidget {
  const _PaginaPortafogli();

  @override
  State<_PaginaPortafogli> createState() => _PaginaPortafogliState();
}

class _PaginaPortafogliState extends State<_PaginaPortafogli> {
  /// Ricarica la lista dal server. Serve dopo creazione ed eliminazione:
  /// WalletProvider riallinea da sé il portafoglio selezionato, e se quello
  /// scelto non c'è più ripiega sul primo.
  Future<void> _ricarica(String token) async {
    await context.read<WalletProvider>().loadWallets(
      token,
      userId: context.read<UserSettingsProvider>().userId,
    );
  }

  Future<void> _nuovo() async {
    final dati = await showDialog<(String, double)>(
      context: context,
      builder: (_) => const _DialogNuovoWallet(),
    );
    if (dati == null || !mounted) return;

    final token = requireToken(context);
    if (token == null) return;

    final ok = await context
        .read<ImpostazioniProvider>()
        .createWallet(token, dati.$1, dati.$2);
    if (!mounted) return;
    if (ok) await _ricarica(token);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Portafoglio creato' : 'Errore nella creazione'),
        backgroundColor: ok ? AppColors.positivo : AppColors.error,
      ),
    );
  }

  Future<void> _elimina(Wallet wallet) async {
    // Un portafoglio si porta dietro categorie, transazioni e storico del
    // salvadanaio: la conferma nomina il portafoglio, così un tap distratto
    // non basta.
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Eliminare il portafoglio?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Stai per eliminare "${wallet.nome}" con tutte le sue categorie, '
          'transazioni e lo storico del salvadanaio. L\'operazione non è '
          'reversibile.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annulla',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Elimina', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;

    final token = requireToken(context);
    if (token == null) return;

    final ok = await context
        .read<ImpostazioniProvider>()
        .deleteWallet(token, wallet.documentId);
    if (!mounted) return;
    if (ok) await _ricarica(token);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Portafoglio eliminato' : 'Errore nell\'eliminazione'),
        backgroundColor: ok ? AppColors.positivo : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final selezionato = walletProvider.selectedWallet;

    return _Sottopagina(
      titolo: 'Portafogli e budget',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (walletProvider.wallets.isNotEmpty) ...[
            const _TabWallet(),
            const SizedBox(height: 20),
          ],
          if (selezionato != null)
            _CardDettagliWallet(wallet: selezionato)
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Nessun portafoglio: creane uno per cominciare.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),

          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _nuovo,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Nuovo portafoglio'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),

          // L'eliminazione sta in fondo e staccata dal resto: è distruttiva e
          // non deve trovarsi accanto ai campi che si toccano tutti i giorni.
          if (selezionato != null && walletProvider.wallets.length > 1) ...[
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () => _elimina(selezionato),
              icon: const Icon(Icons.delete_outline, size: 20),
              label: Text('Elimina "${selezionato.nome}"'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.errorText,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Nome + budget del nuovo portafoglio. Ritorna null se si annulla.
class _DialogNuovoWallet extends StatefulWidget {
  const _DialogNuovoWallet();

  @override
  State<_DialogNuovoWallet> createState() => _DialogNuovoWalletState();
}

class _DialogNuovoWalletState extends State<_DialogNuovoWallet> {
  final _nome = TextEditingController();
  final _budget = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    // Riabilita "Crea" appena si scrive qualcosa. `_CampoTesto` non espone
    // onChanged, e il listener sul controller costa meno che parametrizzarlo.
    _nome.addListener(_ridisegna);
  }

  void _ridisegna() => setState(() {});

  @override
  void dispose() {
    _nome.removeListener(_ridisegna);
    _nome.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nomeValido = _nome.text.trim().isNotEmpty;

    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text(
        'Nuovo portafoglio',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CampoTesto(
            etichetta: 'Nome',
            controller: _nome,
            icona: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 12),
          _CampoTesto(
            etichetta: 'Budget mensile (€)',
            controller: _budget,
            icona: Icons.euro,
            tipo: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Annulla',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          // Senza nome non si crea: un portafoglio "" non è distinguibile
          // dagli altri nella barra in alto.
          onPressed: nomeValido
              ? () => Navigator.pop(context, (
                    _nome.text.trim(),
                    double.tryParse(_budget.text.replaceAll(',', '.')) ?? 0,
                  ))
              : null,
          child: const Text('Crea'),
        ),
      ],
    );
  }
}

// ───────────────────────── Categorie di spesa ─────────────────────────

class _PaginaCategorie extends StatefulWidget {
  const _PaginaCategorie();

  @override
  State<_PaginaCategorie> createState() => _PaginaCategorieState();
}

class _PaginaCategorieState extends State<_PaginaCategorie> {
  final Set<String> _selezionate = {};
  String? _ultimoWalletCaricato;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _caricaSeNecessario();
    });
  }

  void _caricaSeNecessario() {
    final walletId = context.read<WalletProvider>().selectedWallet?.documentId;
    if (walletId != null && walletId != _ultimoWalletCaricato) {
      _ultimoWalletCaricato = walletId;
      final token = requireToken(context);
      if (token == null) return;
      final settings = context.read<UserSettingsProvider>();
      context.read<DashboardProvider>().loadCategorie(
        token,
        walletId,
        orarioNotifiche: settings.orarioNotifiche,
      );
    }
  }

  Future<void> _ricarica() async {
    final wallet = context.read<WalletProvider>().selectedWallet;
    if (wallet == null) return;
    final token = requireToken(context);
    if (token == null) return;
    await context.read<DashboardProvider>().loadCategorie(
      token,
      wallet.documentId,
      orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletSelezionato = context.watch<WalletProvider>().selectedWallet;
    final dashboard = context.watch<DashboardProvider>();

    final categorie = walletSelezionato == null
        ? <Category>[]
        : dashboard.categorie
              .where((c) => c.walletDocumentId == walletSelezionato.documentId)
              .toList();

    return _Sottopagina(
      titolo: 'Categorie di spesa',
      fab: walletSelezionato == null
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              onPressed: () =>
                  _mostraDialogNuovaCategoria(context, walletSelezionato),
              icon: const Icon(Icons.add),
              label: const Text('Nuova categoria'),
            ),
      child: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: _ricarica,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
          children: [
            // Cambiando wallet le spunte non hanno più senso: le azzeriamo.
            _TabWallet(onCambio: () => setState(() => _selezionate.clear())),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Categorie (${categorie.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_selezionate.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => _eliminaSelezionate(walletSelezionato),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppColors.error,
                    ),
                    label: Text(
                      'Elimina (${_selezionate.length})',
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ...categorie.map(
              (cat) => _RigaCategoria(
                categoria: cat,
                isSelezionata: _selezionate.contains(cat.documentId),
                onCheckbox: (val) {
                  setState(() {
                    if (val == true) {
                      _selezionate.add(cat.documentId);
                    } else {
                      _selezionate.remove(cat.documentId);
                    }
                  });
                },
                onEdit: () => _mostraDialogModificaCategoria(context, cat),
              ),
            ),
            if (categorie.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nessuna categoria.\nPremi "Nuova categoria" per aggiungerne una.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _mostraDialogNuovaCategoria(BuildContext context, Wallet? wallet) {
    if (wallet == null) return;
    final nomeCtrl = TextEditingController();
    final budgetCtrl = TextEditingController();
    final iconaCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => _DialogCategoria(
        titolo: 'Nuova Categoria',
        nomeController: nomeCtrl,
        budgetController: budgetCtrl,
        iconaController: iconaCtrl,
        onSalva: () async {
          final budget =
              double.tryParse(budgetCtrl.text.replaceAll(',', '.')) ?? 0;
          if (nomeCtrl.text.isEmpty) return;
          final token = requireToken(context);
          if (token == null) return;
          final provider = context.read<ImpostazioniProvider>();
          final ok = await provider.createCategory(
            token,
            nomeCtrl.text.trim(),
            budget,
            wallet.documentId,
            icona: iconaCtrl.text.trim(),
          );
          if (ok && ctx.mounted) {
            Navigator.pop(ctx);
            await _ricarica();
            if (mounted) setState(() {});
          } else if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(
                  'Errore: ${provider.errore ?? "salvataggio fallito"}',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
      ),
    );
  }

  void _mostraDialogModificaCategoria(BuildContext context, Category cat) {
    final nomeCtrl = TextEditingController(text: cat.nome);
    final budgetCtrl = TextEditingController(
      text: cat.budgetCategoria.toStringAsFixed(0),
    );
    final iconaCtrl = TextEditingController(text: cat.icona);

    showDialog(
      context: context,
      builder: (ctx) => _DialogCategoria(
        titolo: 'Modifica Categoria',
        nomeController: nomeCtrl,
        budgetController: budgetCtrl,
        iconaController: iconaCtrl,
        onSalva: () async {
          final budget =
              double.tryParse(budgetCtrl.text.replaceAll(',', '.')) ?? 0;
          if (nomeCtrl.text.isEmpty) return;
          final token = requireToken(context);
          if (token == null) return;
          final provider = context.read<ImpostazioniProvider>();
          final ok = await provider.updateCategory(
            token,
            cat.documentId,
            nomeCtrl.text.trim(),
            budget,
            icona: iconaCtrl.text.trim(),
          );
          if (ok && ctx.mounted) {
            Navigator.pop(ctx);
            await _ricarica();
            if (mounted) setState(() {});
          } else if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(
                  'Errore: ${provider.errore ?? "salvataggio fallito"}',
                ),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
      ),
    );
  }

  // Niente BuildContext come parametro: usiamo quello dello State, così il
  // check `mounted` copre davvero il context che stiamo usando.
  Future<void> _eliminaSelezionate(Wallet? wallet) async {
    if (wallet == null) return;

    // Eliminare una categoria porta con sé le sue transazioni: chiediamo conferma.
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Eliminare le categorie?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Stai per eliminare ${_selezionate.length} categorie e le transazioni collegate. L\'operazione non è reversibile.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Annulla',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Elimina',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (conferma != true || !mounted) return;

    final token = requireToken(context);
    if (token == null) return;
    final provider = context.read<ImpostazioniProvider>();

    for (final id in _selezionate.toList()) {
      await provider.deleteCategory(token, id);
    }
    if (!mounted) return;
    setState(() => _selezionate.clear());
    await _ricarica();
  }
}

// ───────────────────────── Notifiche e sicurezza ─────────────────────────

class _PaginaNotifiche extends StatelessWidget {
  const _PaginaNotifiche();

  @override
  Widget build(BuildContext context) {
    return const _Sottopagina(
      titolo: 'Notifiche',
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardNotifiche(),
            SizedBox(height: 24),
            _CardSoglia(),
          ],
        ),
      ),
    );
  }
}

/// Soglia oltre la quale una categoria fa scattare l'avviso.
/// È una preferenza del dispositivo (SharedPreferences), non del profilo:
/// riguarda solo le notifiche locali di questo telefono.
class _CardSoglia extends StatefulWidget {
  const _CardSoglia();

  @override
  State<_CardSoglia> createState() => _CardSogliaState();
}

class _CardSogliaState extends State<_CardSoglia> {
  double _soglia = SogliaService.sogliaPredefinita;
  bool _caricando = true;

  @override
  void initState() {
    super.initState();
    SogliaService.soglia().then((v) {
      if (mounted) setState(() { _soglia = v; _caricando = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avviso di budget',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ti avvisa quando una categoria raggiunge questa percentuale del '
            'suo budget. Una volta sola al mese per categoria.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_caricando)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accent,
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _soglia,
                    // Sotto il 50% avviserebbe a metà mese ogni volta; sopra il
                    // 100% non sarebbe più un preavviso ma un referto.
                    min: 0.5,
                    max: 1.0,
                    divisions: 10,
                    activeColor: AppColors.accent,
                    label: '${(_soglia * 100).round()}%',
                    onChanged: (v) => setState(() => _soglia = v),
                    onChangeEnd: SogliaService.salvaSoglia,
                  ),
                ),
                SizedBox(
                  width: 52,
                  child: Text(
                    '${(_soglia * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PaginaSicurezza extends StatelessWidget {
  const _PaginaSicurezza();

  @override
  Widget build(BuildContext context) {
    return _Sottopagina(
      titolo: 'Sicurezza',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Consumer<AuthProvider>(
          builder: (context, auth, _) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.accent,
              title: const Text(
                'Accesso con impronta',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text(
                'Accedi con l\'impronta invece di email e password',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              value: auth.biometriaAbilitata,
              onChanged: (v) async {
                if (!v) {
                  await auth.disabilitaBiometria();
                } else if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Esci e accedi con email e password per attivarlo',
                      ),
                    ),
                  );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Analisi AI ─────────────────────────

/// Sceglie chi genera categorie e giudizio quando analizzi un estratto conto.
/// L'estrazione dei movimenti NON passa mai di qui: quella la fa il parser sul
/// server, in modo esatto, qualunque motore tu scelga.
class _PaginaAnalisiAi extends StatefulWidget {
  const _PaginaAnalisiAi();

  @override
  State<_PaginaAnalisiAi> createState() => _PaginaAnalisiAiState();
}

class _PaginaAnalisiAiState extends State<_PaginaAnalisiAi> {
  final _service = AiSettingsService();
  final _urlCtrl = TextEditingController();
  final _modelloCtrl = TextEditingController();
  final _chiaveCtrl = TextEditingController();

  ImpostazioniAi _s = const ImpostazioniAi();
  bool _caricando = true;
  bool _salvando = false;
  bool _provando = false;

  @override
  void initState() {
    super.initState();
    // Dopo il primo frame: requireToken può mostrare uno snackbar e navigare,
    // cose che in initState non si possono ancora fare.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _carica();
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _modelloCtrl.dispose();
    _chiaveCtrl.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    final token = requireToken(context);
    // Anche senza token la rotella deve fermarsi, altrimenti la pagina resta
    // a girare per sempre.
    if (token == null) {
      setState(() => _caricando = false);
      return;
    }
    try {
      final s = await _service.carica(token);
      if (!mounted) return;
      setState(() {
        _s = s;
        _urlCtrl.text = s.url;
        _modelloCtrl.text = s.modello;
        _caricando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _caricando = false);
      _avviso(erroreLeggibile(e));
    }
  }

  void _cambiaMotore(MotoreAi m) {
    setState(() {
      _s = _s.copyWith(motore: m);
      // Preset comodi, sovrascrivibili a mano.
      if (m == MotoreAi.openrouter) {
        if (_urlCtrl.text.isEmpty || _urlCtrl.text.contains('11434')) {
          _urlCtrl.text = 'https://openrouter.ai/api/v1';
        }
      } else if (m == MotoreAi.ollama && _urlCtrl.text.contains('openrouter')) {
        _urlCtrl.text = '';
      }
    });
  }

  ImpostazioniAi get _daForm => _s.copyWith(
        url: _urlCtrl.text.trim(),
        modello: _modelloCtrl.text.trim(),
      );

  Future<void> _prova() async {
    final token = requireToken(context);
    if (token == null) return;
    setState(() => _provando = true);
    try {
      final (ok, messaggio) = await _service.prova(
        token,
        _daForm,
        chiave: _chiaveCtrl.text.trim(),
      );
      if (mounted) _avviso(messaggio, errore: !ok);
    } catch (e) {
      if (mounted) _avviso(erroreLeggibile(e));
    } finally {
      if (mounted) setState(() => _provando = false);
    }
  }

  Future<void> _salva() async {
    final token = requireToken(context);
    final userId = context.read<UserSettingsProvider>().userId;
    if (token == null || userId == null) return;
    setState(() => _salvando = true);
    try {
      await _service.salva(token, userId, _daForm, chiave: _chiaveCtrl.text.trim());
      if (!mounted) return;
      setState(() {
        _s = _daForm.copyWith(
          chiaveImpostata: _s.chiaveImpostata || _chiaveCtrl.text.trim().isNotEmpty,
        );
        _chiaveCtrl.clear();
      });
      _avviso('Impostazioni salvate', errore: false);
    } catch (e) {
      if (mounted) _avviso(erroreLeggibile(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _avviso(String messaggio, {bool errore = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(messaggio),
        backgroundColor: errore ? AppColors.error : AppColors.accent,
      ),
    );
  }

  /// Elenco modelli OpenRouter, con ricerca. I gratuiti stanno in cima.
  Future<void> _scegliModelloOpenRouter() async {
    List<String> modelli;
    try {
      modelli = await _service.modelliOpenRouter();
    } catch (e) {
      if (mounted) _avviso('Elenco modelli non raggiungibile, scrivilo a mano');
      return;
    }
    if (!mounted) return;

    final scelto = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoModelli(modelli: modelli),
    );
    if (scelto != null) setState(() => _modelloCtrl.text = scelto);
  }

  @override
  Widget build(BuildContext context) {
    if (_caricando) {
      return const _Sottopagina(
        titolo: 'Analisi AI',
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }

    return _Sottopagina(
      titolo: 'Analisi AI',
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'I movimenti vengono letti dal server in modo esatto, senza AI. '
            'Il modello qui sotto serve solo a suggerire le categorie e a '
            'scrivere il giudizio del mese.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          _SceltaMotore(
            icona: Icons.dns_outlined,
            titolo: 'Server Ollama',
            sottotitolo: 'Il tuo mini PC. Solo dalla rete di casa',
            attivo: _s.motore == MotoreAi.ollama,
            onTap: () => _cambiaMotore(MotoreAi.ollama),
          ),
          _SceltaMotore(
            icona: Icons.cloud_outlined,
            titolo: 'OpenRouter',
            sottotitolo: 'Cloud, funziona ovunque. Ci sono modelli gratuiti',
            attivo: _s.motore == MotoreAi.openrouter,
            onTap: () => _cambiaMotore(MotoreAi.openrouter),
          ),
          const SizedBox(height: 20),

          _BloccoImpostazioni(
            titolo: 'CONNESSIONE',
            figli: [
                _CampoTesto(
                  etichetta: _s.motore == MotoreAi.ollama
                      ? 'Indirizzo (es. http://192.168.1.10:11434)'
                      : 'Indirizzo API',
                  controller: _urlCtrl,
                  icona: Icons.link,
                  tipo: TextInputType.url,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CampoTesto(
                        etichetta: 'Modello',
                        controller: _modelloCtrl,
                        icona: Icons.memory,
                      ),
                    ),
                    if (_s.motore == MotoreAi.openrouter) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _scegliModelloOpenRouter,
                        icon: const Icon(Icons.search, color: AppColors.accent),
                        tooltip: 'Scegli dall\'elenco',
                      ),
                    ],
                  ],
                ),
                if (_s.motore == MotoreAi.openrouter) ...[
                  const SizedBox(height: 12),
                  _CampoTesto(
                    etichetta: _s.chiaveImpostata
                        ? 'Chiave API (già salvata, riscrivi per cambiarla)'
                        : 'Chiave API',
                    controller: _chiaveCtrl,
                    icona: Icons.key,
                    password: true,
                  ),
                ],
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _provando ? null : _prova,
                  icon: _provando
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.accent,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering, size: 18),
                  label: const Text('Prova connessione'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),
          _BottonePieno(
            testo: 'Salva impostazioni',
            inCorso: _salvando,
            onPressed: _salva,
          ),
        ],
      ),
    );
  }
}

/// Card di scelta del motore, con il pallino di selezione.
class _SceltaMotore extends StatelessWidget {
  final IconData icona;
  final String titolo;
  final String sottotitolo;
  final bool attivo;
  final VoidCallback onTap;

  const _SceltaMotore({
    required this.icona,
    required this.titolo,
    required this.sottotitolo,
    required this.attivo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: attivo ? AppColors.accent.withValues(alpha: 0.10) : AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: attivo ? AppColors.accent : AppColors.border,
            width: attivo ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icona, color: attivo ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titolo,
                    style: TextStyle(
                      color: attivo ? AppColors.accent : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    sottotitolo,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              attivo ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: attivo ? AppColors.accent : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

/// Elenco modelli OpenRouter con campo di ricerca.
class _DialogoModelli extends StatefulWidget {
  final List<String> modelli;
  const _DialogoModelli({required this.modelli});

  @override
  State<_DialogoModelli> createState() => _DialogoModelliState();
}

class _DialogoModelliState extends State<_DialogoModelli> {
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    final visibili = widget.modelli
        .where((m) => m.toLowerCase().contains(_filtro.toLowerCase()))
        .take(60)
        .toList();

    return AlertDialog(
      backgroundColor: AppColors.card,
      title: const Text(
        'Scegli il modello',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 18),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Cerca (es. gemma, free)',
                hintStyle: TextStyle(color: AppColors.textSecondary),
                prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
              ),
              onChanged: (v) => setState(() => _filtro = v),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: visibili.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  title: Text(
                    visibili[i],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  trailing: visibili[i].endsWith(':free')
                      ? const Text(
                          'gratis',
                          style: TextStyle(color: AppColors.accent, fontSize: 11),
                        )
                      : null,
                  onTap: () => Navigator.pop(context, visibili[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDettagliWallet extends StatefulWidget {
  final Wallet wallet;
  const _CardDettagliWallet({required this.wallet});

  @override
  State<_CardDettagliWallet> createState() => _CardDettagliWalletState();
}

class _CardDettagliWalletState extends State<_CardDettagliWallet> {
  late TextEditingController _nomeCtrl;
  late TextEditingController _budgetCtrl;

  @override
  void initState() {
    super.initState();
    _nomeCtrl = TextEditingController(text: widget.wallet.nome);
    _budgetCtrl = TextEditingController(
      text: widget.wallet.budget.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(_CardDettagliWallet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallet.documentId != widget.wallet.documentId) {
      _nomeCtrl.text = widget.wallet.nome;
      _budgetCtrl.text = widget.wallet.budget.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  // Setta il testo mantenendo il cursore in fondo, invece di farlo saltare a 0
  void _setTesto(TextEditingController ctrl, String testo) {
    ctrl.value = TextEditingValue(
      text: testo,
      selection: TextSelection.collapsed(offset: testo.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DETTAGLI WALLET',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nome',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _CampoWallet(controller: _nomeCtrl, hint: 'Nome wallet'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Budget €',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _CampoWallet(
                      controller: _budgetCtrl,
                      hint: '0',
                      isNumerico: true,
                      suffixIcon: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () {
                              final v = double.tryParse(_budgetCtrl.text) ?? 0;
                              _setTesto(_budgetCtrl, (v + 10).toStringAsFixed(0));
                            },
                            child: const Icon(
                              Icons.keyboard_arrow_up,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final v = double.tryParse(_budgetCtrl.text) ?? 0;
                              if (v > 0) {
                                _setTesto(_budgetCtrl, (v - 10).toStringAsFixed(0));
                              }
                            },
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final budget =
                    double.tryParse(_budgetCtrl.text.replaceAll(',', '.')) ?? 0;
                if (_nomeCtrl.text.isEmpty) return;
                final token = requireToken(context);
                if (token == null) return;
                final ok = await context
                    .read<ImpostazioniProvider>()
                    .updateWallet(
                      token,
                      widget.wallet.documentId,
                      _nomeCtrl.text.trim(),
                      budget,
                    );
                if (ok && context.mounted) {
                  final userId = context.read<UserSettingsProvider>().userId;
                  await context.read<WalletProvider>().loadWallets(token, userId: userId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Wallet aggiornato'),
                      backgroundColor: AppColors.accent,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Salva'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampoWallet extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isNumerico;
  final Widget? suffixIcon;

  const _CampoWallet({
    required this.controller,
    required this.hint,
    this.isNumerico = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: isNumerico
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: isNumerico
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.input,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent),
        ),
      ),
    );
  }
}

class _RigaCategoria extends StatelessWidget {
  final Category categoria;
  final bool isSelezionata;
  final void Function(bool?) onCheckbox;
  final VoidCallback onEdit;

  const _RigaCategoria({
    required this.categoria,
    required this.isSelezionata,
    required this.onCheckbox,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelezionata
              ? AppColors.error.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isSelezionata,
            onChanged: onCheckbox,
            activeColor: AppColors.error,
            side: const BorderSide(color: AppColors.textSecondary),
          ),
          if (categoria.icona.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.input,
                child: Text(
                  categoria.icona,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoria.nome,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Budget: ${categoria.budgetCategoria.toStringAsFixed(0)} €',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Modifica categoria',
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _DialogCategoria extends StatefulWidget {
  final String titolo;
  final TextEditingController nomeController;
  final TextEditingController budgetController;
  final TextEditingController iconaController;
  final VoidCallback onSalva;

  const _DialogCategoria({
    required this.titolo,
    required this.nomeController,
    required this.budgetController,
    required this.iconaController,
    required this.onSalva,
  });

  @override
  State<_DialogCategoria> createState() => _DialogCategoriaState();
}

class _DialogCategoriaState extends State<_DialogCategoria> {
  static const List<String> _emojiPreset = [
    '🛒',
    '🍔',
    '🏠',
    '🚗',
    '⛽',
    '💊',
    '🎬',
    '🏖️',
    '👕',
    '📱',
    '💡',
    '🎁',
    '📚',
    '🐾',
    '☕',
    '💰',
  ];

  @override
  void initState() {
    super.initState();
    widget.iconaController.addListener(_onIconaChanged);
  }

  @override
  void dispose() {
    widget.iconaController.removeListener(_onIconaChanged);
    super.dispose();
  }

  void _onIconaChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.titolo,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: widget.iconaController,
              // Le emoji moderne occupano fino a 7-8 code units UTF-16
              // (es. famiglia 👨‍👩‍👧‍👦). Limitiamo a 8 senza mostrare il counter.
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Icona (emoji)',
                labelStyle: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
                hintText: '🛒',
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _emojiPreset.map((e) {
                final selezionata = widget.iconaController.text == e;
                return GestureDetector(
                  onTap: () {
                    widget.iconaController.value = TextEditingValue(
                      text: e,
                      selection: TextSelection.collapsed(offset: e.length),
                    );
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selezionata ? AppColors.accent : AppColors.input,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selezionata
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 20)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.nomeController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Nome',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.budgetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Budget €',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.input,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Annulla',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: widget.onSalva,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Salva'),
        ),
      ],
    );
  }
}

class _CardNotifiche extends StatelessWidget {
  const _CardNotifiche();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<UserSettingsProvider>();
    final orario = settings.orarioNotifiche;
    final orarioStr = orario != null
        ? '${orario.hour.toString().padLeft(2, '0')}:${orario.minute.toString().padLeft(2, '0')}'
        : '--:--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NOTIFICHE',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: settings.isLoading
                ? null
                : () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: orario ?? const TimeOfDay(hour: 9, minute: 0),
                      builder: (ctx, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: AppColors.accent,
                            surface: AppColors.card,
                          ),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null && context.mounted) {
                      final token = requireToken(context);
                      if (token == null) return;
                      final ok = await context.read<UserSettingsProvider>().updateOrario(token, picked);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Orario aggiornato' : 'Errore aggiornamento'),
                            backgroundColor: ok ? AppColors.positivo : AppColors.error,
                          ),
                        );
                      }
                    }
                  },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.input,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Orario notifiche', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                        Text('Quando ricevere gli avvisi degli addebiti ricorrenti', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(orarioStr, style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Verifica al volo che permessi e canale funzionino: le ricorrenti
          // scattano fra settimane, senza questo non sai se sono rotte.
          TextButton.icon(
            icon: const Icon(Icons.notifications_active_outlined, size: 18),
            label: const Text('Invia notifica di prova'),
            style: TextButton.styleFrom(foregroundColor: AppColors.accent),
            onPressed: () async {
              final ok = await NotificationService.test();
              final n = await NotificationService.pianificate();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Notifica inviata · $n ricorrenti pianificate'
                      : 'Permesso notifiche negato: attivalo dalle impostazioni Android'),
                  backgroundColor: ok ? AppColors.positivo : AppColors.error,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
