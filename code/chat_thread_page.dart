import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_strings.dart';
import '../painters/pill_painter.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../widgets/klipy_picker.dart';

/// Check if a message body is a GIF/sticker URL from Klipy.
bool _isGifUrl(String body) {
  final trimmed = body.trim();
  return trimmed.startsWith('https://') &&
      (trimmed.endsWith('.gif') || trimmed.contains('media.tenor.com') || trimmed.contains('klipy.com'));
}

class ChatThreadPage extends StatefulWidget {
  final String pairProgressId;
  final String otherUserId;
  final String otherUsername;
  final String? otherAvatarUrl;

  const ChatThreadPage({
    super.key,
    required this.pairProgressId,
    required this.otherUserId,
    required this.otherUsername,
    this.otherAvatarUrl,
  });

  @override
  State<ChatThreadPage> createState() => _ChatThreadPageState();
}

class _ChatThreadPageState extends State<ChatThreadPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;
  late final String _myId;
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser!.id;
    _loadMessages();
    _subscribe();
  }

  Future<void> _loadMessages() async {
    final msgs = await ChatService.loadMessages(widget.pairProgressId);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _subscribe() {
    _channel = ChatService.subscribeToMessages(
      widget.pairProgressId,
      (msg) {
        if (!mounted) return;
        // Skip if we already have it (optimistic insert)
        final id = msg['id'];
        if (_messages.any((m) => m['id'] == id)) return;
        setState(() => _messages.add(msg));
        _scrollToBottom();
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    // Optimistic insert
    final optimistic = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'pair_progress_id': widget.pairProgressId,
      'sender_id': _myId,
      'body': text,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final real = await ChatService.sendMessage(widget.pairProgressId, text);
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == optimistic['id']);
        if (idx != -1) _messages[idx] = real;
      });
    } catch (_) {
      // Remove failed message
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m['id'] == optimistic['id']);
      });
    }
  }

  Future<void> _pickGif() async {
    _focusNode.unfocus();
    final url = await showKlipyPicker(context);
    if (url == null || !mounted) return;

    // Send the GIF URL as the message body
    final optimistic = {
      'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'pair_progress_id': widget.pairProgressId,
      'sender_id': _myId,
      'body': url,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    setState(() => _messages.add(optimistic));
    _scrollToBottom();

    try {
      final real = await ChatService.sendMessage(widget.pairProgressId, url);
      if (!mounted) return;
      setState(() {
        final idx = _messages.indexWhere((m) => m['id'] == optimistic['id']);
        if (idx != -1) _messages[idx] = real;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m['id'] == optimistic['id']);
      });
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomSafe = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Transform.translate(
            offset: Offset(0, -_scrollOffset * 0.3),
            child: const PillBackground(),
          ),
          // Messages — full height, padding at bottom so content scrolls behind input
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.iconColor))
                      : GestureDetector(
                          onTap: () => _focusNode.unfocus(),
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              setState(() => _scrollOffset = _scrollController.offset);
                              return false;
                            },
                            child: ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.only(
                                left: 16,
                                right: 16,
                                top: 12,
                                bottom: (bottomInset > 0 ? bottomInset : bottomSafe) + 70,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) => _buildBubble(i),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          // Fade behind input bar row
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: (bottomInset > 0 ? bottomInset : bottomSafe) + 90,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppTheme.bg.withValues(alpha: 0),
                      AppTheme.bg,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Input bar pinned to bottom, no background
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : bottomSafe),
              child: _buildInputBar(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(int index) {
    final msg = _messages[index];
    final isMine = msg['sender_id'] == _myId;
    final body = msg['body'] as String;

    // Show time gap between messages > 10 min apart
    Widget? timeHeader;
    if (index == 0 || _shouldShowTime(index)) {
      final ts = DateTime.tryParse(msg['created_at'] ?? '');
      if (ts != null) {
        timeHeader = Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Center(
            child: Text(
              _formatTime(ts),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.fadedAccent.withValues(alpha: 0.6),
              ),
            ),
          ),
        );
      }
    }

    final isGif = _isGifUrl(body);

    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.only(bottom: 4),
        child: isGif
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: body.trim(),
                  width: 180,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => CustomPaint(
                    painter: _BubblePainter(
                      isMine: isMine,
                      seed: msg['id'].hashCode,
                    ),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Text('GIF'),
                    ),
                  ),
                ),
              )
            : CustomPaint(
                painter: _BubblePainter(
                  isMine: isMine,
                  seed: msg['id'].hashCode,
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    body,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isMine ? Colors.white : AppTheme.text,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
      ),
    );

    if (timeHeader != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [timeHeader, bubble],
      );
    }
    return bubble;
  }

  bool _shouldShowTime(int index) {
    final curr = DateTime.tryParse(_messages[index]['created_at'] ?? '');
    final prev = DateTime.tryParse(_messages[index - 1]['created_at'] ?? '');
    if (curr == null || prev == null) return false;
    return curr.difference(prev).inMinutes > 10;
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inDays == 0) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '${AppStrings.yesterday} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return '${local.day}/${local.month} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: CustomPaint(
              painter: _SendButtonPainter(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: CustomPaint(
              painter: _InputPillPainter(),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text,
                  ),
                  decoration: InputDecoration(
                    hintText: AppStrings.messageHint,
                    hintStyle: TextStyle(
                      color: AppTheme.fadedAccent.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _pickGif,
            child: CustomPaint(
              painter: _GifButtonPainter(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(
                    'GIF',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _send,
            child: CustomPaint(
              painter: _SendButtonPainter(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Painters ──

class _BubblePainter extends CustomPainter {
  final bool isMine;
  final int seed;
  _BubblePainter({required this.isMine, required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = handDrawnPillPath(rect, seed: seed);

    // Shadow
    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = (isMine ? AppTheme.gradient1 : AppTheme.stroke)
            .withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Fill
    if (isMine) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: AppTheme.activeGradient,
          ).createShader(rect)
          ..style = PaintingStyle.fill,
      );
    } else {
      canvas.drawPath(
        path,
        Paint()
          ..color = AppTheme.card
          ..style = PaintingStyle.fill,
      );
    }

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = isMine ? AppTheme.strokeHard : AppTheme.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BubblePainter old) =>
      old.isMine != isMine || old.seed != seed;
}

class _InputPillPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = handDrawnPillPath(rect, seed: 8888);

    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = AppTheme.pillShadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.card
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SendButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = handDrawnPillPath(rect, seed: 9999);

    canvas.drawPath(
      path.shift(const Offset(0, 3)),
      Paint()
        ..color = AppTheme.gradient1.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: AppTheme.activeGradient,
        ).createShader(rect)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.strokeHard
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GifButtonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = handDrawnPillPath(rect, seed: 7777);

    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = AppTheme.fadedAccent.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [AppTheme.fadedAccent, AppTheme.iconColor],
        ).createShader(rect)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.strokeHard
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
