import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/formatters.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../models/chat.dart';
import '../../services/chat_repository.dart';
import '../../widgets/common.dart';

const _maxLength = 4000;
const _counterThreshold = 3500;
const _contentMaxWidth = 720.0;

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _showJumpToEnd = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Marque la conversation comme lue à l'ouverture et à chaque nouveau
    // message reçu tant que l'écran est affiché.
    ref.listenManual<AsyncValue<Conversation?>>(
      conversationProvider(widget.conversationId),
      (_, next) {
        final conversation = next.valueOrNull;
        final uid = ref.read(currentUidProvider);
        if (conversation != null && uid != null && conversation.isUnreadFor(uid)) {
          guard(() => ref.read(chatRepositoryProvider).markRead(conversation.id, uid));
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _showJumpToEnd.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _showJumpToEnd.value = _scroll.offset > 240;
  }

  bool get _nearBottom => !_scroll.hasClients || _scroll.offset < 120;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final uid = ref.read(currentUidProvider);
    if (text.isEmpty || uid == null) return;
    if (text.length > _maxLength) {
      showMessage('Message trop long ($_maxLength caractères maximum).');
      return;
    }
    _controller.clear();
    _scrollToBottom();
    final ok = await guard(
      () => ref.read(chatRepositoryProvider).sendMessage(widget.conversationId, uid, text),
    );
    if (!ok && mounted && _controller.text.isEmpty) _controller.text = text;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        !HardwareKeyboard.instance.isShiftPressed &&
        !_controller.value.composing.isValid) {
      _send();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final uid = ref.watch(currentUidProvider) ?? '';
    final conversation = ref.watch(conversationProvider(widget.conversationId)).valueOrNull;
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final otherName = conversation?.otherName(uid) ?? 'Interlocuteur';

    // Défilement automatique : à l'envoi, ou à la réception si l'utilisateur
    // est déjà en bas de la conversation.
    ref.listen<AsyncValue<List<Message>>>(messagesProvider(widget.conversationId), (prev, next) {
      final old = prev?.valueOrNull;
      final list = next.valueOrNull;
      if (list == null || list.isEmpty) return;
      final isNew = old == null || old.isEmpty || old.first.id != list.first.id;
      if (isNew && (list.first.senderId == uid || _nearBottom)) _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(conversation?.otherName(uid) ?? 'Discussion'),
        actions: [
          if (conversation != null)
            IconButton(
              tooltip: 'Voir le profil',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push('/user/${conversation.otherId(uid)}'),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          child: Column(
            children: [
              Expanded(
                child: AsyncValueWidget(
                  value: messages,
                  onRetry: () => ref.invalidate(messagesProvider(widget.conversationId)),
                  data: (list) {
                    if (list.isEmpty) {
                      return const EmptyState(
                        icon: Icons.waving_hand_outlined,
                        message: 'Démarrez la conversation !',
                      );
                    }
                    return Stack(
                      children: [
                        ListView.builder(
                          controller: _scroll,
                          reverse: true,
                          padding: Gaps.screenPadding,
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final m = list[i];
                            // list[0] est le plus récent (liste inversée).
                            final newer = i > 0 ? list[i - 1] : null;
                            final older = i < list.length - 1 ? list[i + 1] : null;
                            final joinsOlder = older != null &&
                                older.senderId == m.senderId &&
                                _sameDay(older.createdAt, m.createdAt);
                            final joinsNewer = newer != null &&
                                newer.senderId == m.senderId &&
                                _sameDay(newer.createdAt, m.createdAt);
                            final newDay = older == null || !_sameDay(older.createdAt, m.createdAt);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (newDay) _DateSeparator(date: m.createdAt),
                                _MessageBubble(
                                  message: m,
                                  isMine: m.senderId == uid,
                                  senderName: otherName,
                                  joinsOlder: joinsOlder,
                                  joinsNewer: joinsNewer,
                                ),
                              ],
                            );
                          },
                        ),
                        Positioned(
                          right: 12,
                          bottom: 12,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: _showJumpToEnd,
                            builder: (_, show, __) => show
                                ? IconButton.filledTonal(
                                    tooltip: 'Aller au dernier message',
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(48, 48),
                                      elevation: 2,
                                      backgroundColor: scheme.secondaryContainer,
                                      foregroundColor: scheme.onSecondaryContainer,
                                    ),
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                    onPressed: _scrollToBottom,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _Composer(controller: _controller, onSend: _send, onKey: _onKey),
            ],
          ),
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _hhmm(DateTime d) => DateFormat('HH:mm', 'fr_FR').format(d);

String _dayLabel(DateTime d) {
  final now = DateTime.now();
  if (_sameDay(d, now)) return "Aujourd'hui";
  if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Hier';
  return formatDate(d);
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.onKey});

  final TextEditingController controller;
  final VoidCallback onSend;
  final FocusOnKeyEventCallback onKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    OutlineInputBorder pill(Color color, [double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: color, width: width),
        );
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Focus(
                  onKeyEvent: onKey,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, _) {
                      final length = value.text.trim().length;
                      final showCounter = length >= _counterThreshold;
                      return TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        decoration: InputDecoration(
                          hintText: 'Votre message…',
                          isDense: true,
                          fillColor: scheme.surface,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          border: pill(scheme.outline),
                          enabledBorder: pill(scheme.outline),
                          focusedBorder: pill(scheme.primary, 2),
                          counterText: showCounter ? '$length / $_maxLength' : '',
                          counterStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: length > _maxLength
                                    ? scheme.error
                                    : scheme.onSurfaceVariant,
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Gaps.sm,
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: IconButton.filled(
                  tooltip: 'Envoyer',
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _dayLabel(date),
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.senderName,
    required this.joinsOlder,
    required this.joinsNewer,
  });

  final Message message;
  final bool isMine;
  final String senderName;

  /// Le message précédent (au-dessus) est du même expéditeur, le même jour.
  final bool joinsOlder;

  /// Le message suivant (en dessous) est du même expéditeur, le même jour.
  final bool joinsNewer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isMine ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final foreground = isMine ? scheme.onPrimaryContainer : scheme.onSurface;
    final timeColor = scheme.onSurfaceVariant; // l'heure est hors bulle, sur le fond
    const big = Radius.circular(18);
    const small = Radius.circular(4);
    // Les coins du côté de l'expéditeur se resserrent entre messages groupés.
    final sideTop = joinsOlder ? small : big;
    final sideBottom = joinsNewer ? small : big;
    final radius = isMine
        ? BorderRadius.only(
            topLeft: big, topRight: sideTop, bottomLeft: big, bottomRight: sideBottom)
        : BorderRadius.only(
            topLeft: sideTop, topRight: big, bottomLeft: sideBottom, bottomRight: big);
    final time = _hhmm(message.createdAt);
    final showTime = !joinsNewer;
    final maxWidth = (MediaQuery.sizeOf(context).width.clamp(0.0, _contentMaxWidth) * 0.78);

    return Semantics(
      container: true,
      label: '${isMine ? 'Vous' : senderName}, $time : ${message.text}',
      excludeSemantics: true,
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.only(top: joinsOlder ? 2 : 8, bottom: joinsNewer ? 0 : 2),
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(color: background, borderRadius: radius),
                  child: SelectableText(
                    message.text,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: foreground, height: 1.35),
                  ),
                ),
                if (showTime)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                    child: Text(
                      time,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: timeColor),
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
