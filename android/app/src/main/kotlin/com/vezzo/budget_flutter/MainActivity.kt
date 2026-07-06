package com.vezzo.budget_flutter

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (non FlutterActivity) è richiesto dal plugin local_auth
// per mostrare il BiometricPrompt di sistema (impronta/volto).
class MainActivity : FlutterFragmentActivity()
