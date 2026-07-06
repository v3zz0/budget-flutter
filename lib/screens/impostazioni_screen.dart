import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/impostazioni_provider.dart';
import '../providers/user_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_client.dart';
import '../models/category.dart';
import '../models/wallet.dart';
import '../theme.dart';

class ImpostazioniScreen extends StatefulWidget {
  const ImpostazioniScreen({super.key});

  @override
  State<ImpostazioniScreen> createState() => _ImpostazioniScreenState();
}

class _ImpostazioniScreenState extends State<ImpostazioniScreen> {
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
      if (settings.userId == null) {
        settings.load(token);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final wallets = walletProvider.wallets;
    final walletSelezionato = walletProvider.selectedWallet;
    final dashboard = context.watch<DashboardProvider>();

    final categorie = walletSelezionato == null
        ? <Category>[]
        : dashboard.categorie
              .where((c) => c.walletDocumentId == walletSelezionato.documentId)
              .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        onPressed: () =>
            _mostraDialogNuovaCategoria(context, walletSelezionato),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.card,
        onRefresh: () async {
          final token = requireToken(context);
          if (token == null) return;
          final settings = context.read<UserSettingsProvider>();
          await context.read<WalletProvider>().loadWallets(token, userId: settings.userId);
          if (!context.mounted) return;
          if (walletSelezionato != null) {
            await context.read<DashboardProvider>().loadCategorie(
              token,
              walletSelezionato.documentId,
              orarioNotifiche: settings.orarioNotifiche,
            );
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
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

              // Sicurezza — accesso con impronta (login biometrico)
              Consumer<AuthProvider>(
                builder: (context, auth, _) => Container(
                  margin: const EdgeInsets.only(bottom: 24),
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
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                    value: auth.biometriaAbilitata,
                    onChanged: (v) async {
                      if (!v) {
                        await auth.disabilitaBiometria();
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Esci e accedi con email e password per attivarlo'),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),

              // Tab wallet
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: wallets.map((w) {
                    final isSelected =
                        walletSelezionato?.documentId == w.documentId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          walletProvider.setSelectedWallet(w);
                          setState(() => _selezionate.clear());
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.accent
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.accent
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            w.nome,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // Card notifiche
              const _CardNotifiche(),
              const SizedBox(height: 20),

              // Card dettagli wallet
              if (walletSelezionato != null)
                _CardDettagliWallet(wallet: walletSelezionato),
              const SizedBox(height: 20),

              // Header categorie con conteggio e bottone elimina selezionate
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
                      onPressed: () =>
                          _eliminaSelezionate(context, walletSelezionato),
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

              // Lista categorie
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
                    'Nessuna categoria.\nPremi + per aggiungerne una.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
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
            await context.read<DashboardProvider>().loadCategorie(
              token,
              wallet.documentId,
              orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
            );
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
          final wallet = context.read<WalletProvider>().selectedWallet;
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
            if (wallet != null) {
              await context.read<DashboardProvider>().loadCategorie(
                token,
                wallet.documentId,
                orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
              );
            }
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

  Future<void> _eliminaSelezionate(BuildContext context, Wallet? wallet) async {
    if (wallet == null) return;
    final token = requireToken(context);
    if (token == null) return;
    final provider = context.read<ImpostazioniProvider>();
    final orario = context.read<UserSettingsProvider>().orarioNotifiche;

    for (final id in _selezionate.toList()) {
      await provider.deleteCategory(token, id);
    }
    if (!mounted) return;
    setState(() => _selezionate.clear());
    if (context.mounted) {
      await context.read<DashboardProvider>().loadCategorie(
        token,
        wallet.documentId,
        orarioNotifiche: orario,
      );
    }
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
                            backgroundColor: ok ? AppColors.accent : AppColors.error,
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
        ],
      ),
    );
  }
}
