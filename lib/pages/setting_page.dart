import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:p7/themes/theme_provider.dart';
import 'package:p7/service/auth.dart';
import 'package:p7/service/auth_gate.dart';
import 'package:p7/service/pocketbase_service.dart';
import 'package:provider/provider.dart';

import 'blocked_user_page.dart';
import 'payment_history_page.dart';

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

          // Переключатель сервера
          ListenableBuilder(
            listenable: PocketBaseService(),
            builder: (context, _) {
              final pbService = PocketBaseService();
              final isVps = pbService.serverMode == ServerMode.vps;
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      isVps ? Icons.cloud : Icons.computer,
                      color: isVps ? Colors.blue : Colors.green,
                    ),
                    title: Text(
                      "Сервер",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 20,
                      ),
                    ),
                    subtitle: Text(
                      isVps ? "VPS: ${pbService.vpsUrl}" : "Локальный: ${pbService.localUrl}",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    trailing: CupertinoSwitch(
                      value: isVps,
                      activeColor: Colors.blue,
                      onChanged: (value) async {
                        final mode = value ? ServerMode.vps : ServerMode.local;
                        await pbService.switchServer(mode);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                value
                                    ? 'Переключено на VPS сервер'
                                    : 'Переключено на локальный сервер',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  // Кнопка редактирования URL
                  Padding(
                    padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
                    child: Row(
                      children: [
                        _ServerUrlButton(
                          label: "Локальный",
                          url: pbService.localUrl,
                          mode: ServerMode.local,
                          isActive: !isVps,
                        ),
                        const SizedBox(width: 8),
                        _ServerUrlButton(
                          label: "VPS",
                          url: pbService.vpsUrl,
                          mode: ServerMode.vps,
                          isActive: isVps,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(
              "История платежей",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
              ),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const PaymentHistoryPage()),
              );
            },
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

  static void showEditUrlDialog(BuildContext context, ServerMode mode, String currentUrl) {
    final controller = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(mode == ServerMode.local ? "Локальный URL" : "VPS URL"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "http://IP:8090",
            labelText: "URL сервера",
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        actions: [
          TextButton(
            child: const Text("Отмена"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text("Сохранить"),
            onPressed: () async {
              final url = controller.text.trim();
              if (url.isNotEmpty) {
                await PocketBaseService().updateUrl(mode, url);
                if (ctx.mounted) Navigator.of(ctx).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('URL обновлён: $url')),
                  );
                }
              }
            },
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

              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              Navigator.of(ctx).pop(); // закрываем диалог
              // Показываем индикатор в основном контексте
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator()),
              );

              try {
                await Auth().changePassword(
                  currentPassword: _currentPwCtrl.text,
                  newPassword: _newPwCtrl.text,
                );
                nav.pop(); // закрыть индикатор
                messenger.showSnackBar(
                  const SnackBar(content: Text('Пароль успешно обновлён')),
                );
              } on Exception catch (e) {
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
                );
              } catch (e) {
                nav.pop();
                messenger.showSnackBar(
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

class _ServerUrlButton extends StatelessWidget {
  final String label;
  final String url;
  final ServerMode mode;
  final bool isActive;

  const _ServerUrlButton({
    required this.label,
    required this.url,
    required this.mode,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        icon: const Icon(Icons.edit, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          side: BorderSide(
            color: isActive
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outline,
          ),
        ),
        onPressed: () {
          SettingPage.showEditUrlDialog(context, mode, url);
        },
      ),
    );
  }
}