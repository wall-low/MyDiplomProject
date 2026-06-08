import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';

class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message;
  final DateTime timestamp;
  final String type;
  final String? file;
  final String? fileName;
  final int? fileSize;
  final Duration? duration;
  final bool isRead;
  final String? fileUrl;

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
  }) : assert(type == 'text' || type == 'image' || type == 'audio' || type == 'file');

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderID,
      'senderEmail': senderEmail,
      'receiverId': receiverID,
      'message': message,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'type': type,
      'fileName': fileName,
      'fileSize': fileSize,
      'duration': duration?.inSeconds,
      'isRead': isRead,

    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    DateTime parsedTimestamp;
    try {
      if (map['timestamp'] is String) {
        parsedTimestamp = DateTime.parse(map['timestamp']).toLocal();
      } else {
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

  factory Message.fromRecord(RecordModel record, {PocketBase? pb}) {
    final data = record.data;

    DateTime parsedTimestamp;
    try {
      if (data['timestamp'] != null) {
        parsedTimestamp = DateTime.parse(data['timestamp']).toLocal();
      } else {
        parsedTimestamp = DateTime.parse(record.created).toLocal();
      }
    } catch (e) {
      debugPrint('[Message] Ошибка парсинга timestamp: $e');
      parsedTimestamp = DateTime.now();
    }

    Duration? parsedDuration;
    if (data['duration'] != null) {
      try {
        parsedDuration = Duration(seconds: data['duration'] as int);
      } catch (e) {
        debugPrint('[Message] Ошибка парсинга duration: $e');
      }
    }

    String? fileUrl;
    final fileName = data['file'] as String?;

    if (fileName != null && fileName.isNotEmpty && pb != null) {
      try {
        fileUrl = pb.getFileUrl(record, fileName).toString();
        if (data['type'] == 'audio' || data['type'] == 'image') {
          debugPrint('[Message] 📁 Файл ${data['type']}:');
          debugPrint('  - fileName: $fileName');
          debugPrint('  - fileUrl: $fileUrl');
          debugPrint('  - recordId: ${record.id}');
        }
      } catch (e) {
        debugPrint('[Message] Ошибка построения URL файла: $e');
      }
    } else {
      if (data['type'] == 'audio' || data['type'] == 'image') {
        debugPrint('[Message] Нет файла для ${data['type']}!');
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
      fileName: data['fileName'] as String? ?? 
                (data['type'] == 'file' ? data['message'] as String? : null) ?? 
                fileName,
      fileSize: _parseFileSize(data['fileSize']),
      duration: parsedDuration,
      isRead: data['isRead'] as bool? ?? false,
      fileUrl: fileUrl,
    );
  }

  static int? _parseFileSize(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool get isText => type == 'text';
  bool get isImage => type == 'image';
  bool get isAudio => type == 'audio';

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