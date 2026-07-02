import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wallet.dart';
import '../services/wallet_service.dart';

class WalletProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();

  // Stato privato — equivalente di state: {} in Pinia
  List<Wallet> _wallets = [];
  Wallet? _selectedWallet;
  bool _isLoading = false;
  String? _errore;

  // Getter pubblici
  List<Wallet> get wallets => _wallets;
  Wallet? get selectedWallet => _selectedWallet;
  bool get isLoading => _isLoading;
  String? get errore => _errore;
  bool get hasWallet => _selectedWallet != null;

  // loadWallets() — equivalente di setWallets() + chiamata axios in Vue
  // Richiede il token JWT (preso da AuthProvider)
  Future<void> loadWallets(String token, {int? userId}) async {
    _isLoading = true;
    _errore = null;
    notifyListeners();

    try {
      final lista = await _walletService.loadWallets(token, userId: userId);
      _wallets = lista;

      // Stessa logica del wallet.js Vue:
      // 1. Controlla se c'era un wallet salvato in SharedPreferences
      // 2. Se esiste ancora nella lista, lo riseleziona
      // 3. Altrimenti seleziona il primo
      if (_selectedWallet == null && lista.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final savedId = prefs.getString('selectedWalletId');

        if (savedId != null) {
          // Cerca il wallet salvato nella lista aggiornata
          final found = lista.where((w) => w.documentId == savedId).toList();
          _selectedWallet = found.isNotEmpty ? found.first : lista.first;
        } else {
          _selectedWallet = lista.first;
        }
      } else if (_selectedWallet != null) {
        // Riallinea il selectedWallet con l'istanza appena caricata
        // (es. dopo aver rinominato un wallet o cambiato budget).
        // Se non esiste più nella lista, ricade sul primo disponibile.
        final corrente = lista.where((w) => w.documentId == _selectedWallet!.documentId).toList();
        _selectedWallet = corrente.isNotEmpty
            ? corrente.first
            : (lista.isNotEmpty ? lista.first : null);
      }
    } catch (e) {
      _errore = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // setSelectedWallet() — equivalente dell'action setSelectedWallet() in Pinia
  Future<void> setSelectedWallet(Wallet wallet) async {
    _selectedWallet = wallet;

    // Salva il documentId in SharedPreferences
    // Equivalente di localStorage.setItem('selectedWallet', ...) in Vue
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedWalletId', wallet.documentId);

    notifyListeners();
  }
}
