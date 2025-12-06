import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:p7/components/my_button.dart';
import 'package:p7/components/my_text_field.dart';
import 'package:p7/service/auth.dart';
import 'register_profile_page.dart';

// УДАЛЕНО: import 'package:firebase_auth/firebase_auth.dart';
// Мигрировали на PocketBase, используем ClientException вместо FirebaseAuthException

class RegisterPage extends StatefulWidget {
  final void Function()? onTap;
  const RegisterPage({super.key, required this.onTap});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _auth = Auth();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController pwController = TextEditingController();
  final TextEditingController confirmController = TextEditingController();

  final FocusNode emailFocus = FocusNode();
  final FocusNode pwFocus = FocusNode();
  final FocusNode confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    emailController.dispose();
    pwController.dispose();
    confirmController.dispose();
    emailFocus.dispose();
    pwFocus.dispose();
    confirmFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    final emailReg = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailReg.hasMatch(value)) {
      return 'Некорректный email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите пароль';
    }
    if (value.length < 6) {
      return 'Минимум 6 символов';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Подтвердите пароль';
    }
    if (value != pwController.text) {
      return 'Пароли не совпадают';
    }
    return null;
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _continueToProfile() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _auth.registerEmailPassword(
        emailController.text.trim(),
        pwController.text,
      );

      if (mounted) {
        setState(() => _isLoading = false);

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterProfilePage(
              email: emailController.text.trim(),
            ),
          ),
        );
      }
    } on ClientException catch (e) {
      // ИЗМЕНЕНО: FirebaseAuthException → ClientException
      //
      // PocketBase использует statusCode вместо code
      // Основные коды ошибок при регистрации:
      // 400 - некорректные данные (слабый пароль, некорректный email, email уже используется)
      if (mounted) {
        setState(() => _isLoading = false);

        String message;

        // Проверяем ответ от сервера для более точной ошибки
        final response = e.response;
        if (response != null && response is Map) {
          final data = response['data'];
          if (data != null && data is Map) {
            // PocketBase возвращает детальные ошибки в data
            if (data.containsKey('email')) {
              message = 'Этот email уже используется';
            } else if (data.containsKey('password')) {
              message = 'Слишком слабый пароль (минимум 8 символов)';
            } else {
              message = 'Ошибка регистрации: некорректные данные';
            }
          } else {
            message = 'Ошибка регистрации: ${response['message'] ?? 'Проверьте данные'}';
          }
        } else if (e.statusCode == 400) {
          message = 'Некорректные данные';
        } else {
          message = 'Ошибка регистрации';
        }

        _showSnackBar(message, isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Что-то пошло не так', isError: true);
      }
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
                mainAxisAlignment: MainAxisAlignment.center,
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
                            Icons.person_add_rounded,
                            size: 60,
                            color: scheme.primary,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  Text(
                    "Создайте аккаунт",
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
                      "Шаг 1 из 2",
                      style: TextStyle(
                        color: scheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  MyTextField(
                    textEditingController: emailController,
                    obscureText: false,
                    hintText: "Email",
                    label: "Email",
                    prefixIcon: const Icon(Icons.email_outlined),
                    focusNode: emailFocus,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(pwFocus);
                    },
                    validator: _validateEmail,
                  ),

                  const SizedBox(height: 16),

                  MyTextField(
                    textEditingController: pwController,
                    obscureText: _obscurePassword,
                    hintText: "Пароль",
                    label: "Пароль",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    focusNode: pwFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) {
                      FocusScope.of(context).requestFocus(confirmFocus);
                    },
                    validator: _validatePassword,
                  ),

                  const SizedBox(height: 16),

                  MyTextField(
                    textEditingController: confirmController,
                    obscureText: _obscureConfirm,
                    hintText: "Подтвердите пароль",
                    label: "Подтвердите пароль",
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        });
                      },
                    ),
                    focusNode: confirmFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _continueToProfile(),
                    validator: _validateConfirmPassword,
                  ),

                  const SizedBox(height: 12),

                  // Требования к паролю
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Пароль должен содержать минимум 6 символов',
                            style: TextStyle(
                              color: scheme.secondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  MyButton(
                    onTap: _isLoading ? null : _continueToProfile,
                    text: _isLoading ? "Загрузка..." : "Далее",
                  ),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Уже есть аккаунт?",
                        style: TextStyle(
                          color: scheme.secondary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: widget.onTap,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: Text(
                          "Войти",
                          style: TextStyle(
                            color: scheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
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