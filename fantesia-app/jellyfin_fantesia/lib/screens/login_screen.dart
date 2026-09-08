import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/jellyfin_api.dart';
import '../config.dart';
import '../theme.dart';
import 'root_screen.dart';

/// Connexion. Aucune adresse de serveur n'est demandee : elle est fixee dans
/// [AppConfig].
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Renseigne ton identifiant et ton mot de passe.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await JellyfinApi.instance.login(_user.text.trim(), _pass.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RootScreen()),
      );
    } catch (e) {
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Fantesia',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -1.5,
                        color: C.amber,
                      ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Connecte-toi avec ton compte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.textDim),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _user,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: 'Identifiant',
                    prefixIcon: Icon(Icons.person_outline, color: C.textDim),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  obscureText: _hidden,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline, color: C.textDim),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: C.textDim,
                      ),
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(color: C.danger, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Text('Se connecter'),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () => launchUrl(
                    Uri.parse(AppConfig.jfaGoUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  child: const Text(
                    'Creer un compte ou reinitialiser le mot de passe',
                    style: TextStyle(color: C.textDim, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
