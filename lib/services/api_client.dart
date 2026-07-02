import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Sessione scaduta']);
  @override
  String toString() => message;
}

// Converte un'eccezione tecnica in un messaggio user-friendly
String erroreLeggibile(Object e) {
  if (e is UnauthorizedException) return 'Sessione scaduta. Effettua nuovamente il login.';
  if (e is TimeoutException) return 'Il server non risponde. Controlla la connessione.';
  if (e is SocketException) return 'Nessuna connessione a internet.';
  if (e is HttpException) return 'Errore di comunicazione con il server.';
  if (e is FormatException) return 'Risposta del server non valida.';

  final msg = e.toString();
  if (msg.contains('500')) return 'Errore del server. Riprova più tardi.';
  if (msg.contains('404')) return 'Risorsa non trovata.';
  if (msg.contains('Exception:')) {
    return msg.replaceFirst('Exception:', '').trim();
  }
  return 'Si è verificato un errore. Riprova.';
}

class ApiClient {
  // Chiave globale per navigare anche senza BuildContext
  static final navigatorKey = GlobalKey<NavigatorState>();
  static const timeout = Duration(seconds: 15);

  static Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  static Future<http.Response> get(Uri uri, {String? token}) async {
    final res = await http.get(uri, headers: _headers(token)).timeout(timeout);
    _check(res);
    return res;
  }

  static Future<http.Response> post(Uri uri, {String? token, Object? body}) async {
    final res = await http.post(uri, headers: _headers(token), body: body).timeout(timeout);
    _check(res);
    return res;
  }

  static Future<http.Response> put(Uri uri, {String? token, Object? body}) async {
    final res = await http.put(uri, headers: _headers(token), body: body).timeout(timeout);
    _check(res);
    return res;
  }

  static Future<http.Response> delete(Uri uri, {String? token}) async {
    final res = await http.delete(uri, headers: _headers(token)).timeout(timeout);
    _check(res);
    return res;
  }

  static void _check(http.Response res) {
    if (res.statusCode == 401 || res.statusCode == 403) {
      navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
      throw UnauthorizedException();
    }
  }
}

/// Recupera il JWT dall'AuthProvider. Se assente:
/// - mostra una SnackBar "Sessione scaduta"
/// - reindirizza al login
/// - ritorna null così il chiamante può fare `return`.
///
/// Uso tipico:
///   final token = requireToken(context);
///   if (token == null) return;
///   await qualcosa(token);
String? requireToken(BuildContext context) {
  final token = context.read<AuthProvider>().token;
  if (token != null && token.isNotEmpty) return token;

  // Token mancante: feedback all'utente + redirect.
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    const SnackBar(content: Text('Sessione scaduta. Effettua nuovamente il login.')),
  );
  ApiClient.navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (_) => false);
  return null;
}
