import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/jellyfin_api.dart';
import '../config.dart';
import '../theme.dart';
import 'login_screen.dart';
import 'quality_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final api = JellyfinApi.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Reglages')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline, color: C.amber),
            title: const Text('Compte'),
            subtitle: Text(api.userName ?? ''),
          ),
          const Divider(indent: 16),
          ListTile(
            leading: const Icon(Icons.hd_outlined, color: C.amber),
            title: const Text('Definition par defaut'),
            subtitle: Text(QualityPrefs.current.label),
            trailing: const Icon(Icons.chevron_right, color: C.textDim),
            onTap: () async {
              await showQualitySheet(context, force: true);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.speed_outlined, color: C.amber),
            title: const Text('Demander la definition avant chaque lecture'),
            value: !QualityPrefs.skipSheet,
            activeColor: C.amber,
            onChanged: (v) async {
              await QualityPrefs.setSkip(!v);
              setState(() {});
            },
          ),
          const Divider(indent: 16),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined, color: C.amber),
            title: const Text('Gerer mon compte'),
            subtitle: const Text('Mot de passe, invitations'),
            trailing: const Icon(Icons.open_in_new, size: 18, color: C.textDim),
            onTap: () => launchUrl(
              Uri.parse(AppConfig.jfaGoUrl),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined, color: C.amber),
            title: const Text('Serveur'),
            subtitle: Text(
              AppConfig.jellyfinUrl.replaceFirst('https://', ''),
            ),
          ),
          const Divider(indent: 16),
          ListTile(
            leading: const Icon(Icons.logout, color: C.danger),
            title: const Text('Se deconnecter',
                style: TextStyle(color: C.danger)),
            onTap: () async {
              await api.logout();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (_) => false,
              );
            },
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Fantesia ${AppConfig.clientVersion}',
              style: const TextStyle(color: C.textDim, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
