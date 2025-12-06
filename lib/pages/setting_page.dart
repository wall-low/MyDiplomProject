import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:p7/themes/theme_provider.dart';
import 'package:p7/service/auth.dart';
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
        title: const Text("S E T T I N G S"),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: ListView(
        children: [

          ListTile(
            title: Text(
              "Dark Mode",
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
              "Blocked Users",
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
              "Change Password",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
              ),
            ),
            leading: const Icon(Icons.lock_outline),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final _currentPwCtrl = TextEditingController();
    final _newPwCtrl = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Change Password"),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Текущее пароль
              TextFormField(
                controller: _currentPwCtrl,
                decoration: const InputDecoration(labelText: "Current Password"),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter current password';
                  if (v.length < 6) return 'Too short';
                  return null;
                },
              ),

              // Новый пароль
              TextFormField(
                controller: _newPwCtrl,
                decoration: const InputDecoration(labelText: "New Password"),
                obscureText: true,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter new password';
                  if (v.length < 6) return 'Must be at least 6 characters';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text("Update"),
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
                  const SnackBar(content: Text('Password updated successfully')),
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
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}