import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/category.dart';
import '../models/wallet.dart';

/// Ultimo elenco di portafogli e categorie visto con successo dal server.
///
/// Non è una copia dei dati finanziari (nessuna transazione, nessun totale
/// speso): serve solo a sapere QUALI portafogli e QUALI categorie esistono,
/// così il modulo "nuova transazione" funziona anche quando l'app parte
/// senza aver mai raggiunto il server in questa sessione — es. telefono
/// senza rete fin dall'apertura, il caso che il solo "salva offline" di ieri
/// non copriva: senza un elenco di categorie da mostrare, il modulo restava
/// bloccato anche se la transazione, una volta scelta la categoria, sarebbe
/// finita comunque nella coda offline.
class ReferenceCache {
  static const _chiaveWallets = 'cache_wallets';
  static String _chiaveCategorie(String walletId) =>
      'cache_categorie_$walletId';

  static Future<void> salvaWallets(List<Wallet> wallets) async {
    final prefs = await SharedPreferences.getInstance();
    final json = wallets
        .map((w) => {
              'documentId': w.documentId,
              'nome': w.nome,
              'budget': w.budget,
              'salvadanaio': w.salvadanaio,
              'esclusoDaStatistiche': w.esclusoDaStatistiche,
            })
        .toList();
    await prefs.setString(_chiaveWallets, jsonEncode(json));
  }

  static Future<List<Wallet>> caricaWallets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chiaveWallets);
    if (raw == null) return [];
    final lista = jsonDecode(raw) as List;
    return lista
        .map((m) => Wallet(
              documentId: m['documentId'] as String,
              nome: m['nome'] as String,
              budget: (m['budget'] as num).toDouble(),
              salvadanaio: (m['salvadanaio'] as num).toDouble(),
              esclusoDaStatistiche: m['esclusoDaStatistiche'] as bool? ?? false,
            ))
        .toList();
  }

  static Future<void> salvaCategorie(
    String walletId,
    List<Category> categorie,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final json = categorie
        .map((c) => {
              'documentId': c.documentId,
              'nome': c.nome,
              'budgetCategoria': c.budgetCategoria,
              'walletDocumentId': c.walletDocumentId,
              'icona': c.icona,
            })
        .toList();
    await prefs.setString(_chiaveCategorie(walletId), jsonEncode(json));
  }

  static Future<List<Category>> caricaCategorie(String walletId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_chiaveCategorie(walletId));
    if (raw == null) return [];
    final lista = jsonDecode(raw) as List;
    return lista
        .map((m) => Category(
              documentId: m['documentId'] as String,
              nome: m['nome'] as String,
              budgetCategoria: (m['budgetCategoria'] as num).toDouble(),
              walletDocumentId: m['walletDocumentId'] as String,
              icona: m['icona'] as String? ?? '',
            ))
        .toList();
  }
}
