import 'package:flutter/material.dart';
import '../services/wallet_service.dart';
import '../services/category_service.dart';
import '../services/api_client.dart';

class ImpostazioniProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService();
  final CategoryService _categoryService = CategoryService();

  bool isLoading = false;
  String? errore;

  Future<bool> updateWallet(String token, String documentId, String nome, double budget) async {
    try {
      await _walletService.updateWallet(token, documentId, nome, budget);
      return true;
    } catch (e) {
      errore = erroreLeggibile(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCategory(String token, String documentId, String nome, double budget, {String? icona}) async {
    try {
      await _categoryService.updateCategory(token, documentId, nome, budget, icona: icona);
      return true;
    } catch (e) {
      errore = erroreLeggibile(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(String token, String documentId) async {
    try {
      await _categoryService.deleteCategory(token, documentId);
      return true;
    } catch (e) {
      errore = erroreLeggibile(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> createCategory(String token, String nome, double budget, String walletDocumentId, {String? icona}) async {
    try {
      await _categoryService.createCategory(token, nome, budget, walletDocumentId, icona: icona);
      return true;
    } catch (e) {
      errore = erroreLeggibile(e);
      notifyListeners();
      return false;
    }
  }
}
