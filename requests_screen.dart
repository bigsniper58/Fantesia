import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config.dart';
import '../theme.dart';

/// Jellyseerr, integre dans l'application.
///
/// Jellyseerr accepte la connexion avec le compte Jellyfin : l'utilisateur
/// reste dans la meme application pour demander un titre absent du catalogue.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _web;
  int _progress = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(C.bg)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) => setState(() => _progress = p),
          onPageFinished: (_) => setState(() => _progress = 100),
        ),
      )
      ..loadRequest(Uri.parse(AppConfig.jellyseerrUrl));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Demandes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _web.reload(),
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
      ),
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (await _web.canGoBack()) _web.goBack();
        },
        child: WebViewWidget(controller: _web),
      ),
    );
  }
}
