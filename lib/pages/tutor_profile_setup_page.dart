import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:p7/components/load_animation.dart';
import 'package:p7/components/my_button.dart';
import 'package:p7/models/tutor_profile.dart';
import 'package:p7/service/tutor_profile_service.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/card_storage_service.dart';

/// Форматирует ввод номера карты: XXXX XXXX XXXX XXXX
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Страница заполнения расширенного профиля репетитора
///
/// Открывается для репетиторов, которые ещё не заполнили свой профиль
/// Собирает: предметы, цены, опыт, образование, формат занятий
class TutorProfileSetupPage extends StatefulWidget {
  final bool isEditing; // true = редактирование, false = первичное заполнение

  const TutorProfileSetupPage({
    super.key,
    this.isEditing = false,
  });

  @override
  State<TutorProfileSetupPage> createState() => _TutorProfileSetupPageState();
}

class _TutorProfileSetupPageState extends State<TutorProfileSetupPage> {
  final _tutorProfileService = TutorProfileService();
  final _auth = Auth();
  final _formKey = GlobalKey<FormState>();

  // Контроллеры для текстовых полей
  final TextEditingController _priceMinController = TextEditingController();
  final TextEditingController _priceMaxController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _payoutCardController = TextEditingController();

  // Список всех доступных предметов
  final List<String> _availableSubjects = [
    'Математика',
    'Физика',
    'Химия',
    'Биология',
    'Русский язык',
    'Английский язык',
    'Немецкий язык',
    'История',
    'Обществознание',
    'Литература',
    'География',
    'Информатика',
    'Программирование',
  ];

  // Выбранные предметы
  List<String> _selectedSubjects = [];

  // Формат занятий
  bool _isOnline = false;
  bool _isOffline = false;

  bool _isLoading = false;
  String? _existingProfileId; // ID записи в tutor_profiles (для обновления)

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingProfile();
    }
  }

  Future<void> _loadExistingProfile() async {
    final userId = _auth.getCurrentUid();
    if (userId.isEmpty) return;

    final profile = await _tutorProfileService.getTutorProfileByUserId(userId);
    if (profile == null || !mounted) return;

    setState(() {
      _existingProfileId = profile.id;
      _selectedSubjects = List<String>.from(profile.subjects);
      _isOnline = profile.lessonFormat.contains('online');
      _isOffline = profile.lessonFormat.contains('offline');
      if (profile.priceMin != null) {
        _priceMinController.text = profile.priceMin!.toInt().toString();
      }
      if (profile.priceMax != null) {
        _priceMaxController.text = profile.priceMax!.toInt().toString();
      }
      if (profile.experience != null) {
        _experienceController.text = profile.experience.toString();
      }
      if (profile.education != null) {
        _educationController.text = profile.education!;
      }
      if (profile.payoutCardLast4 != null) {
        _payoutCardController.text = '•••• •••• •••• ${profile.payoutCardLast4}';
      }
    });
  }

  @override
  void dispose() {
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _payoutCardController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: Duration(seconds: isError ? 3 : 2),
      ),
    );
  }

  void _saveProfile() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Валидация предметов
    if (_selectedSubjects.isEmpty) {
      _showSnackBar('Выберите хотя бы один предмет', isError: true);
      return;
    }

    // Валидация формата занятий
    if (!_isOnline && !_isOffline) {
      _showSnackBar('Выберите хотя бы один формат занятий', isError: true);
      return;
    }

    // Валидация цен
    final priceMin = _priceMinController.text.isNotEmpty
        ? double.tryParse(_priceMinController.text)
        : null;
    final priceMax = _priceMaxController.text.isNotEmpty
        ? double.tryParse(_priceMaxController.text)
        : null;

    if (priceMin != null && priceMax != null && priceMin > priceMax) {
      _showSnackBar('Минимальная цена не может быть больше максимальной',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);
    showLoad(context, message: 'Сохранение профиля...');

    try {
      final userId = _auth.getCurrentUid();
      debugPrint('[TutorProfileSetup] 📋 userId: $userId');

      if (userId.isEmpty) {
        throw Exception('Пользователь не авторизован');
      }

      // Формируем список форматов занятий
      List<String> lessonFormats = [];
      if (_isOnline) lessonFormats.add('online');
      if (_isOffline) lessonFormats.add('offline');

      // Парсим опыт
      final experience = _experienceController.text.isNotEmpty
          ? int.tryParse(_experienceController.text)
          : null;

      debugPrint('[TutorProfileSetup] 📝 Данные для создания:');
      debugPrint('  - subjects: $_selectedSubjects');
      debugPrint('  - priceMin: $priceMin');
      debugPrint('  - priceMax: $priceMax');
      debugPrint('  - experience: $experience');
      debugPrint('  - lessonFormats: $lessonFormats');

      // Извлекаем последние 4 цифры карты для выплат
      // (если поле изменилось — содержит 16 цифр; если загружено из профиля — пропускаем)
      String? payoutCardLast4;
      final rawCard = _payoutCardController.text.replaceAll(RegExp(r'\D'), '');
      if (rawCard.length == 16) {
        payoutCardLast4 = rawCard.substring(12);
      }

      final education = _educationController.text.trim().isNotEmpty
          ? _educationController.text.trim()
          : null;

      TutorProfile? profile;

      if (widget.isEditing && _existingProfileId != null) {
        // Обновляем существующий профиль
        final updates = <String, dynamic>{
          'subjects': _selectedSubjects,
          if (priceMin != null) 'priceMin': priceMin,
          if (priceMax != null) 'priceMax': priceMax,
          if (experience != null) 'experience': experience,
          if (education != null) 'education': education,
          'lessonFormat': lessonFormats,
          if (payoutCardLast4 != null) 'payoutCardLast4': payoutCardLast4,
        };
        profile = await _tutorProfileService.updateTutorProfile(
            _existingProfileId!, updates);
      } else {
        // Создаём новый профиль
        profile = await _tutorProfileService.createTutorProfile(
          userId: userId,
          subjects: _selectedSubjects,
          priceMin: priceMin,
          priceMax: priceMax,
          experience: experience,
          education: education,
          lessonFormat: lessonFormats,
          payoutCardLast4: payoutCardLast4,
        );
      }

      if (mounted) {
        hideLoad(context);
        setState(() => _isLoading = false);

        if (profile != null) {
          _showSnackBar(widget.isEditing
              ? 'Профиль успешно обновлён!'
              : 'Профиль репетитора успешно создан!');
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            Navigator.pop(context, true);
          }
        } else {
          _showSnackBar('Ошибка сохранения профиля', isError: true);
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[TutorProfileSetup] ❌ ОШИБКА сохранения профиля:');
      debugPrint('  Error: $e');
      debugPrint('  StackTrace: $stackTrace');

      if (mounted) {
        hideLoad(context);
        setState(() => _isLoading = false);
        _showSnackBar('Ошибка: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Редактирование профиля'
              : 'Заполните профиль репетитора',
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Приветственный текст
                if (!widget.isEditing) ...[
                  const Text(
                    'Расскажите о себе',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Заполните информацию, чтобы ученики могли найти вас',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Предметы преподавания
                _buildSectionTitle('Предметы преподавания *'),
                const SizedBox(height: 12),
                _buildSubjectsSelector(),
                const SizedBox(height: 24),

                // Стоимость занятий
                _buildSectionTitle('Стоимость занятий (₽/час)'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _priceMinController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: 'От',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('—', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _priceMaxController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: InputDecoration(
                          hintText: 'До',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.tertiary,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Опыт работы
                _buildSectionTitle('Опыт работы (лет)'),
                const SizedBox(height: 12),
                TextField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: 'Например: 5',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Образование
                _buildSectionTitle('Образование'),
                const SizedBox(height: 12),
                TextField(
                  controller: _educationController,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(
                    hintText: 'Например: МГУ, факультет математики',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Формат занятий
                _buildSectionTitle('Формат занятий *'),
                const SizedBox(height: 12),
                _buildLessonFormatSelector(),
                const SizedBox(height: 24),

                // Карта для выплат
                _buildSectionTitle('Карта для получения оплаты'),
                const SizedBox(height: 4),
                Text(
                  'Введите номер карты, на которую будете получать выплаты от учеников. Хранятся только последние 4 цифры.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                _buildPayoutCardField(),
                const SizedBox(height: 32),

                // Кнопка сохранения
                MyButton(
                  text: widget.isEditing ? 'Сохранить изменения' : 'Создать профиль',
                  onTap: _isLoading ? () {} : _saveProfile,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSubjectsSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _availableSubjects.map((subject) {
          final isSelected = _selectedSubjects.contains(subject);
          return FilterChip(
            label: Text(subject),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedSubjects.add(subject);
                } else {
                  _selectedSubjects.remove(subject);
                }
              });
            },
            selectedColor: Theme.of(context).colorScheme.primary,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPayoutCardField() {
    final digits =
        _payoutCardController.text.replaceAll(RegExp(r'\D'), '');
    final network = SavedCard.detectNetwork(digits);
    final isComplete = digits.length == 16;

    return TextField(
      controller: _payoutCardController,
      keyboardType: TextInputType.number,
      inputFormatters: [_CardNumberFormatter()],
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: 'XXXX XXXX XXXX XXXX',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Theme.of(context).colorScheme.tertiary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        suffixIcon: digits.isEmpty
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (network == 'visa')
                      const Text('VISA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1F71),
                              fontSize: 13))
                    else if (network == 'mastercard')
                      const Text('MC',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFEB001B),
                              fontSize: 13))
                    else if (network == 'mir')
                      const Text('МИР',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF009900),
                              fontSize: 13)),
                    if (isComplete) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 18),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLessonFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            title: const Text('Онлайн занятия'),
            subtitle: const Text('Через Zoom, Skype и т.д.'),
            value: _isOnline,
            onChanged: (value) {
              setState(() {
                _isOnline = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          CheckboxListTile(
            title: const Text('Оффлайн занятия'),
            subtitle: const Text('Очные встречи'),
            value: _isOffline,
            onChanged: (value) {
              setState(() {
                _isOffline = value ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
