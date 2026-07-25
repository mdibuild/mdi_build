import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/chat_message.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import 'providers/chat_providers.dart';

String _dateTimeLabel(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} ${two(value.hour)}:${two(value.minute)}';
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();

  bool _sending = false;
  bool _recording = false;

  @override
  void dispose() {
    _messageController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    if (_sending) {
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final profile = await ref.read(currentProfileProvider.future);
    final project = await ref.read(selectedProjectProvider.future);

    if (profile == null || project == null) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await ref.read(chatRepositoryProvider).sendText(
            companyId: profile.companyId,
            projectId: project.id,
            senderId: profile.id,
            senderName: 'Vous',
            text: text,
          );

      _messageController.clear();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur message : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
    );

    if (picked == null) {
      return;
    }

    final bytes = await picked.readAsBytes();

    await _sendAttachment(
      bytes: bytes,
      fileName: picked.name,
      mimeType: _resolveMimeType(picked.name, preferred: 'image/jpeg'),
      messageType: 'image',
    );
  }

  Future<void> _pickFile() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.any,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final file = picked.files.single;
    final bytes = file.bytes;

    if (bytes == null) {
      return;
    }

    await _sendAttachment(
      bytes: bytes,
      fileName: file.name,
      mimeType: _resolveMimeType(file.name),
      messageType: 'file',
    );
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();

      if (!mounted) {
        return;
      }

      setState(() {
        _recording = false;
      });

      if (path == null) {
        return;
      }

      final file = File(path);
      if (!await file.exists()) {
        return;
      }

      final bytes = await file.readAsBytes();

      await _sendAttachment(
        bytes: bytes,
        fileName: 'audio_${DateTime.now().millisecondsSinceEpoch}.m4a',
        mimeType: 'audio/mp4',
        messageType: 'audio',
      );

      return;
    }

    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone non autorisé.')),
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final path =
        '${tempDir.path}/chat_record_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(),
      path: path,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _recording = true;
    });
  }

  Future<void> _sendAttachment({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required String messageType,
  }) async {
    if (_sending) {
      return;
    }

    final profile = await ref.read(currentProfileProvider.future);
    final project = await ref.read(selectedProjectProvider.future);

    if (profile == null || project == null) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await ref.read(chatRepositoryProvider).sendBinaryMessage(
            companyId: profile.companyId,
            projectId: project.id,
            senderId: profile.id,
            senderName: 'Vous',
            messageType: messageType,
            bytes: bytes,
            fileName: fileName,
            mimeType: mimeType,
          );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur pièce jointe : $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  String _resolveMimeType(String fileName, {String? preferred}) {
    if (preferred != null && preferred.trim().isNotEmpty) {
      return preferred;
    }

    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }
    if (lower.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (lower.endsWith('.m4a')) {
      return 'audio/mp4';
    }

    return 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    final projectAsync = ref.watch(selectedProjectProvider);
    final messagesAsync = ref.watch(currentProjectMessagesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: projectAsync.when(
        data: (project) {
          if (project == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Choisis un projet pour ouvrir le chat projet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.forum_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Canal projet',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(project.name),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(
                        child: Text('Aucun message pour ce projet.'),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _ChatMessageTile(message: message);
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Text('Erreur chat : $error'),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    border: Border(
                      top: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Image',
                        onPressed: _sending ? null : _pickImage,
                        icon: const Icon(Icons.image_outlined),
                      ),
                      IconButton(
                        tooltip: 'Fichier',
                        onPressed: _sending ? null : _pickFile,
                        icon: const Icon(Icons.attach_file_outlined),
                      ),
                      IconButton(
                        tooltip: _recording ? 'Arrêter audio' : 'Audio',
                        onPressed: _sending ? null : _toggleRecord,
                        icon: Icon(
                          _recording
                              ? Icons.stop_circle_outlined
                              : Icons.mic_none_outlined,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          minLines: 1,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: _recording
                                ? 'Enregistrement audio...'
                                : 'ÃƒâDA°crire un message',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _sending ? null : _sendText,
                        child: Text(_sending ? '...' : 'Envoyer'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, _) => Center(
          child: Text('Erreur projet : $error'),
        ),
      ),
    );
  }
}

class _ChatMessageTile extends ConsumerWidget {
  const _ChatMessageTile({
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfileAsync = ref.watch(currentProfileProvider);
    final currentUserId = currentProfileAsync.valueOrNull?.id;
    final isMine = currentUserId != null && currentUserId == message.senderId;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment:
                  isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  isMine ? 'Vous' : message.senderName,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 6),
                if (message.isText) Text(message.textContent),
                if (message.isImage && message.hasAttachment)
                  _ImageAttachment(message: message),
                if (message.isFile && message.hasAttachment)
                  _FileAttachment(message: message),
                if (message.isAudio && message.hasAttachment)
                  _AudioAttachment(message: message),
                const SizedBox(height: 6),
                Text(
                  _dateTimeLabel(message.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageAttachment extends ConsumerWidget {
  const _ImageAttachment({
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = ref.read(chatRepositoryProvider).createSignedUrl(
          bucketId: message.bucketId!,
          filePath: message.filePath!,
        );

    return FutureBuilder<String>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final url = snapshot.data!;

        return GestureDetector(
          onTap: () => launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              url,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }
}

class _FileAttachment extends ConsumerWidget {
  const _FileAttachment({
    required this.message,
  });

  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () async {
        final url = await ref.read(chatRepositoryProvider).createSignedUrl(
              bucketId: message.bucketId!,
              filePath: message.filePath!,
            );

        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      },
      icon: const Icon(Icons.insert_drive_file_outlined),
      label: Text(message.fileName ?? 'Fichier'),
    );
  }
}

class _AudioAttachment extends StatefulWidget {
  const _AudioAttachment({
    required this.message,
  });

  final ChatMessage message;

  @override
  State<_AudioAttachment> createState() => _AudioAttachmentState();
}

class _AudioAttachmentState extends State<_AudioAttachment> {
  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();

    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<String> _loadUrl(BuildContext context) {
    final container = ProviderScope.containerOf(context, listen: false);

    return container.read(chatRepositoryProvider).createSignedUrl(
          bucketId: widget.message.bucketId!,
          filePath: widget.message.filePath!,
        );
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.message.audioDurationMs == null
        ? '-'
        : (widget.message.audioDurationMs! / 1000).toStringAsFixed(0);

    return FutureBuilder<String>(
      future: _loadUrl(context),
      builder: (context, snapshot) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: snapshot.hasData
                  ? () async {
                      if (_playing) {
                        await _player.stop();

                        if (mounted) {
                          setState(() {
                            _playing = false;
                          });
                        }
                        return;
                      }

                      await _player.play(UrlSource(snapshot.data!));

                      if (mounted) {
                        setState(() {
                          _playing = true;
                        });
                      }
                    }
                  : null,
              icon: Icon(
                _playing
                    ? Icons.stop_circle_outlined
                    : Icons.play_circle_outline,
              ),
            ),
            Text('Audio · $seconds s'),
          ],
        );
      },
    );
  }
}
