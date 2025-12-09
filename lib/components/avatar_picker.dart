import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:p7/service/pocketbase_service.dart';
import 'package:p7/service/auth.dart';

class AvatarPicker extends StatefulWidget {

  final double size;


  final BorderRadius borderRadius;


  final bool enablePicker;

  const AvatarPicker({
    Key? key,
    this.size = 120,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.enablePicker = true,
  }) : super(key: key);

  @override
  State<AvatarPicker> createState() => _AvatarPickerState();
}

class _AvatarPickerState extends State<AvatarPicker> {
  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();
  // ИЗМЕНЕНИЕ 1: Добавили PocketBase сервис
  final _pbService = PocketBaseService();

  @override
  void initState() {
    super.initState();
    _loadSavedUrl();
  }

  /// Загрузить сохраненный URL аватара
  ///
  /// БЫЛО (Firestore):
  /// 1. Получали документ из Users коллекции
  /// 2. Извлекали avatarUrl из data
  ///
  /// СТАЛО (PocketBase):
  /// 1. Получаем RecordModel из users коллекции
  /// 2. Генерируем URL через getUserAvatarUrl()
  ///
  /// ЗАЧЕМ:
  /// PocketBase хранит только имя файла, URL генерируется динамически
  Future<void> _loadSavedUrl() async {
    try {
      // ИЗМЕНЕНИЕ 2: Auth() вместо FirebaseAuth
      //
      // БЫЛО:
      // final uid = FirebaseAuth.instance.currentUser!.uid;
      //
      // СТАЛО:
      // final uid = Auth().getCurrentUid();
      final uid = Auth().getCurrentUid();

      // ИЗМЕНЕНИЕ 3: getOne() вместо doc().get()
      //
      // БЫЛО (Firestore):
      // final doc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      // final avatarUrl = doc.data()?['avatarUrl'];
      //
      // СТАЛО (PocketBase):
      // final record = await _pbService.client.collection('users').getOne(uid);
      // final avatarUrl = _pbService.getUserAvatarUrl(record);
      final record = await _pbService.client.collection('users').getOne(uid);

      // ИЗМЕНЕНИЕ 4: getUserAvatarUrl() вместо прямого доступа к полю
      //
      // PocketBase:
      // - record.data['avatar'] содержит только имя файла (например, "abc123.jpg")
      // - Полный URL генерируется через pb.getFileUrl(record, filename)
      // - getUserAvatarUrl() делает это автоматически с thumbnail
      final avatarUrl = _pbService.getUserAvatarUrl(record);

      if (!mounted) return;
      setState(() => _avatarUrl = avatarUrl.isNotEmpty ? avatarUrl : null);
    } catch (e) {
      debugPrint('[AvatarPicker] Ошибка загрузки аватара: $e');
    }
  }

  /// Выбрать и загрузить новый аватар
  ///
  /// БЫЛО (Cloudinary + Firestore - 3 шага):
  /// 1. ImagePicker → выбор файла
  /// 2. Cloudinary.uploadAvatar() → загрузка, получение URL
  /// 3. Firestore.update() → сохранение URL
  ///
  /// СТАЛО (PocketBase - 2 шага):
  /// 1. ImagePicker → выбор файла
  /// 2. PocketBase.uploadAvatar() → загрузка + обновление записи одновременно
  ///
  /// ЗАЧЕМ:
  /// PocketBase хранит файлы вместе с записями, не нужен отдельный сервис
  Future<void> _pickAndUpload() async {
    debugPrint('[AvatarPicker] 🖼️ Начало выбора изображения...');

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 85,
    );

    if (picked == null) {
      debugPrint('[AvatarPicker] ❌ Изображение не выбрано');
      return;
    }

    debugPrint('[AvatarPicker] ✅ Изображение выбрано: ${picked.path}');

    // Показываем индикатор загрузки
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 16),
              Text('Загрузка аватара...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      final uid = Auth().getCurrentUid();
      debugPrint('[AvatarPicker] 👤 User ID: $uid');

      // Проверяем размер файла
      final fileSize = await picked.length();
      debugPrint('[AvatarPicker] 📦 Размер файла: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      if (fileSize > 5 * 1024 * 1024) {
        throw Exception('Файл слишком большой (макс. 5 МБ)');
      }

      debugPrint('[AvatarPicker] 🚀 Начало загрузки в PocketBase...');

      final record = await _pbService.uploadAvatar(
        userId: uid,
        filePath: picked.path,
      );

      debugPrint('[AvatarPicker] ✅ Аватар загружен в PocketBase');
      debugPrint('[AvatarPicker] 📄 Record ID: ${record.id}');
      debugPrint('[AvatarPicker] 📄 Avatar field: ${record.data['avatar']}');

      final url = _pbService.getUserAvatarUrl(record);
      debugPrint('[AvatarPicker] 🌐 Generated URL: $url');

      if (!mounted) return;

      // Убираем индикатор загрузки
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      setState(() => _avatarUrl = url);

      // Показываем успешное сообщение
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Аватар успешно обновлён!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('[AvatarPicker] ❌ ОШИБКА загрузки аватара: $e');
      debugPrint('[AvatarPicker] 📋 Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Ошибка загрузки: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enablePicker ? _pickAndUpload : null,
      child: Hero(
        // ИЗМЕНЕНИЕ 7: Auth() вместо FirebaseAuth
        tag: 'avatar-${Auth().getCurrentUid()}',
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.enablePicker
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            borderRadius: widget.borderRadius,
            image: _avatarUrl != null
                ? DecorationImage(
              image: NetworkImage(_avatarUrl!),
              fit: BoxFit.cover,
            )
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: _avatarUrl == null
              ? Icon(
            Icons.person,
            size: widget.size * 0.6,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          )
              : null,
        ),
      ),
    );
  }
}
