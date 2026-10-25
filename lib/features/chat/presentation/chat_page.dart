import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mdi_build/shared/presentation/project_module_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/chat_message.dart';
import '../../../core/models/settings_user_entry.dart';
import '../../../core/services/firebase_push_service.dart';
import '../../../shared/presentation/module_filters.dart';
import '../../../shared/presentation/premium_ui.dart';
import '../../projects/presentation/providers/current_profile_provider.dart';
import '../../projects/presentation/providers/projects_providers.dart';
import '../../projects/presentation/providers/selected_project_provider.dart';
import '../../settings/presentation/providers/settings_providers.dart';
import '../domain/chat_unread.dart';
import 'providers/chat_providers.dart';

String _timeLabel(DateTime value) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.hour)}:${two(value.minute)}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

const _weekdays = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// Libellé d'un séparateur de date : « Aujourd'hui », « Hier », le jour de
/// la semaine pour les 7 derniers jours, sinon la date complète.
String _dayLabel(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(value.year, value.month, value.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    return "Aujourd'hui";
  }
  if (diff == 1) {
    return 'Hier';
  }
  if (diff > 1 && diff < 7) {
    return _weekdays[value.weekday - 1];
  }
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year}';
}

/// Couleurs de l'espace de discussion, reprises de WhatsApp (clair/sombre).
class _WaColors {
  const _WaColors(this.isDark);

  factory _WaColors.of(BuildContext context) =>
      _WaColors(Theme.of(context).brightness == Brightness.dark);

  final bool isDark;

  Color get wallpaper =>
      isDark ? const Color(0xFF0B141A) : const Color(0xFFEFEAE2);
  Color get outgoing =>
      isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3);
  Color get incoming => isDark ? const Color(0xFF202C33) : Colors.white;
  Color get text => isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
  Color get meta => isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);
  Color get metaOutgoing =>
      isDark ? const Color(0xFFA9C7C1) : const Color(0xFF667781);
  Color get pill => isDark ? const Color(0xFF182229) : Colors.white;
  Color get pillText =>
      isDark ? const Color(0xFF8696A0) : const Color(0xFF54656F);
  Color get composer => isDark ? const Color(0xFF2A3942) : Colors.white;
  Color get accent => const Color(0xFF00A884);
  Color get readTick => const Color(0xFF53BDEB);

  /// Couleurs des noms d'auteurs dans les conversations à plusieurs.
  List<Color> get authorColors => isDark
      ? const [
          Color(0xFF53BDEB),
          Color(0xFFFF72A1),
          Color(0xFF06CF9C),
          Color(0xFFFFA97A),
          Color(0xFFA791FF),
          Color(0xFF71EB85),
          Color(0xFFFF6E6E),
          Color(0xFF35CDDE),
        ]
      : const [
          Color(0xFF0A6FD6),
          Color(0xFFC2185B),
          Color(0xFF00796B),
          Color(0xFFD84315),
          Color(0xFF5E35B1),
          Color(0xFF2E7D32),
          Color(0xFFC62828),
          Color(0xFF00838F),
        ];

  Color authorColor(String? key) {
    final value = key ?? '';
    var sum = 0;
    for (final unit in value.codeUnits) {
      sum += unit;
    }
    return authorColors[sum % authorColors.length];
  }
}

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final FocusNode _composerFocus =
      FocusNode(onKeyEvent: _handleComposerKey);
  final AudioRecorder _recorder = AudioRecorder();

  bool _sending = false;
  bool _recording = false;
  bool _searching = false;
  bool _filtering = false;
  bool _showJumpToBottom = false;
  String _search = '';
  String _contentFilter = 'all';
  String _authorFilter = 'all';
  String? _recipientId;
  String? _recipientName;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (!kIsWeb) {
      FirebasePushService.clearModule('chat');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _composerFocus.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 320;
    if (show != _showJumpToBottom) {
      setState(() => _showJumpToBottom = show);
    }
  }

  /// La liste est inversée : la position 0 correspond aux derniers messages.
  void _jumpToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  /// Sur ordinateur (web/bureau) : Entrée envoie, Maj+Entrée va à la ligne.
  KeyEventResult _handleComposerKey(FocusNode node, KeyEvent event) {
    final desktopLike = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;
    if (!desktopLike || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter || HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _sendText();
    return KeyEventResult.handled;
  }

  /// Destination de l'envoi selon la conversation ouverte :
  /// chat général (projectId null) ou projet sélectionné.
  Future<({bool ok, String? projectId})> _resolveTarget() async {
    if (ref.read(chatConversationProvider) == ChatConversation.general) {
      return (ok: true, projectId: null);
    }
    final project = await ref.read(selectedProjectProvider.future);
    if (project == null) {
      return (ok: false, projectId: null);
    }
    return (ok: true, projectId: project.id);
  }

  void _openGeneral() {
    ref.read(chatConversationProvider.notifier).open(ChatConversation.general);
    _jumpToBottom();
  }

  Future<void> _openProject(String projectId) async {
    await ref.read(selectedProjectIdProvider.notifier).setProjectId(projectId);
    ref.read(chatConversationProvider.notifier).open(ChatConversation.project);
    _jumpToBottom();
  }

  void _refresh() {
    ref.invalidate(currentProjectMessagesProvider);
    ref.invalidate(generalChatMessagesProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Messages actualisés'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _search = '';
    });
  }

  bool get _hasMessageFilters =>
      _search.trim().isNotEmpty ||
      _contentFilter != 'all' ||
      _authorFilter != 'all';

  void _resetMessageFilters() {
    _searchController.clear();
    setState(() {
      _search = '';
      _contentFilter = 'all';
      _authorFilter = 'all';
    });
  }

  void _toggleMessageFilters() {
    FocusScope.of(context).unfocus();
    setState(() => _filtering = !_filtering);
  }

  List<ChatMessage> _filterMessages(List<ChatMessage> all, String? myId) {
    final query = _search.trim().toLowerCase();
    return all.where((message) {
      final contentMatch =
          _contentFilter == 'all' || message.messageType == _contentFilter;
      final authorMatch =
          _authorFilter == 'all' || (myId != null && message.senderId == myId);
      final textMatch = query.isEmpty ||
          message.textContent.toLowerCase().contains(query) ||
          message.senderName.toLowerCase().contains(query) ||
          (message.fileName ?? '').toLowerCase().contains(query);
      return contentMatch && authorMatch && textMatch;
    }).toList();
  }

  Widget _buildMessageFilters() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 178,
              child: ModuleFilterDropdown<String>(
                label: 'Type de contenu',
                value: _contentFilter,
                items: const [
                  DropdownMenuItem(
                      value: 'all', child: Text('Tous les contenus')),
                  DropdownMenuItem(value: 'text', child: Text('Textes')),
                  DropdownMenuItem(value: 'image', child: Text('Photos')),
                  DropdownMenuItem(value: 'file', child: Text('Documents')),
                  DropdownMenuItem(value: 'audio', child: Text('Audio')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _contentFilter = value);
                },
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 178,
              child: ModuleFilterDropdown<String>(
                label: 'Auteur',
                value: _authorFilter,
                items: const [
                  DropdownMenuItem(
                      value: 'all', child: Text('Tous les auteurs')),
                  DropdownMenuItem(value: 'mine', child: Text('Mes messages')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _authorFilter = value);
                },
              ),
            ),
          ],
        ),
      ),
    );
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
    final target = await _resolveTarget();

    if (profile == null || !target.ok) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await ref.read(chatRepositoryProvider).sendText(
            companyId: profile.companyId,
            projectId: target.projectId,
            senderId: profile.id,
            senderName: '${profile.fullName} · ${profile.role.label}',
            text: text,
            recipientId: _recipientId,
            recipientName: _recipientName,
          );

      _messageController.clear();
      _jumpToBottom();
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
          _recipientId = null;
          _recipientName = null;
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
    final picked = await FilePicker.pickFiles(
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
    final target = await _resolveTarget();

    if (profile == null || !target.ok) {
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      await ref.read(chatRepositoryProvider).sendBinaryMessage(
            companyId: profile.companyId,
            projectId: target.projectId,
            senderId: profile.id,
            senderName: '${profile.fullName} · ${profile.role.label}',
            messageType: messageType,
            bytes: bytes,
            fileName: fileName,
            mimeType: mimeType,
            recipientId: _recipientId,
            recipientName: _recipientName,
          );
      _jumpToBottom();
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
          _recipientId = null;
          _recipientName = null;
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

  /// Accusés de lecture : marque comme lus les messages qui me sont
  /// adressés dans la conversation affichée (après le rendu).
  void _scheduleMarkRead(List<ChatMessage> messages, String? myId) {
    if (myId == null) {
      return;
    }
    final unread = messages
        .where((m) => m.recipientId == myId && !m.isRead && m.id.isNotEmpty)
        .toList();
    if (unread.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final repo = ref.read(chatRepositoryProvider);
      for (final m in unread) {
        repo.markRead(m.id);
      }
    });
  }

  /// Conversation affichée = lue jusqu'à son dernier message (pastille).
  void _scheduleMarkSeen(List<ChatMessage> messages, String key) {
    if (messages.isEmpty) {
      return;
    }
    var latest = messages.first.createdAt;
    for (final m in messages) {
      if (m.createdAt.isAfter(latest)) {
        latest = m.createdAt;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatReadStateProvider.notifier).markSeen(key, latest);
      }
    });
  }

  Future<void> _openConversationPicker() async {
    final conversation = ref.read(chatConversationProvider);
    final selectedId = ref.read(selectedProjectProvider).value?.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final projectsAsync = ref.watch(projectsProvider);
            final unread = ref.watch(chatUnreadByConversationProvider);
            final theme = Theme.of(context);

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Text(
                        'Conversations',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 12),
                        children: [
                          _ConversationTile(
                            icon: Icons.groups_rounded,
                            title: 'Chat général',
                            subtitle: "Toute l'équipe · hors projet",
                            unread: unread['general'] ?? 0,
                            selected: conversation == ChatConversation.general,
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _openGeneral();
                            },
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Divider(),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                            child: Text(
                              'Projets',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                          ...projectsAsync.when(
                            data: (projects) => projects.isEmpty
                                ? const [
                                    ListTile(
                                      title: Text('Aucun projet'),
                                      subtitle: Text(
                                        'Créez un projet dans le module Projets.',
                                      ),
                                    ),
                                  ]
                                : [
                                    for (final project in projects)
                                      _ConversationTile(
                                        icon: Icons.apartment_rounded,
                                        title: project.name,
                                        subtitle: 'Conversation du projet',
                                        unread: unread[project.id] ?? 0,
                                        selected: conversation ==
                                                ChatConversation.project &&
                                            project.id == selectedId,
                                        onTap: () {
                                          Navigator.of(sheetContext).pop();
                                          _openProject(project.id);
                                        },
                                      ),
                                  ],
                            loading: () => const [
                              Padding(
                                padding: EdgeInsets.all(20),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              ),
                            ],
                            error: (_, __) => const [
                              ListTile(title: Text('Projets indisponibles')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickRecipient(List<SettingsUserEntry> recipients) async {
    final picked = await showModalBottomSheet<SettingsUserEntry?>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(
                    'Destinataire',
                    style: Theme.of(sheetContext).textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: const Text('Tout le monde'),
                  subtitle:
                      const Text('Message visible par toute la conversation'),
                  selected: _recipientId == null,
                  onTap: () => Navigator.of(sheetContext).pop(),
                ),
                for (final entry in recipients)
                  ListTile(
                    leading: const Icon(Icons.lock_person_outlined),
                    title: Text(entry.displayName),
                    subtitle: Text('Message privé · ${entry.role}'),
                    selected: entry.id == _recipientId,
                    onTap: () => Navigator.of(sheetContext).pop(entry),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _recipientId = picked?.id;
      _recipientName = picked?.displayName;
    });
  }

  Future<void> _openAttachMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        Widget option(
          IconData icon,
          String label,
          Color color,
          Future<void> Function() action,
        ) {
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(sheetContext).pop();
              action();
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: color,
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(label),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12,
              runSpacing: 8,
              children: [
                option(
                  Icons.photo_library_rounded,
                  'Galerie',
                  const Color(0xFFBF59CF),
                  _pickImage,
                ),
                option(
                  Icons.insert_drive_file_rounded,
                  'Document',
                  const Color(0xFF7F66FF),
                  _pickFile,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wa = _WaColors.of(context);
    final conversation = ref.watch(chatConversationProvider);
    final projectAsync = ref.watch(selectedProjectProvider);
    final project = projectAsync.value;
    final isGeneral = conversation == ChatConversation.general;
    final noProject = !isGeneral && projectAsync.hasValue && project == null;
    final messagesAsync = isGeneral
        ? ref.watch(generalChatMessagesProvider)
        : ref.watch(currentProjectMessagesProvider);
    final profile = ref.watch(currentProfileProvider).value;
    final List<SettingsUserEntry> recipients = profile == null
        ? const []
        : (ref.watch(companyUsersProvider(profile.companyId)).value ?? const [])
            .where((entry) => entry.id != profile.id)
            .toList();
    // Assez de hauteur pour afficher les onglets Général / Projet ? (sinon,
    // en paysage sur téléphone, on bascule via le titre de la conversation).
    final availableHeight = MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    final shortViewport = availableHeight < 300;
    final roomy =
        MediaQuery.sizeOf(context).height >= 520 && availableHeight >= 400;
    final unread = ref.watch(chatUnreadByConversationProvider);
    final conversationKey = chatConversationKey(isGeneral ? null : project?.id);
    final projectUnread = unread.entries
        .where((e) => e.key != 'general')
        .fold<int>(0, (sum, e) => sum + e.value);

    return ProjectModuleScaffold(
      backgroundColor: wa.wallpaper,
      appBar: _buildAppBar(
        context,
        isGeneral: isGeneral,
        projectName: project?.name,
        roomy: roomy,
        shortViewport: shortViewport,
        generalUnread: unread['general'] ?? 0,
        projectUnread: projectUnread,
      ),
      body: Column(
        children: [
          if (!noProject &&
              _filtering &&
              MediaQuery.viewInsetsOf(context).bottom == 0)
            _buildMessageFilters(),
          if (!noProject && _hasMessageFilters && !shortViewport)
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        messagesAsync.hasValue
                            ? '${_filterMessages(messagesAsync.value!, profile?.id).length} '
                                'sur ${messagesAsync.value!.length} messages'
                            : 'Filtrage de la conversation',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      constraints:
                          const BoxConstraints(minWidth: 36, minHeight: 32),
                      padding: const EdgeInsets.all(6),
                      tooltip: 'Réinitialiser les filtres du chat',
                      icon: const Icon(Icons.filter_alt_off_outlined, size: 20),
                      onPressed: _resetMessageFilters,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: noProject
                ? _NoProjectPanel(
                    onOpenGeneral: _openGeneral,
                    onChooseProject: _openConversationPicker,
                  )
                : _buildMessages(
                    wa,
                    messagesAsync,
                    myId: profile?.id,
                    isGeneral: isGeneral,
                    projectName: project?.name,
                    conversationKey: conversationKey,
                  ),
          ),
          if (!noProject) _buildComposer(wa, recipients),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    BuildContext context, {
    required bool isGeneral,
    required String? projectName,
    required bool roomy,
    required bool shortViewport,
    required int generalUnread,
    required int projectUnread,
  }) {
    final theme = Theme.of(context);
    final onBar = theme.appBarTheme.foregroundColor ?? Colors.white;
    final barColor = theme.appBarTheme.backgroundColor ?? theme.primaryColor;

    if (_searching) {
      return AppBar(
        toolbarHeight: shortViewport ? 44 : null,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Fermer la recherche',
          onPressed: _closeSearch,
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          cursorColor: onBar,
          style: TextStyle(color: onBar, fontSize: 17),
          onChanged: (value) => setState(() => _search = value),
          decoration: InputDecoration(
            hintText: 'Rechercher dans la conversation…',
            hintStyle: TextStyle(color: onBar.withValues(alpha: 0.7)),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (_hasMessageFilters && shortViewport)
            IconButton(
              tooltip: 'Réinitialiser les filtres du chat',
              icon: const Icon(Icons.filter_alt_off_outlined),
              onPressed: _resetMessageFilters,
            ),
          IconButton(
            icon:
                Icon(_filtering ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: 'Filtres des messages',
            onPressed: _toggleMessageFilters,
          ),
          if (_search.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Effacer',
              onPressed: () {
                _searchController.clear();
                setState(() => _search = '');
              },
            ),
        ],
      );
    }

    final title = isGeneral ? 'Chat général' : (projectName ?? 'Chat projet');
    final subtitle =
        isGeneral ? "Toute l'équipe · hors projet" : 'Conversation du projet';

    return AppBar(
      toolbarHeight: shortViewport ? 44 : null,
      titleSpacing: 8,
      title: Semantics(
        button: true,
        label: 'Changer de conversation',
        child: InkWell(
          onTap: _openConversationPicker,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: onBar.withValues(alpha: 0.18),
                  child: Icon(
                    isGeneral ? Icons.groups_rounded : Icons.apartment_rounded,
                    color: onBar,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: onBar,
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: onBar.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.expand_more, color: onBar.withValues(alpha: 0.9)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_hasMessageFilters && shortViewport)
          IconButton(
            tooltip: 'Réinitialiser les filtres du chat',
            icon: const Icon(Icons.filter_alt_off_outlined),
            onPressed: _resetMessageFilters,
          ),
        IconButton(
          icon: Icon(
              _filtering || _contentFilter != 'all' || _authorFilter != 'all'
                  ? Icons.filter_alt
                  : Icons.filter_alt_outlined),
          tooltip: 'Filtres des messages',
          onPressed: _toggleMessageFilters,
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Rechercher',
          onPressed: () => setState(() => _searching = true),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
          onPressed: _refresh,
        ),
      ],
      bottom: roomy
          ? PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: _ConversationPill(
                        icon: Icons.groups_rounded,
                        label: 'Général',
                        badge: isGeneral ? 0 : generalUnread,
                        selected: isGeneral,
                        onBar: onBar,
                        barColor: barColor,
                        onTap: _openGeneral,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ConversationPill(
                        icon: Icons.apartment_rounded,
                        label: projectName == null
                            ? 'Projet'
                            : 'Projet · $projectName',
                        badge: isGeneral ? projectUnread : 0,
                        selected: !isGeneral,
                        onBar: onBar,
                        barColor: barColor,
                        onTap: () {
                          if (isGeneral) {
                            ref
                                .read(chatConversationProvider.notifier)
                                .open(ChatConversation.project);
                            _jumpToBottom();
                          } else {
                            _openConversationPicker();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildMessages(
    _WaColors wa,
    AsyncValue<List<ChatMessage>> messagesAsync, {
    required String? myId,
    required bool isGeneral,
    required String? projectName,
    required String conversationKey,
  }) {
    return messagesAsync.when(
      data: (all) {
        _scheduleMarkRead(all, myId);
        _scheduleMarkSeen(all, conversationKey);

        final messages = _filterMessages(all, myId);

        if (messages.isEmpty) {
          return _ChatNotice(
            wa: wa,
            icon: _hasMessageFilters ? Icons.search_off : Icons.forum_outlined,
            text: _hasMessageFilters
                ? 'Aucun message ne correspond aux filtres de cette conversation.'
                : isGeneral
                    ? "Chat général de l'équipe.\nLes messages envoyés ici sont "
                        'visibles par toute l’entreprise et ne sont rattachés '
                        'à aucun projet.'
                    : 'Aucun message pour ${projectName ?? 'ce projet'}.\n'
                        'Écrivez le premier message de la conversation.',
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxBubble =
                (constraints.maxWidth * 0.80).clamp(160.0, 560.0).toDouble();

            return Stack(
              children: [
                ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final index = messages.length - 1 - i;
                    final message = messages[index];
                    final previous = index > 0 ? messages[index - 1] : null;
                    final showDate = previous == null ||
                        !_sameDay(previous.createdAt, message.createdAt);
                    final firstOfGroup =
                        showDate || previous.senderId != message.senderId;
                    final isMine = myId != null && message.senderId == myId;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showDate)
                          _DateChip(wa: wa, date: message.createdAt),
                        _MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          isMine: isMine,
                          myId: myId,
                          firstOfGroup: firstOfGroup,
                          showAuthor: !isMine && firstOfGroup,
                          maxWidth: maxBubble,
                          wa: wa,
                        ),
                      ],
                    );
                  },
                ),
                if (_showJumpToBottom)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Material(
                      color: wa.pill,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: IconButton(
                        tooltip: 'Derniers messages',
                        icon: Icon(
                          Icons.keyboard_double_arrow_down,
                          color: wa.meta,
                        ),
                        onPressed: _jumpToBottom,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ChatNotice(
        wa: wa,
        icon: Icons.error_outline,
        text: 'Erreur chat : $error',
      ),
    );
  }

  Widget _buildComposer(_WaColors wa, List<SettingsUserEntry> recipients) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_recipientId != null)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: wa.composer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: wa.accent, width: 4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: wa.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Message privé à ${_recipientName ?? 'Utilisateur'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: wa.text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Envoyer à tout le monde',
                      icon: Icon(Icons.close, size: 20, color: wa.meta),
                      onPressed: () => setState(() {
                        _recipientId = null;
                        _recipientName = null;
                      }),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(
                      color: wa.composer,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 1.5,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          tooltip: 'Message privé',
                          icon: Icon(
                            _recipientId == null
                                ? Icons.person_add_alt_1_outlined
                                : Icons.lock_person,
                            color: _recipientId == null ? wa.meta : wa.accent,
                          ),
                          onPressed: _sending || recipients.isEmpty
                              ? null
                              : () => _pickRecipient(recipients),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _composerFocus,
                            enabled: !_recording,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            cursorColor: wa.accent,
                            style: TextStyle(color: wa.text, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: _recording
                                  ? 'Enregistrement audio…'
                                  : 'Message',
                              hintStyle: TextStyle(color: wa.meta),
                              filled: false,
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 13),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Joindre un fichier',
                          icon: Transform.rotate(
                            angle: -0.7,
                            child: Icon(Icons.attach_file, color: wa.meta),
                          ),
                          onPressed:
                              _sending || _recording ? null : _openAttachMenu,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _messageController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    final IconData icon;
                    final String tooltip;
                    if (_recording) {
                      icon = Icons.stop_rounded;
                      tooltip = "Arrêter et envoyer l'audio";
                    } else if (hasText) {
                      icon = Icons.send_rounded;
                      tooltip = 'Envoyer';
                    } else {
                      icon = Icons.mic_rounded;
                      tooltip = 'Message vocal';
                    }

                    return _RoundActionButton(
                      color: _recording ? const Color(0xFFE53935) : wa.accent,
                      icon: icon,
                      tooltip: tooltip,
                      busy: _sending,
                      onPressed: _sending
                          ? null
                          : (hasText && !_recording
                              ? _sendText
                              : _toggleRecord),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationPill extends StatelessWidget {
  const _ConversationPill({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onBar,
    required this.barColor,
    required this.onTap,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final int badge;
  final bool selected;
  final Color onBar;
  final Color barColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? barColor : onBar;

    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? onBar : onBar.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge > 0) ...[
                  const SizedBox(width: 6),
                  UnreadBubble(count: badge),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.unread = 0,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int unread;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      selected: selected,
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Icon(icon, color: scheme.primary),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: unread > 0
          ? UnreadBubble(count: unread)
          : selected
              ? Icon(Icons.check_circle, color: scheme.primary)
              : null,
      onTap: onTap,
    );
  }
}

class _NoProjectPanel extends StatelessWidget {
  const _NoProjectPanel({
    required this.onOpenGeneral,
    required this.onChooseProject,
  });

  final VoidCallback onOpenGeneral;
  final VoidCallback onChooseProject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.apartment_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aucun projet sélectionné',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Choisissez un projet pour ouvrir sa conversation, ou "
                    "utilisez le chat général de l'équipe.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: onOpenGeneral,
                    icon: const Icon(Icons.groups_rounded),
                    label: const Text('Ouvrir le chat général'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: onChooseProject,
                    icon: const Icon(Icons.apartment_rounded),
                    label: const Text('Choisir un projet'),
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

/// Encart d'information centré sur le fond de discussion (vide, erreur…).
class _ChatNotice extends StatelessWidget {
  const _ChatNotice({
    required this.wa,
    required this.icon,
    required this.text,
  });

  final _WaColors wa;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: wa.pill,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: wa.pillText),
                const SizedBox(height: 8),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: wa.pillText, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({required this.wa, required this.date});

  final _WaColors wa;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: wa.pill,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          _dayLabel(date),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: wa.pillText,
          ),
        ),
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.color,
    required this.icon,
    required this.tooltip,
    required this.busy,
    required this.onPressed,
  });

  final Color color;
  final IconData icon;
  final String tooltip;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: color,
            shape: const CircleBorder(),
            elevation: 1,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(icon, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Petite pointe de bulle (comme WhatsApp) sur le premier message d'un groupe.
class _BubbleTailPainter extends CustomPainter {
  const _BubbleTailPainter({required this.color, required this.isMine});

  final Color color;
  final bool isMine;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (isMine) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(0, size.height)
        ..close();
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, 0)
        ..lineTo(size.width, size.height)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isMine != isMine;
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.myId,
    required this.firstOfGroup,
    required this.showAuthor,
    required this.maxWidth,
    required this.wa,
  });

  final ChatMessage message;
  final bool isMine;
  final String? myId;
  final bool firstOfGroup;
  final bool showAuthor;
  final double maxWidth;
  final _WaColors wa;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le message'),
        content: const Text('Ce message sera supprimé pour tout le monde.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: PremiumButtonStyles.destructive(context),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(chatRepositoryProvider).deleteMessage(message);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur suppression : $error')),
      );
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: message.textContent);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 5,
          decoration: const InputDecoration(hintText: 'Nouveau texte'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newText == null || newText.isEmpty || newText == message.textContent) {
      return;
    }

    try {
      await ref
          .read(chatRepositoryProvider)
          .editText(messageId: message.id, newText: newText);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur modification : $error')),
      );
    }
  }

  /// Appui long (ou clic droit) sur un de ses messages : modifier/supprimer.
  void _showActions(BuildContext context, WidgetRef ref) {
    if (!isMine || message.id.isEmpty) {
      return;
    }
    final error = Theme.of(context).colorScheme.error;

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isText)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _edit(context, ref);
                },
              ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: error),
              title: Text('Supprimer', style: TextStyle(color: error)),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _delete(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final background = isMine ? wa.outgoing : wa.incoming;
    final metaColor = isMine ? wa.metaOutgoing : wa.meta;
    // Accusé réel uniquement : messages privés (lecture enregistrée en base).
    final showReceipt = isMine && message.recipientId != null;
    final metaWidth =
        38.0 + (message.isEdited ? 52 : 0) + (showReceipt ? 20 : 0);

    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Text(
            'modifié ',
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: metaColor,
            ),
          ),
        Text(
          _timeLabel(message.createdAt),
          style: TextStyle(fontSize: 11.5, color: metaColor),
        ),
        if (showReceipt) ...[
          const SizedBox(width: 3),
          Icon(
            message.isRead ? Icons.done_all : Icons.done,
            size: 16,
            color: message.isRead ? wa.readTick : metaColor,
          ),
        ],
      ],
    );

    final nameParts = message.senderName.split(' · ');
    final authorName = nameParts.first;
    final authorRole =
        nameParts.length > 1 ? nameParts.sublist(1).join(' · ') : null;

    final String? privateLabel;
    if (message.recipientId == null) {
      privateLabel = null;
    } else if (!isMine && message.recipientId == myId) {
      privateLabel = 'Privé · pour vous';
    } else {
      privateLabel = 'Privé · à ${message.recipientName ?? 'Utilisateur'}';
    }

    final Widget content;
    if (message.isText) {
      content = Stack(
        children: [
          Text.rich(
            TextSpan(
              text: message.textContent,
              children: [
                // Réserve la place de l'heure en fin de dernière ligne.
                WidgetSpan(child: SizedBox(width: metaWidth, height: 12)),
              ],
            ),
            style: TextStyle(fontSize: 15.5, height: 1.3, color: wa.text),
          ),
          Positioned(right: 0, bottom: 0, child: meta),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isImage && message.hasAttachment)
            _ImageAttachment(message: message)
          else if (message.isFile && message.hasAttachment)
            _FileAttachment(message: message)
          else if (message.isAudio && message.hasAttachment)
            _AudioAttachment(message: message)
          else
            Text(
              'Pièce jointe indisponible',
              style: TextStyle(fontStyle: FontStyle.italic, color: metaColor),
            ),
          const SizedBox(height: 3),
          meta,
        ],
      );
    }

    const radius = Radius.circular(8);
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: message.isImage
          ? const EdgeInsets.all(4)
          : const EdgeInsets.fromLTRB(9, 6, 9, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: !isMine && firstOfGroup ? Radius.zero : radius,
          topRight: isMine && firstOfGroup ? Radius.zero : radius,
          bottomLeft: radius,
          bottomRight: radius,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x21000000),
            blurRadius: 0.6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: wa.text),
        child: IconTheme.merge(
          data: IconThemeData(color: wa.text),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showAuthor)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    message.isImage ? 5 : 0,
                    message.isImage ? 2 : 0,
                    0,
                    2,
                  ),
                  child: Text.rich(
                    TextSpan(
                      text: authorName,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: wa.authorColor(message.senderId),
                      ),
                      children: [
                        if (authorRole != null)
                          TextSpan(
                            text: '  ~ $authorRole',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: wa.meta,
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (privateLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 12, color: metaColor),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          privateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: metaColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              content,
            ],
          ),
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(
        top: firstOfGroup ? 6 : 2,
        left: isMine ? 48 : 8,
        right: isMine ? 8 : 48,
      ),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showActions(context, ref),
          onSecondaryTap: () => _showActions(context, ref),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              bubble,
              if (firstOfGroup)
                Positioned(
                  top: 0,
                  right: isMine ? -7 : null,
                  left: isMine ? null : -7,
                  child: CustomPaint(
                    size: const Size(8, 10),
                    painter: _BubbleTailPainter(
                      color: background,
                      isMine: isMine,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageAttachment extends ConsumerStatefulWidget {
  const _ImageAttachment({
    required this.message,
  });

  final ChatMessage message;

  @override
  ConsumerState<_ImageAttachment> createState() => _ImageAttachmentState();
}

class _ImageAttachmentState extends ConsumerState<_ImageAttachment> {
  late final Future<String> _urlFuture =
      ref.read(chatRepositoryProvider).createSignedUrl(
            bucketId: widget.message.bucketId!,
            filePath: widget.message.filePath!,
          );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _urlFuture,
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
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              url,
              height: 220,
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
    final textColor = DefaultTextStyle.of(context).style.color;

    return Material(
      color: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final url = await ref.read(chatRepositoryProvider).createSignedUrl(
                bucketId: message.bucketId!,
                filePath: message.filePath!,
              );

          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: 30,
                color: textColor?.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message.fileName ?? 'Fichier',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
  late final Future<String> _urlFuture = _loadUrl();

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

  Future<String> _loadUrl() {
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
      future: _urlFuture,
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
