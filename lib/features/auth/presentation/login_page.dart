import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/device_token_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/username_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    FocusScope.of(context).unfocus();
    setState(() => loading = true);

    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: usernameToPseudoEmail(usernameController.text),
        password: passwordController.text,
      );

      unawaited(DeviceTokenService.registerCurrentToken());

      if (!mounted) {
        return;
      }

      context.go('/dashboard');
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de connexion : $error')),
      );
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FlutterLogo(size: 72),
                  const SizedBox(height: 16),
                  TextField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Nom d\'utilisateur',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    decoration:
                        const InputDecoration(labelText: 'Mot de passe'),
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      child: Text(loading ? 'Connexion...' : 'Se connecter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
