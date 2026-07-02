import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:budget_flutter/main.dart';
import 'package:budget_flutter/providers/auth_provider.dart';
import 'package:budget_flutter/providers/wallet_provider.dart';
import 'package:budget_flutter/providers/dashboard_provider.dart';
import 'package:budget_flutter/providers/transazione_provider.dart';
import 'package:budget_flutter/providers/salvadanaio_provider.dart';
import 'package:budget_flutter/providers/impostazioni_provider.dart';
import 'package:budget_flutter/providers/user_settings_provider.dart';
import 'package:budget_flutter/providers/analisi_provider.dart';

void main() {
  testWidgets('App si avvia mostrando lo spinner di startup', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => WalletProvider()),
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider(create: (_) => TransazioneProvider()),
          ChangeNotifierProvider(create: (_) => SalvadanaiProvider()),
          ChangeNotifierProvider(create: (_) => ImpostazioniProvider()),
          ChangeNotifierProvider(create: (_) => UserSettingsProvider()),
          ChangeNotifierProvider(create: (_) => AnalisiProvider()),
        ],
        child: const BudgetApp(),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
