import 'package:pocketbase/pocketbase.dart';

/// Модель сообщения в чате
///
/// Мигрировано с Firestore на PocketBase
/// Добавлен метод fromRecord() для преобразования RecordModel
///
/// СТРУКТУРА (ОБНОВЛЕНО ПОД POCKETBASE STORAGE):
/// - Текстовые сообщения: type=text, message содержит текст, file=null
/// - Изображения: type=image, file содержит имя файла, message=пустая строка
/// - Аудио: type=audio, file содержит имя файла, message=пустая строка
class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message; // Текст сообщения (только для type=text)
  final DateTime timestamp; // ИЗМЕНЕНО: Timestamp → DateTime
  final String type; // "text" | "image" | "audio"
  final String? file; // ✅ НОВОЕ: Имя файла в PocketBase Storage (для image/audio)
  final String? fileName; // Оригинальное имя файла (опционально)
  final int? fileSize; // Размер файла в байтах
  final Duration? duration; // Длительность аудио
  final bool isRead;
  final String? fileUrl; // ✅ НОВОЕ: Полный URL файла (вычисляется в fromRecord)

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.message,
    required this.timestamp,
    required this.type,
    this.file, // ✅ НОВОЕ поле
    this.fileName,
    this.fileSize,
    this.duration,
    this.isRead = false, // По умолчанию false
    this.fileUrl, // ✅ НОВОЕ: URL файла
  }) : assert(type == 'text' || type == 'image' || type == 'audio');

  /// Преобразование Message в Map для отправки в PocketBase
  ///
  /// ИЗМЕНЕНО:
  /// - timestamp: Timestamp → DateTime.toIso8601String()
  /// - Добавлено chatRoomId (будет добавлено в chat_service.dart)
  Map<String, dynamic> toMap() {
    return {
      // ИЗМЕНЕНИЕ: Изменены названия полей для PocketBase
      //
      // БЫЛО (Firestore):
      // 'senderID', 'receiverID' (с заглавными ID)
      //
      // СТАЛО (PocketBase):
      // 'senderId', 'receiverId' (camelCase - стандарт PocketBase)
      'senderId': senderID,
      'senderEmail': senderEmail,
      'receiverId': receiverID,
      'message': message,

      // ИЗМЕНЕНИЕ: timestamp теперь DateTime, а не Firestore Timestamp
      //
      // БЫЛО:
      // 'timestamp': timestamp (Firestore Timestamp)
      //
      // СТАЛО:
      // 'timestamp': timestamp.toIso8601String() (ISO 8601 строка)
      //
      // PocketBase автоматически распознает ISO 8601 строки
      'timestamp': timestamp.toIso8601String(),

      'type': type,
      'fileName': fileName,
      'fileSize': fileSize,
      'duration': duration?.inSeconds,
      'isRead': isRead,
      // chatRoomId будет добавлен в chat_service.dart при отправке
    };
  }

  /// Создание Message из Map
  ///
  /// ОБНОВЛЕНО для работы с DateTime вместо Timestamp
  factory Message.fromMap(Map<String, dynamic> map) {
    // Парсинг timestamp
    DateTime parsedTimestamp;
    try {
      if (map['timestamp'] is String) {
        // ISO 8601 строка из PocketBase
        parsedTimestamp = DateTime.parse(map['timestamp']);
      } else {
        // Fallback
        parsedTimestamp = DateTime.now();
      }
    } catch (e) {
      print('[Message] Ошибка парсинга timestamp: $e');
      parsedTimestamp = DateTime.now();
    }

    return Message(
      // Поддерживаем оба варианта (старый с ID и новый с Id)
      senderID: map['senderId'] ?? map['senderID'] ?? '',
      senderEmail: map['senderEmail'] ?? '',
      receiverID: map['receiverId'] ?? map['receiverID'] ?? '',
      message: map['message'] ?? '',
      timestamp: parsedTimestamp,
      type: map['type'] ?? 'text',
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      duration: map['duration'] != null
          ? Duration(seconds: map['duration'] as int)
          : null,
      isRead: map['isRead'] ?? false,
    );
  }

  /// Создание Message из RecordModel (PocketBase)
  ///
  /// НОВЫЙ МЕТОД для работы с PocketBase
  ///
  /// RecordModel содержит:
  /// - record.id - ID сообщения
  /// - record.data - Map с данными сообщения
  /// - record.created - дата создания (ISO 8601 строка)
  /// - record.updated - дата обновления (ISO 8601 строка)
  ///
  /// ОБНОВЛЕНО: Добавлена поддержка поля 'file' (PocketBase Storage)
  /// ✅ НОВОЕ: Автоматически вычисляет fileUrl для изображений/аудио
  factory Message.fromRecord(RecordModel record, {PocketBase? pb}) {
    final data = record.data;

    // Парсинг timestamp из record.created (ISO 8601)
    DateTime parsedTimestamp;
    try {
      // Пытаемся взять timestamp из data, если нет - используем created
      if (data['timestamp'] != null) {
        parsedTimestamp = DateTime.parse(data['timestamp']);
      } else {
        parsedTimestamp = DateTime.parse(record.created);
      }
    } catch (e) {
      print('[Message] Ошибка парсинга timestamp: $e');
      parsedTimestamp = DateTime.now();
    }

    // Парсинг duration
    Duration? parsedDuration;
    if (data['duration'] != null) {
      try {
        parsedDuration = Duration(seconds: data['duration'] as int);
      } catch (e) {
        print('[Message] Ошибка парсинга duration: $e');
      }
    }

    // ✅ НОВОЕ: Вычисляем fileUrl если есть file
    String? fileUrl;
    final fileName = data['file'] as String?;

    if (fileName != null && fileName.isNotEmpty && pb != null) {
      try {
        fileUrl = pb.getFileUrl(record, fileName).toString();
        // Логируем только для аудио/изображений (для отладки)
        if (data['type'] == 'audio' || data['type'] == 'image') {
          print('[Message] 📁 Файл ${data['type']}:');
          print('  - fileName: $fileName');
          print('  - fileUrl: $fileUrl');
          print('  - recordId: ${record.id}');
        }
      } catch (e) {
        print('[Message] ❌ Ошибка построения URL файла: $e');
      }
    } else {
      if (data['type'] == 'audio' || data['type'] == 'image') {
        print('[Message] ⚠️ Нет файла для ${data['type']}!');
        print('  - fileName: $fileName');
        print('  - pb: ${pb != null ? "OK" : "NULL"}');
      }
    }

    return Message(
      // PocketBase использует camelCase: senderId, receiverId
      senderID: data['senderId'] as String? ?? '',
      senderEmail: data['senderEmail'] as String? ?? '',
      receiverID: data['receiverId'] as String? ?? '',
      message: data['message'] as String? ?? '',
      timestamp: parsedTimestamp,
      type: data['type'] as String? ?? 'text',
      file: fileName, // ✅ Имя файла из PocketBase Storage
      fileName: data['fileName'] as String?,
      fileSize: data['fileSize'] as int?,
      duration: parsedDuration,
      isRead: data['isRead'] as bool? ?? false,
      fileUrl: fileUrl, // ✅ НОВОЕ: URL файла
    );
  }

  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isAudio => type == 'audio';

  // Удобный метод для копирования с изменением isRead
  Message copyWith({
    String? senderID,
    String? senderEmail,
    String? receiverID,
    String? message,
    DateTime? timestamp, // ИЗМЕНЕНО: Timestamp → DateTime
    String? type,
    String? file, // ✅ НОВОЕ
    String? fileName,
    int? fileSize,
    Duration? duration,
    bool? isRead,
    String? fileUrl, // ✅ НОВОЕ
  }) {
    return Message(
      senderID: senderID ?? this.senderID,
      senderEmail: senderEmail ?? this.senderEmail,
      receiverID: receiverID ?? this.receiverID,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      file: file ?? this.file, // ✅ НОВОЕ
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      isRead: isRead ?? this.isRead,
      fileUrl: fileUrl ?? this.fileUrl, // ✅ НОВОЕ
    );
  }
}