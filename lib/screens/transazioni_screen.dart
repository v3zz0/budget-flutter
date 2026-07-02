import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/transazione_provider.dart';
import '../providers/user_settings_provider.dart';
import '../services/api_client.dart';
import '../theme.dart';
import '../models/category.dart';
import '../models/transaction.dart';

class TransazioniScreen extends StatefulWidget {
  final VoidCallback? onSalvato;
  const TransazioniScreen({super.key, this.onSalvato});

  @override
  State<TransazioniScreen> createState() => _TransazioniScreenState();
}

class _TransazioniScreenState extends State<TransazioniScreen> {
  Category? _categoriaSelezionata;
  final TextEditingController _importoController = TextEditingController(
    text: '0',
  );
  final TextEditingController _descrizioneController = TextEditingController();
  DateTime _dataSelezionata = DateTime.now();
  bool _ricorrente = false;
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
      context.read<DashboardProvider>().loadCategorie(
        token,
        walletId,
        orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
      );
      setState(() => _categoriaSelezionata = null);
    }
  }

  @override
  void dispose() {
    _importoController.dispose();
    _descrizioneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final walletProvider = context.watch<WalletProvider>();
    final categorie = walletProvider.selectedWallet == null
        ? <Category>[]
        : context
              .watch<DashboardProvider>()
              .categorie
              .where(
                (c) =>
                    c.walletDocumentId ==
                    walletProvider.selectedWallet!.documentId,
              )
              .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.accent,
          backgroundColor: AppColors.card,
          onRefresh: () async {
            final token = requireToken(context);
            final walletId = walletProvider.selectedWallet?.documentId;
            if (token == null || walletId == null) return;
            await context.read<DashboardProvider>().loadCategorie(
              token,
              walletId,
              orarioNotifiche: context.read<UserSettingsProvider>().orarioNotifiche,
            );
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header stile design
              const Text(
                'NUOVA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const Text(
                'Transazione',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 32),

              // Importo — grande e centrato
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 28,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Text(
                      'IMPORTO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _importoController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const Text(
                          '€',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w300,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Sezione categoria
              const Text(
                'CATEGORIA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              categorie.isEmpty
                  ? const Text(
                      'Nessuna categoria disponibile',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: List.generate(categorie.length, (i) {
                        final cat = categorie[i];
                        final isSelected =
                            _categoriaSelezionata?.documentId == cat.documentId;
                        final colore =
                            AppColors.categorie[i % AppColors.categorie.length];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _categoriaSelezionata = cat),
                          child: Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colore.withValues(alpha: 0.15)
                                  : AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? colore : AppColors.border,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 25,
                                  backgroundColor: colore.withValues(alpha: 0.2),
                                  child: cat.icona.isNotEmpty
                                      ? Text(cat.icona, style: const TextStyle(fontSize: 22))
                                      : Text(
                                          cat.nome.isNotEmpty ? cat.nome[0].toUpperCase() : '?',
                                          style: TextStyle(color: colore, fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cat.nome,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isSelected
                                        ? colore
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
              const SizedBox(height: 24),

              // Nome / Descrizione
              const Text(
                'NOME (OPZIONALE)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descrizioneController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Descrizione...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Data
              const Text(
                'DATA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dataSelezionata,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) setState(() => _dataSelezionata = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_dataSelezionata.day.toString().padLeft(2, '0')} / ${_dataSelezionata.month.toString().padLeft(2, '0')} / ${_dataSelezionata.year}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Toggle ricorrente
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.repeat,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ricorrente',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Si ripete ogni mese',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _ricorrente,
                      activeThumbColor: AppColors.accent,
                      onChanged: (val) => setState(() => _ricorrente = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Bottone salva
              Consumer<TransazioneProvider>(
                builder: (context, provider, child) {
                  return ElevatedButton(
                    onPressed: provider.isLoading
                        ? null
                        : () async {
                            final importoVal = double.tryParse(
                              _importoController.text.replaceAll(',', '.'),
                            );
                            if (_categoriaSelezionata == null ||
                                importoVal == null ||
                                importoVal <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Seleziona una categoria e inserisci un importo valido',
                                  ),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                              return;
                            }

                            final token = requireToken(context);
                            if (token == null) return;
                            final transazione = Transaction(
                              documentId: '',
                              importo: importoVal,
                              descrizione: _descrizioneController.text.trim(),
                              data: _dataSelezionata,
                              transazioneRicorrente: _ricorrente,
                              categoriaDocumentId:
                                  _categoriaSelezionata!.documentId,
                            );

                            final successo = await provider.salva(
                              token,
                              transazione,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    successo
                                        ? 'Transazione salvata!'
                                        : 'Errore nel salvataggio',
                                  ),
                                  backgroundColor: successo
                                      ? AppColors.accent
                                      : AppColors.error,
                                ),
                              );
                            }
                            if (successo && context.mounted) {
                              _importoController.text = '0';
                              _descrizioneController.clear();
                              setState(() {
                                _categoriaSelezionata = null;
                                _ricorrente = false;
                                _dataSelezionata = DateTime.now();
                              });
                              widget.onSalvato?.call();
                              context.read<DashboardProvider>().loadCategorie(
                                token,
                                context
                                    .read<WalletProvider>()
                                    .selectedWallet!
                                    .documentId,
                                orarioNotifiche: context
                                    .read<UserSettingsProvider>()
                                    .orarioNotifiche,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: provider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Salva Transazione',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
