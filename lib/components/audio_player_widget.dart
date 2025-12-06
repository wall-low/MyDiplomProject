import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

// УДАЛЕНО: import 'package:cloud_firestore/cloud_firestore.dart';
// Мигрировали на PocketBase, используем DateTime вместо Timestamp

class ChatAudioPlayer extends StatefulWidget {
  final String url;
  final bool isCurrentUser;
  final DateTime? timestamp; // ИЗМЕНЕНО: Timestamp → DateTime

  const ChatAudioPlayer({
    super.key,
    required this.url,
    required this.isCurrentUser,
    this.timestamp,
  });

  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _player.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.defaultToSpeaker,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );

    _player.onDurationChanged.listen((d) {
      setState(() => _duration = d);
    });

    _player.onPositionChanged.listen((p) {
      setState(() => _position = p);
    });

    _player.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == PlayerState.playing;
        if (_isPlaying) {
          _rippleController.repeat();
        } else {
          _rippleController.stop();
          _rippleController.reset();
        }
      });
    });
  }

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ИЗМЕНЕНО: Timestamp → DateTime
  String _formatTime(DateTime? timestamp) {
    if (timestamp == null) return '';

    // БЫЛО: final date = timestamp.toDate();
    // СТАЛО: timestamp уже DateTime, не нужна конвертация
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bubbleColor = widget.isCurrentUser
        ? scheme.primary
        : scheme.secondaryContainer;

    final iconColor = widget.isCurrentUser
        ? scheme.onPrimary
        : scheme.primary;

    final textColor = widget.isCurrentUser
        ? scheme.onPrimary
        : scheme.onSurface;

    final progressColor = widget.isCurrentUser
        ? scheme.onPrimary
        : scheme.primary;

    return Align(
      alignment: widget.isCurrentUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 12),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Основной контент (кнопка + волны)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кнопка с пульсирующей анимацией
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Пульсирующие круги при воспроизведении
                    if (_isPlaying)
                      AnimatedBuilder(
                        animation: _rippleController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: RipplePainter(
                              animation: _rippleController,
                              color: iconColor,
                            ),
                            size: const Size(50, 50),
                          );
                        },
                      ),

                    // Кнопка
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: widget.isCurrentUser
                              ? Colors.white.withValues(alpha: 0.25)
                              : scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: RotationTransition(
                                turns: animation,
                                child: child,
                              ),
                            );
                          },
                          child: Icon(
                            _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            key: ValueKey(_isPlaying),
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Прогресс и волны
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Анимированные звуковые волны
                      SizedBox(
                        height: 24,
                        child: AnimatedBuilder(
                          animation: _rippleController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: SoundWavesPainter(
                                animation: _rippleController,
                                color: progressColor,
                                isPlaying: _isPlaying,
                              ),
                              size: const Size(double.infinity, 24),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Прогресс бар
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 3,
                          child: LinearProgressIndicator(
                            value: _duration.inSeconds == 0
                                ? 0
                                : _position.inSeconds / _duration.inSeconds,
                            color: progressColor,
                            backgroundColor: widget.isCurrentUser
                                ? Colors.white.withValues(alpha: 0.25)
                                : scheme.surface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Длительность аудио
                      Text(
                        _position.inSeconds > 0
                            ? _formatDuration(_duration - _position)
                            : _formatDuration(_duration),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),

            // Время отправки (как в текстовых сообщениях)
            if (widget.timestamp != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  _formatTime(widget.timestamp),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Пульсирующие круги вокруг кнопки
class RipplePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  RipplePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Рисуем 2 пульсирующих круга с разной задержкой
    for (int i = 0; i < 2; i++) {
      final progress = (animation.value + (i * 0.5)) % 1.0;
      final radius = 20 + (progress * 15);
      final opacity = 1.0 - progress;

      paint.color = color.withValues(alpha: opacity * 0.4);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(RipplePainter oldDelegate) => true;
}

// Анимированные звуковые волны
class SoundWavesPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final bool isPlaying;

  SoundWavesPainter({
    required this.animation,
    required this.color,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: isPlaying ? 0.8 : 0.3)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const barCount = 20;
    final barWidth = size.width / barCount;
    final centerY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final x = i * barWidth + barWidth / 2;

      // Создаем волнообразный паттерн
      final wave = math.sin((i / barCount) * math.pi * 2 +
          (isPlaying ? animation.value * math.pi * 4 : 0));

      final baseHeight = size.height * 0.2;
      final maxHeight = size.height * 0.7;
      final height = baseHeight + (wave.abs() * (maxHeight - baseHeight));

      final top = centerY - height / 2;
      final bottom = centerY + height / 2;

      canvas.drawLine(
        Offset(x, top),
        Offset(x, bottom),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(SoundWavesPainter oldDelegate) {
    return oldDelegate.animation != animation ||
        oldDelegate.isPlaying != isPlaying;
  }
}