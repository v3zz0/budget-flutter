import 'transaction.dart';

/// Una transazione creata mentre il telefono era offline (o mentre il server
/// non rispondeva), in attesa di essere inviata a Strapi.
///
/// Diversa da [Transaction]: qui [documentId] è sempre vuoto (non esiste
/// ancora lato server), e [clientUuid] è obbligatorio — è la chiave con cui
/// [Transaction.toJson] viene mandata al server e con cui si riconosce se
/// l'invio è già andato a buon fine in un tentativo precedente.
class TransazionePendente {
  final String clientUuid;
  final Transaction transazione;
  final DateTime creataIl;

  const TransazionePendente({
    required this.clientUuid,
    required this.transazione,
    required this.creataIl,
  });
}
