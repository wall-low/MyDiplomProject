import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart' as fs;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:p7/components/chat_bubble.dart';
import 'package:p7/components/my_text_field.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/chat_service.dart';
import '../components/audio_player_widget.dart';
import '../models/messenge.dart';

class ChatPage extends StatefulWidget {
  final String receiverName; // ИЗМЕНЕНО: username → name
  final String receiverID;

  const ChatPage({
    super.key,
    required this.receiverName,
    required this.receiverID,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _hasTextNotifier = ValueNotifier(false);

  final ChatService _chatService = ChatService();
  final Auth _auth = Auth();
  final fs.FlutterSoundRecorder _recorder = fs.FlutterSoundRecorder();

  bool _isRecording = false;
  final Map<String, double> _uploadingFiles = {};
  final Set<String> _cancelledUploads = {};
  // ИЗМЕНЕНО: List<DocumentSnapshot> → List<Message>
  //
  // PocketBase возвращает List<Message> вместо QuerySnapshot
  List<Message> _cachedMessages = [];

  bool _isUserScrolling = false;
  bool _isFirstLoad = true;
  int _previousMessageCount = 0;
  int _newMessagesCount = 0;

  static final Map<String, double> _scrollPositions = {};
  String get _chatKey => '${_auth.getCurrentUid()}_${widget.receiverID}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller.addListener(() {
      _hasTextNotifier.value = _controller.text.trim().isNotEmpty;
    });

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_isUserScrolling) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isUserScrolling) _scrollToBottom(animate: false);
        });
      }
    });

    _scrollController.addListener(_onScroll);
    _markMessagesAsRead();
    _initializeRecorder();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 100.0;

    if (maxScroll - currentScroll > threshold) {
      _isUserScrolling = true;
      _scrollPositions[_chatKey] = currentScroll;
    } else {
      _isUserScrolling = false;
      _newMessagesCount = 0;
      // Сохраняем -1 как маркер "внизу", а не удаляем позицию
      _scrollPositions[_chatKey] = -1;
    }
  }

  @override
  void dispose() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      const threshold = 100.0;

      // Сохраняем позицию: -1 если внизу, иначе реальную позицию
      if (maxScroll - currentScroll <= threshold) {
        _scrollPositions[_chatKey] = -1;
      } else if (_isUserScrolling) {
        _scrollPositions[_chatKey] = currentScroll;
      }
    }
    // Отменяем все активные загрузки
    _cancelledUploads.addAll(_uploadingFiles.keys);
    _uploadingFiles.clear();

    // НОВОЕ: Отписываемся от realtime подписок
    _chatService.unsubscribeFromMessages(_auth.getCurrentUid(), widget.receiverID);

    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _hasTextNotifier.dispose();
    _recorder.closeRecorder();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _markMessagesAsRead();
    }
  }

  Future<void> _initializeRecorder() async {
    await _recorder.openRecorder();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _chatService.markMessagesAsRead(
        _auth.getCurrentUid(),
        widget.receiverID,
      );
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (!mounted) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _focusNode.unfocus();

    try {
      await _chatService.sendMessage(widget.receiverID, text);
      if (!_isUserScrolling) _scrollToBottom(animate: false);
    } catch (e) {
      if (mounted) _showError('Ошибка отправки сообщения');
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    if (!mounted) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (pickedFile == null || !mounted) return;

    final localId = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _uploadingFiles[localId] = 0.0;
    });

    if (!_isUserScrolling) _scrollToBottom(animate: false);

    try {
      _simulateProgress(localId);

      // ✅ УПРОЩЕНО: Просто передаём локальный путь в chat_service
      // chat_service.dart сам загрузит файл в PocketBase Storage
      if (!mounted) throw Exception('Upload cancelled');

      await _chatService.sendMessageWithImage(
        receiverId: widget.receiverID,
        filePath: pickedFile.path, // ✅ Передаём локальный путь
      );

      if (!_isUserScrolling) _scrollToBottom(animate: false);
    } catch (e) {
      if (mounted) _showError('Ошибка загрузки изображения');
    } finally {
      if (mounted) {
        setState(() {
          _uploadingFiles.remove(localId);
          _cancelledUploads.remove(localId);
        });
      }
    }
  }

  void _simulateProgress(String localId) {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_cancelledUploads.contains(localId)) return;
      if (_uploadingFiles.containsKey(localId) && mounted) {
        setState(() {
          _uploadingFiles[localId] = (_uploadingFiles[localId]! + 0.1).clamp(0.0, 1.0);
        });
        if (_uploadingFiles[localId]! < 1.0) {
          _simulateProgress(localId);
        }
      }
    });
  }

  void _showImageSourceDialog() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Галерея'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Камера'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkPermission() async {
    var status = await Permission.microphone.status;

    if (status.isPermanentlyDenied) {
      if (!mounted) return false;
      final go = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Микрофон заблокирован'),
          content: const Text(
            'Доступ к микрофону постоянно запрещён.\n'
                'Откройте настройки и разрешите доступ.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Открыть настройки'),
            ),
          ],
        ),
      );

      if (go == true) await openAppSettings();
      return false;
    }

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    return status.isGranted;
  }

  Future<void> _startRecording() async {
    if (!mounted) return;
    if (!await _checkPermission()) {
      _showError('Требуется доступ к микрофону');
      return;
    }

    try {
      if (!_recorder.isRecording) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.startRecorder(
          toFile: path,
          codec: fs.Codec.aacMP4,
          bitRate: 128000,
          sampleRate: 44100,
        );

        setState(() => _isRecording = true);
      }
    } catch (e) {
      _showError('Ошибка записи: $e');
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (!mounted) return;

    String? localId;
    try {
      final result = await _recorder.stopRecorder();
      setState(() => _isRecording = false);

      if (result != null) {
        final uploadId = DateTime.now().millisecondsSinceEpoch.toString();
        localId = uploadId;
        setState(() {
          _uploadingFiles[uploadId] = 0.0;
        });

        if (!_isUserScrolling) _scrollToBottom(animate: false);
        _simulateProgress(uploadId);

        // ✅ УПРОЩЕНО: Просто передаём локальный путь в chat_service
        // chat_service.dart сам загрузит файл в PocketBase Storage
        if (mounted) {
          await _chatService.sendMessageWithAudio(
            receiverId: widget.receiverID,
            filePath: result, // ✅ Передаём локальный путь
          );
          if (!_isUserScrolling) _scrollToBottom(animate: false);
        }
      }
    } catch (e) {
      _showError('Ошибка остановки записи: $e');
    } finally {
      if (localId != null && mounted) {
        setState(() {
          _uploadingFiles.remove(localId);
          _cancelledUploads.remove(localId);
        });
      }
      if (mounted) {
        await _recorder.closeRecorder();
        await _initializeRecorder();
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients || !mounted) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    const threshold = 50.0;

    // Сбрасываем счётчик новых сообщений
    if (mounted && _newMessagesCount > 0) {
      setState(() {
        _newMessagesCount = 0;
      });
    }

    // Если уже внизу, ничего не делаем
    if (maxScroll - currentScroll <= 10.0) {
      return;
    }

    // Если близко к низу или не нужна анимация - jumpTo
    if (!animate || maxScroll - currentScroll <= threshold) {
      _scrollController.jumpTo(maxScroll);
    } else {
      // Иначе плавная анимация
      _scrollController.animateTo(
        maxScroll,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _restoreScrollPosition() {
    if (!_scrollController.hasClients || !mounted) return;

    try {
      final maxExtent = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      final savedPosition = _scrollPositions[_chatKey];

      if (savedPosition == null || savedPosition == -1) {
        // Нет сохранённой позиции или был внизу -> прокручиваем в низ
        // Проверяем что maxExtent уже рассчитан и мы еще не внизу
        if (maxExtent > 0 && (maxExtent - currentScroll > 10.0)) {
          _scrollController.jumpTo(maxExtent);
        } else if (maxExtent == 0) {
          // Если maxExtent еще 0, пробуем снова через небольшую задержку
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted && _scrollController.hasClients) {
              try {
                final maxExtent = _scrollController.position.maxScrollExtent;
                final currentScroll = _scrollController.position.pixels;
                if (maxExtent - currentScroll > 10.0) {
                  _scrollController.jumpTo(maxExtent);
                }
              } catch (e) {
                // Игнорируем если ScrollPosition еще не готов
              }
            }
          });
        }
        _isUserScrolling = false;
      } else {
        // Восстанавливаем сохранённую позицию
        final targetPosition = savedPosition < maxExtent ? savedPosition : maxExtent;
        // Проверяем что позиция действительно отличается
        if ((targetPosition - currentScroll).abs() > 1.0) {
          _scrollController.jumpTo(targetPosition);
        }
        _isUserScrolling = true;
      }
    } catch (e) {
      // Игнорируем если ScrollPosition еще не готов
      // Это может происходить при быстром переключении между чатами
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = _auth.getCurrentUid();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.receiverName, // ИЗМЕНЕНО: показываем полное имя
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Divider(
            height: 1,
            thickness: 0.5,
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
          Expanded(
            // ИЗМЕНЕНО: FutureBuilder → StreamBuilder с realtime подписками
            // ИЗМЕНЕНО: getMessages() → getMessagesStream()
            //
            // Используем realtime subscriptions через PocketBase subscribe()
            // Сообщения обновляются автоматически при изменениях в БД
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessagesStream(myId, widget.receiverID),
              builder: (ctx, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Ошибка загрузки',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snap.connectionState == ConnectionState.waiting && _cachedMessages.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                // ИЗМЕНЕНО: snap.data?.docs → snap.data
                //
                // PocketBase возвращает List<Message>, а не QuerySnapshot с docs
                _cachedMessages = snap.data ?? [];
                final currentMessageCount = _cachedMessages.length;

                if (_cachedMessages.isEmpty && _uploadingFiles.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Нет сообщений',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Начните общение!',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_isFirstLoad) {
                    // Первая загрузка - даем время на построение ListView, затем восстанавливаем позицию
                    _previousMessageCount = currentMessageCount;
                    // Дополнительная задержка чтобы ListView полностью построился
                    Future.delayed(const Duration(milliseconds: 50), () {
                      if (mounted) {
                        _restoreScrollPosition();
                        // Отключаем флаг первой загрузки только после восстановления позиции
                        _isFirstLoad = false;
                      }
                    });
                  } else if (currentMessageCount > _previousMessageCount) {
                    // Появились новые сообщения
                    final newMessagesAdded = currentMessageCount - _previousMessageCount;
                    _previousMessageCount = currentMessageCount;

                    if (!_isUserScrolling) {
                      // Пользователь внизу - прокручиваем без лишней задержки
                      if (mounted) _scrollToBottom(animate: true);
                    } else {
                      // Пользователь прокрутил вверх - показываем счётчик
                      if (mounted) {
                        setState(() {
                          _newMessagesCount += newMessagesAdded;
                        });
                      }
                    }
                  }
                });

                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _cachedMessages.length + _uploadingFiles.length,
                      itemBuilder: (_, i) {
                        if (i < _cachedMessages.length) {
                          // ИЗМЕНЕНО: Теперь _cachedMessages содержит Message объекты, не DocumentSnapshot
                          //
                          // БЫЛО:
                          // final doc = _cachedMessages[i];  // DocumentSnapshot
                          // final data = doc.data()! as Map<String, dynamic>;
                          // final msg = Message.fromMap(data);
                          //
                          // СТАЛО:
                          // final msg = _cachedMessages[i];  // уже Message!
                          final msg = _cachedMessages[i];
                          final isMine = msg.senderID == myId;

                          // ИЗМЕНЕНО: Теперь сравниваем Message объекты напрямую
                          final showDateSeparator = i == 0 ||
                              _shouldShowDateSeparator(
                                _cachedMessages[i - 1],
                                msg,
                              );

                          // ИЗМЕНЕНО: Генерируем уникальный ключ из timestamp + senderID
                          // (вместо doc.id)
                          final messageKey = '${msg.timestamp.millisecondsSinceEpoch}_${msg.senderID}';

                          return Column(
                            key: ValueKey(messageKey),
                            children: [
                              if (showDateSeparator)
                                // ИЗМЕНЕНО: timestamp уже DateTime, не нужен toDate()
                                _buildDateSeparator(msg.timestamp),
                              _buildMessage(msg, isMine, messageKey),
                            ],
                          );
                        }

                        final uploadIndex = i - _cachedMessages.length;
                        final entry = _uploadingFiles.entries.elementAt(uploadIndex);
                        return _buildUploadingMessage(entry.key, entry.value);
                      },
                    ),
                    if (_isUserScrolling || _newMessagesCount > 0)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Material(
                          elevation: 4,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isUserScrolling = false;
                                _newMessagesCount = 0;
                              });
                              _scrollToBottom(animate: true);
                            },
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      Icons.keyboard_arrow_down,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      size: 28,
                                    ),
                                  ),
                                  if (_newMessagesCount > 0)
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(context).colorScheme.surface,
                                            width: 2,
                                          ),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        child: Center(
                                          child: Text(
                                            _newMessagesCount > 99 ? '99+' : '$_newMessagesCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildUploadingMessage(String localId, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
          ),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 2.5,
                  color: Theme.of(context).colorScheme.onPrimary,
                  backgroundColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.3),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Загрузка ${(progress * 100).toInt()}%',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ИЗМЕНЕНО: Теперь принимает Message вместо Map<String, dynamic>
  //
  // БЫЛО:
  // bool _shouldShowDateSeparator(Map<String, dynamic> prevData, Map<String, dynamic> currentData) {
  //   final prevTime = (prevData['timestamp'] as Timestamp).toDate();
  //   final currentTime = (currentData['timestamp'] as Timestamp).toDate();
  //
  // СТАЛО:
  // bool _shouldShowDateSeparator(Message prevMsg, Message currentMsg) {
  //   final prevTime = prevMsg.timestamp;  // уже DateTime
  //   final currentTime = currentMsg.timestamp;  // уже DateTime
  bool _shouldShowDateSeparator(Message prevMsg, Message currentMsg) {
    final prevTime = prevMsg.timestamp;
    final currentTime = currentMsg.timestamp;
    return prevTime.day != currentTime.day ||
        prevTime.month != currentTime.month ||
        prevTime.year != currentTime.year;
  }

  Widget _buildDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    String dateText;
    if (messageDate == today) {
      dateText = 'Сегодня';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      dateText = 'Вчера';
    } else {
      dateText = '${date.day}.${date.month}.${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          dateText,
          style: TextStyle(
            color: Theme.of(context).colorScheme.secondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ИЗМЕНЕНО: Timestamp → DateTime
  String _formatTime(DateTime timestamp) {
    // БЫЛО: final date = timestamp.toDate();
    // СТАЛО: timestamp уже DateTime
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildMessage(Message msg, bool isMine, String docId) {
    if (msg.type == 'audio') {
      // ✅ ИСПРАВЛЕНО: Используем fileUrl вместо message для аудио
      final audioUrl = msg.fileUrl ?? msg.message;

      debugPrint('[ChatPage] 🎵 Аудио сообщение: fileUrl=${msg.fileUrl}, message="${msg.message}", final audioUrl="$audioUrl"');

      // Защита от пустого URL
      if (audioUrl.isEmpty) {
        debugPrint('[ChatPage] ⚠️ ПУСТОЙ URL для аудио! Показываем ошибку.');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Ошибка загрузки аудио'),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: Builder(
            builder: (context) {
              try {
                return ChatAudioPlayer(
                  url: audioUrl,
                  isCurrentUser: isMine,
                  timestamp: msg.timestamp,
                );
              } catch (e) {
                debugPrint('[ChatPage] ❌ Ошибка создания ChatAudioPlayer: $e');
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️ Ошибка загрузки аудио'),
                      const SizedBox(height: 4),
                      Text(
                        audioUrl.length > 50
                          ? '${audioUrl.substring(0, 50)}...'
                          : audioUrl,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      );
    } else if (msg.type == 'image') {
      // ✅ ИСПРАВЛЕНО: Используем fileUrl вместо message для изображений
      final imageUrl = msg.fileUrl ?? msg.message;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: GestureDetector(
            onTap: () {
              if (!mounted) return;
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  backgroundColor: Colors.transparent,
                  child: Stack(
                    children: [
                      InteractiveViewer(
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: imageUrl,
                            placeholder: (context, url) => Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(Icons.error_outline, size: 40),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 40,
                        right: 20,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 30),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Hero(
              tag: imageUrl,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        width: 250,
                        height: 250,
                        placeholder: (context, url) => Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.error_outline, size: 40),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _formatTime(msg.timestamp),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
          child: ChatBubble(
            message: msg.message,
            isCurrentUser: isMine,
            userID: msg.senderID,
            messageID: docId,
            timestamp: msg.timestamp,
          ),
        ),
      );
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.primaryContainer,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: _uploadingFiles.isNotEmpty ? null : _showImageSourceDialog,
              icon: Icon(
                Icons.add_circle_outline,
                size: 28,
                color: _uploadingFiles.isNotEmpty
                    ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)
                    : Theme.of(context).colorScheme.primary,
              ),
              tooltip: 'Прикрепить',
            ),
            Expanded(
              child: ValueListenableBuilder<bool>(
                valueListenable: _hasTextNotifier,
                builder: (context, hasText, _) {
                  return MyTextField(
                    textEditingController: _controller,
                    obscureText: false,
                    hintText: "Сообщение",
                    focusNode: _focusNode,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<bool>(
              valueListenable: _hasTextNotifier,
              builder: (context, hasText, _) {
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: hasText
                      ? Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: _uploadingFiles.isNotEmpty ? null : _sendMessage,
                      icon: Icon(
                        Icons.send_rounded,
                        color: Theme.of(context).colorScheme.onPrimary,
                        size: 22,
                      ),
                      splashRadius: 24,
                    ),
                  )
                      : AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      onPressed: _uploadingFiles.isNotEmpty
                          ? null
                          : (_isRecording ? _stopRecordingAndSend : _startRecording),
                      icon: Icon(
                        _isRecording ? Icons.stop_circle : Icons.mic,
                        size: 28,
                        color: _uploadingFiles.isNotEmpty
                            ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.3)
                            : (_isRecording
                            ? Colors.red
                            : Theme.of(context).colorScheme.primary),
                      ),
                      splashRadius: 24,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}