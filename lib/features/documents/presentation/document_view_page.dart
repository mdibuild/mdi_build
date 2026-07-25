import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/project_document.dart';
import 'providers/documents_providers.dart';

class DocumentViewPage extends ConsumerStatefulWidget {
  const DocumentViewPage({
    super.key,
    required this.document,
  });

  final ProjectDocument document;

  @override
  ConsumerState<DocumentViewPage> createState() => _DocumentViewPageState();
}

class _DocumentViewPageState extends ConsumerState<DocumentViewPage> {
  late Future<String> signedUrlFuture;

  @override
  void initState() {
    super.initState();
    signedUrlFuture = ref.read(documentsRepositoryProvider).createSignedUrl(
          bucketId: widget.document.bucketId,
          filePath: widget.document.filePath,
        );
  }

  Future<void> _copyUrl(String signedUrl) async {
    await Clipboard.setData(ClipboardData(text: signedUrl));

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien temporaire copié.')),
    );
  }

  Future<void> _openInApp(String signedUrl) async {
    final uri = Uri.tryParse(signedUrl);
    if (uri == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien document invalide.')),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.inAppBrowserView,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible dâDAÃ¢âDAž¢ouvrir le document.')),
      );
    }
  }

  Future<void> _openExternal(String signedUrl) async {
    final uri = Uri.tryParse(signedUrl);
    if (uri == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien document invalide.')),
      );
      return;
    }

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Impossible dâDAÃ¢âDAž¢ouvrir le document.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;

    return Scaffold(
      appBar: AppBar(
        title: Text(document.title),
      ),
      body: FutureBuilder<String>(
        future: signedUrlFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.trim().isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    'Impossible de charger le document : ${snapshot.error ?? 'lien indisponible'}'),
              ),
            );
          }

          final signedUrl = snapshot.data!;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => _openInApp(signedUrl),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(
                          document.isImage ? 'Rafraîchir / ouvrir' : 'Ouvrir'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _openExternal(signedUrl),
                      icon: const Icon(Icons.launch_outlined),
                      label: const Text('Application externe'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _copyUrl(signedUrl),
                      icon: const Icon(Icons.link_outlined),
                      label: const Text('Copier le lien'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildContent(
                  context: context,
                  document: document,
                  signedUrl: signedUrl,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent({
    required BuildContext context,
    required ProjectDocument document,
    required String signedUrl,
  }) {
    if (document.isImage) {
      return InteractiveViewer(
        minScale: 0.6,
        maxScale: 4,
        child: Center(
          child: Image.network(
            signedUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Impossible dâDAÃ¢âDAž¢afficher cette image.'),
              );
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                return child;
              }

              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          ),
        ),
      );
    }

    if (document.isPdf) {
      return _DocumentFallbackView(
        icon: Icons.picture_as_pdf_outlined,
        title: 'PDF détecté',
        subtitle: 'Le PDF sâDAÃ¢âDAž¢ouvre dans la vue intégrée du téléphone.',
        onOpen: () => _openInApp(signedUrl),
      );
    }

    return _DocumentFallbackView(
      icon: Icons.insert_drive_file_outlined,
      title: document.fileName,
      subtitle:
          'Ce type de fichier sâDAÃ¢âDAž¢ouvre via le navigateur intégré ou une application externe.',
      onOpen: () => _openInApp(signedUrl),
    );
  }
}

class _DocumentFallbackView extends StatelessWidget {
  const _DocumentFallbackView({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onOpen,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 52),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Ouvrir maintenant'),
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
