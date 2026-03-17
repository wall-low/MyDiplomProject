import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

/// Модель сообщения в чате
///
/// - Текстовые сообщения: type=text, message содержит текст, file=null
/// - Изображения: type=image, file содержит имя файла, message=пустая строка
/// - Аудио: type=audio, file содержит имя файла, message=пустая строка
class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message; // Текст сообщения (только для type=text)
  final DateTime timestamp;
  final String type; // "text" | "image" | "audio"
  final String? file; // Имя файла в PocketBase Storage (для image/audio)
  final String? fileName; // Оригинальное имя файла (опционально)
  final int? fileSize; // Размер файла в байтах
  final Duration? duration; // Длительность аудио
  final bool isRead;
  final String? fileUrl; // Полный URL файла (вычисляется в fromRecord)

  Message({
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.message,
    required this.timestamp,
    required this.type,
    this.file,
    this.fileName,
    this.fileSize,
    this.duration,
    this.isRead = false,
    this.fileUrl,
  }) : assert(type == 'text' || type == 'image' || type == 'audio');

  /// Преобразование Message в Map для отправки в PocketBase
  Map<String, dynamic> toMap() {
    return {
      'senderId': senderID,
      'senderEmail': senderEmail,
      'receiverId': receiverID,
      'message': message,
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
  factory Message.fromMap(Map<String, dynamic> map) {
    // Парсинг timestamp
    DateTime parsedTimestamp;
    try {
      if (map['timestamp'] is String) {
        // ISO 8601 строка из PocketBase → локальное время
        parsedTimestamp = DateTime.parse(map['timestamp']).toLocal();
      } else {
        // Fallback
        parsedTimestamp = DateTime.now();
      }
    } catch (e) {
      debugPrint('[Message] Ошибка парсинга timestamp: $e');
      parsedTimestamp = DateTime.now();
    }

    return Message(
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
  /// Автоматически вычисляет fileUrl для изображений/аудио
  factory Message.fromRecord(RecordModel record, {PocketBase? pb}) {
    final data = record.data;

    // Парсинг timestamp из record.created (ISO 8601)
    DateTime parsedTimestamp;
    try {
      // Пытаемся взять timestamp из data, если нет - используем created
      if (data['timestamp'] != null) {
        parsedTimestamp = DateTime.parse(data['timestamp']).toLocal();
      } else {
        parsedTimestamp = DateTime.parse(record.created).toLocal();
      }
    } catch (e) {
      debugPrint('[Message] Ошибка парсинга timestamp: $e');
      parsedTimestamp = DateTime.now();
    }

    // Парсинг duration
    Duration? parsedDuration;
    if (data['duration'] != null) {
      try {
        parsedDuration = Duration(seconds: data['duration'] as int);
      } catch (e) {
        debugPrint('[Message] Ошибка парсинга duration: $e');
      }
    }

    // Вычисляем fileUrl если есть file
    String? fileUrl;
    final fileName = data['file'] as String?;

    if (fileName != null && fileName.isNotEmpty && pb != null) {
      try {
        fileUrl = pb.getFileUrl(record, fileName).toString();
        // Логируем только для аудио/изображений (для отладки)
        if (data['type'] == 'audio' || data['type'] == 'image') {
          debugPrint('[Message] 📁 Файл ${data['type']}:');
          debugPrint('  - fileName: $fileName');
          debugPrint('  - fileUrl: $fileUrl');
          debugPrint('  - recordId: ${record.id}');
        }
      } catch (e) {
        debugPrint('[Message] ❌ Ошибка построения URL файла: $e');
      }
    } else {
      if (data['type'] == 'audio' || data['type'] == 'image') {
        debugPrint('[Message] ⚠️ Нет файла для ${data['type']}!');
        debugPrint('  - fileName: $fileName');
        debugPrint('  - pb: ${pb != null ? "OK" : "NULL"}');
      }
    }

    return Message(
      senderID: data['senderId'] as String? ?? '',
      senderEmail: data['senderEmail'] as String? ?? '',
      receiverID: data['receiverId'] as String? ?? '',
      message: data['message'] as String? ?? '',
      timestamp: parsedTimestamp,
      type: data['type'] as String? ?? 'text',
      file: fileName,
      fileName: data['fileName'] as String?,
      fileSize: data['fileSize'] as int?,
      duration: parsedDuration,
      isRead: data['isRead'] as bool? ?? false,
      fileUrl: fileUrl,
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
    DateTime? timestamp,
    String? type,
    String? file,
    String? fileName,
    int? fileSize,
    Duration? duration,
    bool? isRead,
    String? fileUrl,
  }) {
    return Message(
      senderID: senderID ?? this.senderID,
      senderEmail: senderEmail ?? this.senderEmail,
      receiverID: receiverID ?? this.receiverID,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      file: file ?? this.file,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      duration: duration ?? this.duration,
      isRead: isRead ?? this.isRead,
      fileUrl: fileUrl ?? this.fileUrl,
    );
  }
}