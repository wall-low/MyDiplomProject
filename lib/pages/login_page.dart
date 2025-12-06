import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:p7/components/my_button.dart';
import 'package:p7/components/my_text_field.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/pages/home_page.dart';
import '../components/load_animation.dart';

// УДАЛЕНО: import 'package:firebase_auth/firebase_auth.dart';
// Мигрировали на PocketBase, используем ClientException вместо FirebaseAuthException
// УДАЛЕНО: import 'package:p7/service/auth_gate.dart'; (AuthGate только для запуска приложения)

class LoginPage extends StatefulWidget {
  final void Function()? onTap;

  const LoginPage({super.key, required this.onTap});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = Auth();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final FocusNode emailFocus = FocusNode();
  final FocusNode passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    emailFocus.dispose();
    passwordFocus.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
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

  void login() async {
    // Убираем фокус с полей (закрываем клавиатуру)
    FocusScope.of(context).unfocus();

    // Валидация формы
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    showLoad(context);

    try {
      await _auth.loginEmailPassword(
        emailController.text.trim(),
        passwordController.text,
      );

      // ВАЖНО: Закрываем диалог загрузки ПЕРЕД навигацией
      if (mounted) {
        hideLoad(context);
        setState(() => _isLoading = false);
      }

      // ИЗМЕНЕНО: Прямой переход на HomePage после успешного входа
      //
      // ЛОГИКА:
      // - При логине пользователь УЖЕ имеет заполненный профиль (заполнялся при регистрации)
      // - AuthGate нужен только при запуске приложения (проверка сохраненной сессии)
      // - После успешного входа сразу переходим на HomePage без проверок
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } on ClientException catch (e) {
      // ИЗМЕНЕНО: FirebaseAuthException → ClientException
      //
      // PocketBase использует statusCode вместо code
      // Основные коды ошибок:
      // 400 - некорректные данные (неверный email/пароль)
      // 403 - доступ запрещен
      // 404 - пользователь не найден
      String message;

      if (e.statusCode == 400) {
        // Неверный email или пароль
        message = 'Неверный email или пароль';
      } else if (e.statusCode == 403) {
        message = 'Доступ запрещен';
      } else if (e.statusCode == 404) {
        message = 'Пользователь не найден';
      } else {
        message = 'Ошибка входа: ${e.response}';
      }

      if (mounted) {
        hideLoad(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        hideLoad(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Что-то пошло не так. Проверьте интернет'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController();
    final resetFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.lock_reset,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text('Восстановление пароля'),
          ],
        ),
        content: Form(
          key: resetFormKey,
          child: TextFormField(
            controller: resetEmailController,
            decoration: InputDecoration(
              hintText: 'Введите ваш email',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: _validateEmail,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (!resetFormKey.currentState!.validate()) {
                return;
              }

              try {
                // ИЗМЕНЕНО: FirebaseAuth.instance.sendPasswordResetEmail → _auth.requestPasswordReset
                //
                // PocketBase отправит email с ссылкой для сброса пароля
                await _auth.requestPasswordReset(
                  resetEmailController.text.trim(),
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Письмо отправлено на почту');
                }
              } on Exception catch (e) {
                // ИЗМЕНЕНО: FirebaseAuthException → Exception
                //
                // auth.requestPasswordReset() уже обработал ClientException
                // и бросил Exception с понятным сообщением
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackBar('Ошибка отправки', isError: true);
                }
              }
            },
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
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
                            Icons.lock_open_rounded,
                            size: 60,
                            color: scheme.primary,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  Text(
                    "С возвращением!",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    "Войдите, чтобы продолжить",
                    style: TextStyle(
                      color: scheme.secondary,
                      fontSize: 16,
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
                      FocusScope.of(context).requestFocus(passwordFocus);
                    },
                    validator: _validateEmail,
                  ),

                  const SizedBox(height: 16),

                  MyTextField(
                    textEditingController: passwordController,
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
                    focusNode: passwordFocus,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => login(),
                    validator: _validatePassword,
                  ),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _showForgotPasswordDialog,
                      child: Text(
                        "Забыли пароль?",
                        style: TextStyle(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  MyButton(
                    onTap: _isLoading ? null : login,
                    text: _isLoading ? "Вход..." : "Войти",
                  ),

                  const SizedBox(height: 40),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Нет аккаунта?",
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
                          "Зарегистрироваться",
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