import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:p7/components/load_animation.dart';
import 'package:p7/components/my_button.dart';
import 'package:p7/components/my_text_field.dart';
import 'package:p7/service/databases.dart';
import 'package:p7/pages/main_navigation.dart';

class RegisterProfilePage extends StatefulWidget {
  final String email;

  const RegisterProfilePage({
    super.key,
    required this.email,
  });

  @override
  State<RegisterProfilePage> createState() => _RegisterProfilePageState();
}

class _RegisterProfilePageState extends State<RegisterProfilePage> {
  final _db = Databases();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  DateTime? _birthDate;
  String? _selectedRole;

  final List<String> _roles = [
    'Ученик',
    'Репетитор',
  ];

  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    cityController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите имя';
    }
    final digitReg = RegExp(r'\d');
    if (digitReg.hasMatch(value)) {
      return 'Имя не может содержать цифры';
    }
    if (value.length < 2) {
      return 'Имя слишком короткое';
    }
    return null;
  }

  String? _validateCity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите город';
    }
    if (value.length < 2) {
      return 'Название города слишком короткое';
    }
    return null;
  }

  int _calculateAge(DateTime birthDate) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
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

  void _completeRegistration() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_birthDate == null) {
      _showSnackBar('Выберите дату рождения', isError: true);
      return;
    }

    final age = _calculateAge(_birthDate!);
    if (age < 1 || age > 100) {
      _showSnackBar('Возраст должен быть от 1 до 100 лет', isError: true);
      return;
    }

    if (_selectedRole == null) {
      _showSnackBar('Выберите роль', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    showLoad(context, message: 'Сохранение профиля...');

    try {
      // ИЗМЕНЕНО: saveInfoInFirebase → saveInfoInPocketBase
      await _db.saveInfoInPocketBase(
        name: nameController.text.trim(),
        email: widget.email,
        birthDate: _birthDate!,
        city: cityController.text.trim(),
        role: _selectedRole!,
      );

      if (mounted) {
        hideLoad(context);
        setState(() => _isLoading = false);

        _showSnackBar('Регистрация завершена!');

        await Future.delayed(const Duration(milliseconds: 500));

        // ИЗМЕНЕНО: AuthGate → MainNavigation
        //
        // ЛОГИКА:
        // - Профиль уже сохранен в PocketBase
        // - Пользователь авторизован
        // - Переходим на MainNavigation (с Bottom Navigation Bar)
        // - Это обеспечивает единообразный UX с обычным входом
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const MainNavigation()),
                (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        hideLoad(context);
        setState(() => _isLoading = false);
        _showSnackBar('Ошибка сохранения: ${e.toString()}', isError: true);
      }
    }
  }

  Future<void> _selectBirthDate() async {
    final scheme = Theme.of(context).colorScheme;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(DateTime.now().year - 18),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: scheme.primary,
              onPrimary: scheme.onPrimary,
              surface: scheme.surface,
              onSurface: scheme.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  // Логотип с анимацией
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_circle_rounded,
                            size: 60,
                            color: scheme.primary,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  Text(
                    "Расскажите о себе",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Индикатор шага
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Шаг 2 из 2",
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Имя
                  MyTextField(
                    textEditingController: nameController,
                    obscureText: false,
                    hintText: "Ваше имя",
                    label: "Имя",
                    prefixIcon: const Icon(Icons.person_outline),
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                  ),

                  const SizedBox(height: 16),

                  // Город
                  MyTextField(
                    textEditingController: cityController,
                    obscureText: false,
                    hintText: "Ваш город",
                    label: "Город",
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.done,
                    validator: _validateCity,
                  ),

                  const SizedBox(height: 16),

                  // Дата рождения
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selectBirthDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _birthDate == null
                                ? scheme.secondary
                                : scheme.primary,
                            width: _birthDate == null ? 1.5 : 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              color: _birthDate == null
                                  ? scheme.secondary
                                  : scheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_birthDate != null)
                                    Text(
                                      'Дата рождения',
                                      style: TextStyle(
                                        color: scheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  Text(
                                    _birthDate == null
                                        ? 'Дата рождения'
                                        : DateFormat('dd.MM.yyyy').format(_birthDate!),
                                    style: TextStyle(
                                      color: _birthDate == null
                                          ? scheme.secondary
                                          : scheme.onSurface,
                                      fontSize: 15,
                                      fontWeight: _birthDate == null
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_birthDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: scheme.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_calculateAge(_birthDate!)} лет',
                                  style: TextStyle(
                                    color: scheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Роль
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedRole == null
                            ? scheme.secondary
                            : scheme.primary,
                        width: _selectedRole == null ? 1.5 : 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.work_outline,
                          color: _selectedRole == null
                              ? scheme.secondary
                              : scheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              hint: Text(
                                'Выберите роль',
                                style: TextStyle(
                                  color: scheme.secondary,
                                  fontSize: 15,
                                ),
                              ),
                              value: _selectedRole,
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: _selectedRole == null
                                    ? scheme.secondary
                                    : scheme.primary,
                              ),
                              style: TextStyle(
                                color: scheme.onSurface,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                              dropdownColor: scheme.surface,
                              borderRadius: BorderRadius.circular(12),
                              items: _roles.map((String role) {
                                return DropdownMenuItem<String>(
                                  value: role,
                                  child: Row(
                                    children: [
                                      Icon(
                                        role == 'Ученик'
                                            ? Icons.school_outlined
                                            : Icons.person_outline,
                                        size: 18,
                                        color: scheme.primary,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(role),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() => _selectedRole = newValue);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  MyButton(
                    onTap: _isLoading ? null : _completeRegistration,
                    text: _isLoading ? "Сохранение..." : "Завершить регистрацию",
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}