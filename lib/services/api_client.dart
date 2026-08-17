import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// 401 — il JWT non è più valido: la sessione va chiusa davvero.
class UnauthorizedException implements Exception {
  final String message;
  UnauthorizedException([this.message = 'Sessione scaduta']);
  @override
  String toString() => message;
}

/// 403 — il token è valido, ma il ruolo non ha il permesso su quella rotta.
/// NON è una sessione scaduta: quasi sempre è un permesso Strapi non abilitato
/// (Settings → Users & Permissions → Roles → Authenticated). Deve restare un
/// errore della singola chiamata, altrimenti una feature secondaria che il
/// server nega butta fuori l'utente dall'intera app.
class ForbiddenException implements Exception {
  final String message;
  ForbiddenException([this.message = 'Permesso negato']);
  @override
  String toString() => message;
}

// Converte un'eccezione tecnica in un messaggio user-friendly
String erroreLeggibile(Object e) {
  if (e is UnauthorizedException) return 'Sessione scaduta. Effettua nuovamente il login.';
  if (e is ForbiddenException) {
    return 'Il server non autorizza questa funzione. Controlla i permessi del tuo utente.';
  }
  if (e is TimeoutException) return 'Il server non risponde. Controlla la connessione.';
  if (e is SocketException) return 'Nessuna connessione a internet.';
  // Succede sulle richieste lunghe: il telefono va in standby o cambia rete e
  // il socket muore. Senza questo caso finiva a schermo il testo grezzo
  // "Client Software caused connection abort, uri=...".
  if (e is http.ClientException) {
    return 'Connessione interrotta durante la richiesta. '
        'Se stavi analizzando un estratto conto, tieni l\'app aperta e riprova.';
  }
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

  /// Invocata quando il server dice che il JWT non vale più (401).
  /// La registra main.dart e la implementa AuthProvider: il layer HTTP segnala
  /// e basta, non naviga e non tocca lo stato di sessione. Prima lo faceva:
  /// un singolo 403 su una rotta secondaria azzerava lo stack di navigazione
  /// lasciando però token e isLoggedIn intatti, e l'app rimbalzava
  /// login → home → errore → login all'infinito.
  static void Function()? onSessioneScaduta;

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
    if (res.statusCode == 401) {
      onSessioneScaduta?.call();
      throw UnauthorizedException();
    }
    // 403 = permesso mancante, non sessione scaduta: rilanciamo e basta, così
    // il try/catch del provider che ha fatto la chiamata può gestirlo da solo.
    if (res.statusCode == 403) {
      throw ForbiddenException();
    }
  }
}

/// Recupera il JWT dall'AuthProvider. Se assente:
/// - mostra una SnackBar "Sessione scaduta"
/// - chiude la sessione (che porta al login)
/// - ritorna null così il chiamante può fare `return`.
///
/// Uso tipico:
///   final token = requireToken(context);
///   if (token == null) return;
///   await qualcosa(token);
String? requireToken(BuildContext context) {
  final token = context.read<AuthProvider>().token;
  if (token != null && token.isNotEmpty) return token;

  // Token mancante: feedback all'utente + chiusura sessione. Il redirect passa
  // dallo stesso punto del 401, così non esistono due strade diverse (e
  // divergenti) per tornare al login.
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    const SnackBar(content: Text('Sessione scaduta. Effettua nuovamente il login.')),
  );
  ApiClient.onSessioneScaduta?.call();
  return null;
}
