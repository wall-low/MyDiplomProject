import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:p7/components/load_animation.dart';
import 'package:p7/components/my_button.dart';
import 'package:p7/service/tutor_profile_service.dart';
import 'package:p7/service/auth.dart';

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

  @override
  void dispose() {
    _priceMinController.dispose();
    _priceMaxController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
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
      print('[TutorProfileSetup] 📋 userId: $userId');

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

      print('[TutorProfileSetup] 📝 Данные для создания:');
      print('  - subjects: $_selectedSubjects');
      print('  - priceMin: $priceMin');
      print('  - priceMax: $priceMax');
      print('  - experience: $experience');
      print('  - lessonFormats: $lessonFormats');

      // Создаём профиль
      final profile = await _tutorProfileService.createTutorProfile(
        userId: userId,
        subjects: _selectedSubjects,
        priceMin: priceMin,
        priceMax: priceMax,
        experience: experience,
        education: _educationController.text.trim().isNotEmpty
            ? _educationController.text.trim()
            : null,
        lessonFormat: lessonFormats,
      );

      print('[TutorProfileSetup] ✅ Профиль создан: ${profile?.id}');

      if (mounted) {
        hideLoad(context);
        setState(() => _isLoading = false);

        if (profile != null) {
          _showSnackBar('Профиль репетитора успешно создан!');
          await Future.delayed(const Duration(milliseconds: 500));

          // Возвращаемся назад
          if (mounted) {
            Navigator.pop(context, true); // true = профиль создан
          }
        } else {
          _showSnackBar('Ошибка создания профиля', isError: true);
        }
      }
    } catch (e, stackTrace) {
      print('[TutorProfileSetup] ❌ ОШИБКА создания профиля:');
      print('  Error: $e');
      print('  StackTrace: $stackTrace');

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
