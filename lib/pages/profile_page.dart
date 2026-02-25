import 'package:flutter/material.dart';
import 'package:p7/components/input_box.dart';
import 'package:p7/models/user.dart';
import 'package:p7/models/tutor_profile.dart';
import 'package:p7/pages/setting_page.dart';
import 'package:p7/pages/tutor_profile_setup_page.dart';
import 'package:p7/service/database_provider.dart';
import 'package:p7/service/tutor_profile_service.dart';
import 'package:provider/provider.dart';

import 'package:p7/components/avatar_picker.dart';

class ProfilePage extends StatefulWidget {
  final String uid;
  const ProfilePage({super.key, required this.uid});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final DatabaseProvider _databaseProvider;
  final _tutorProfileService = TutorProfileService();

  UserProfile? _user;
  TutorProfile? _tutorProfile; // Профиль репетитора (если есть)
  final _bioCtrl = TextEditingController();

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _databaseProvider = context.read<DatabaseProvider>();
    _loadUser();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final u = await _databaseProvider.userProfile(widget.uid);

    // Если пользователь - репетитор, загружаем его профиль
    TutorProfile? tutorProf;
    if (u?.role == 'Репетитор') {
      tutorProf = await _tutorProfileService.getTutorProfileByUserId(widget.uid);
    }

    if (mounted) {
      setState(() {
        _user = u;
        _tutorProfile = tutorProf;
        _loading = false;
      });
    }
  }

  /* ---------- BIO ----------- */

  void _showBioEditor() {
    _bioCtrl.text = _user?.bio ?? '';
    showDialog(
      context: context,
      builder: (_) => InputBox(
        textEditingController: _bioCtrl,
        hintText: 'Расскажите о себе',
        onPressed: _saveBio,
        onPressedText: 'Сохранить',
      ),
    );
  }

  Future<void> _saveBio() async {
    setState(() => _loading = true);

    await _databaseProvider.updateBio(_bioCtrl.text);
    await _loadUser();
    setState(() {
      _loading=false;
    });

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


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTutor = _user?.role == 'Репетитор';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
          ? Center(
              child: Text(
                'Пользователь не найден',
                style: TextStyle(color: colorScheme.onSurface),
              ),
            )
          : CustomScrollView(
              slivers: [
                // Gradient Header с аватаром
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: colorScheme.primary,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SettingPage()),
                        );
                      },
                      tooltip: 'Настройки',
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 60),
                          // Аватар
                          const AvatarPicker(),
                          const SizedBox(height: 16),
                          // Имя
                          Text(
                            _user!.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Badge роли
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isTutor
                                  ? Colors.amber.withValues(alpha: 0.9)
                                  : Colors.blue.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isTutor ? Icons.school : Icons.person,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _user!.role,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Контент
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Карточка "Информация"
                        _buildInfoCard(colorScheme),
                        const SizedBox(height: 16),

                        // Карточка "О себе"
                        _buildBioCard(colorScheme),
                        const SizedBox(height: 16),

                        // Карточка "Профиль репетитора" (только для репетиторов)
                        if (isTutor) _buildTutorProfileCard(colorScheme),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Карточка с информацией
  Widget _buildInfoCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ИНФОРМАЦИЯ',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Возраст
            _buildInfoRow(
              icon: Icons.cake,
              label: 'Возраст',
              value: '${_calculateAge(_user!.birthDate)} лет',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),

            // Город
            _buildInfoRow(
              icon: Icons.location_city,
              label: 'Город',
              value: _user!.city,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),

            // Email
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _user!.email,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  // Строка информации
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Карточка "О себе"
  Widget _buildBioCard(ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.chat_bubble_outline, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'О СЕБЕ',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _showBioEditor,
                  icon: Icon(Icons.edit, color: colorScheme.primary),
                  tooltip: 'Редактировать',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),
            Text(
              _user!.bio.isEmpty ? 'Расскажите о себе...' : _user!.bio,
              style: TextStyle(
                color: _user!.bio.isEmpty
                    ? colorScheme.onSurface.withValues(alpha: 0.4)
                    : colorScheme.onSurface,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Карточка профиля репетитора
  Widget _buildTutorProfileCard(ColorScheme colorScheme) {
    // Если профиль репетитора не заполнен, показываем кнопку создания
    if (_tutorProfile == null) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.school,
                size: 48,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Профиль репетитора не заполнен',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Заполните профиль, чтобы ученики могли найти вас',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TutorProfileSetupPage(),
                    ),
                  );
                  // Если профиль создан, перезагружаем страницу
                  if (result == true) {
                    _loadUser();
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Заполнить профиль'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Профиль заполнен - показываем данные
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'ПРОФИЛЬ РЕПЕТИТОРА',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TutorProfileSetupPage(
                          isEditing: true,
                        ),
                      ),
                    );
                    if (result == true) {
                      _loadUser();
                    }
                  },
                  icon: Icon(Icons.edit, color: colorScheme.primary),
                  tooltip: 'Редактировать профиль',
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 16),

            // Рейтинг
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _tutorProfile!.isReallyNewbie
                        ? Icons.new_releases
                        : Icons.star,
                    color: Colors.amber,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _tutorProfile!.getRatingDisplay(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Предметы
            if (_tutorProfile!.subjects.isNotEmpty) ...[
              _buildTutorInfoSection(
                icon: Icons.book,
                title: 'Предметы',
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tutorProfile!.subjects
                    .map((subject) => Chip(
                          label: Text(subject),
                          backgroundColor:
                              colorScheme.primary.withValues(alpha: 0.1),
                          labelStyle: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Цена
            _buildTutorInfoRow(
              icon: Icons.attach_money,
              label: 'Стоимость',
              value: _tutorProfile!.getPriceDisplay(),
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),

            // Опыт
            if (_tutorProfile!.experience != null) ...[
              _buildTutorInfoRow(
                icon: Icons.work_outline,
                label: 'Опыт работы',
                value: _tutorProfile!.getExperienceDisplay(),
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 12),
            ],

            // Формат занятий
            _buildTutorInfoRow(
              icon: Icons.computer,
              label: 'Формат занятий',
              value: _tutorProfile!.getLessonFormatDisplay(),
              colorScheme: colorScheme,
            ),

            // Образование
            if (_tutorProfile!.education != null &&
                _tutorProfile!.education!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTutorInfoSection(
                icon: Icons.school_outlined,
                title: 'Образование',
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 8),
              Text(
                _tutorProfile!.education!,
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Секция информации репетитора
  Widget _buildTutorInfoSection({
    required IconData icon,
    required String title,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  // Строка информации репетитора
  Widget _buildTutorInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required ColorScheme colorScheme,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}