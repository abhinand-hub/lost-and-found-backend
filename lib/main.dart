import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'dart:html' as html;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://twhahfakfvuunofvatbh.supabase.co',
    anonKey: 'sb_publishable_kw48P_tlfkDNQP6-7kZpqw_MLI99KuE',
  );

  // 🔥 Clean auth redirect URL
  final uri = Uri.base;
  if (uri.queryParameters.containsKey('code')) {
    final cleanUri = Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.port,
      path: uri.path,
    );
    // replace URL without reloading page
    // ignore: undefined_prefixed_name
    html.window.history.replaceState(null, '', cleanUri.toString());
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "iLost",
      home: AuthGate(), // 🔥 IMPORTANT CHANGE
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data!.session;

        if (session != null) {
          return const HomeScreen();
        } else {
          return const SplashScreen();
        }
      },
    );
  }
}
