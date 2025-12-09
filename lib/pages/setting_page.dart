import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:p7/themes/theme_provider.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/auth_gate.dart';
import 'package:provider/provider.dart';

// УДАЛЕНО: import 'package:firebase_auth/firebase_auth.dart';
// Мигрировали на PocketBase

import 'blocked_user_page.dart';

class SettingPage extends StatelessWidget {
  const SettingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProv = context.watch<ThemProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        title: const Text("Н А С Т Р О Й К И"),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: ListView(
        children: [

          ListTile(
            title: Text(
              "Тёмная тема",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
              ),
            ),
            trailing: CupertinoSwitch(
              value: themeProv.isDarkMode,
              onChanged: (_) => themeProv.toggleTheme(),
            ),
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.block),
            title: Text(
              "Заблокированные пользователи",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => BlockedUserPage()),
              );
            },
          ),

          const Divider(),

          // Пункт для смены пароля
          ListTile(
            title: Text(
              "Сменить пароль",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
              ),
            ),
            leading: const Icon(Icons.lock_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context),
          ),

          const Divider(),

          // Logout кнопка
          ListTile(
            title: Text(
              "Выйти",
              style: TextStyle(
                color: Colors.red,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            leading: const Icon(
              Icons.logout,
              color: Colors.red,
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  // Logout функция
  void _logout(BuildContext context) async {
    // Показываем диалог подтверждения
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Выход"),
        content: const Text("Вы уверены, что хотите выйти из аккаунта?"),
        actions: [
          TextButton(
            child: const Text("Отмена"),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("Выйти"),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      // Выполняем logout
      await Auth().logout();

      // Переходим на AuthGate (который покажет LoginOrRegister)
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false, // Удаляем весь стек навигации
        );
      }
    }
  }

  void _showChangePasswordDialog(BuildContext context) {
    final _currentPwCtrl = TextEditingController();
    final _newPwCtrl = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Смена пароля"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Текущий пароль
              TextFormField(
                controller: _currentPwCtrl,
                decoration: const InputDecoration(labelText: "Текущий пароль"),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите текущий пароль';
                  if (v.length < 6) return 'Слишком короткий';
                  return null;
                },
              ),

              // Новый пароль
              TextFormField(
                controller: _newPwCtrl,
                decoration: const InputDecoration(labelText: "Новый пароль"),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Введите новый пароль';
                  if (v.length < 6) return 'Минимум 6 символов';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Отмена"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text("Обновить"),
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;

              Navigator.of(ctx).pop(); // закрываем диалог
              // Показываем индикатор в основном контексте
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                // Реаутентификация + смена пароля
                await Auth().changePassword(
                  currentPassword: _currentPwCtrl.text,
                  newPassword: _newPwCtrl.text,
                );
                // Успех
                Navigator.of(context).pop(); // закрыть индикатор
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Пароль успешно обновлён')),
                );
              } on Exception catch (e) {
                // ИЗМЕНЕНО: FirebaseAuthException → Exception
                //
                // auth.changePassword() бросает Exception с понятным сообщением
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}