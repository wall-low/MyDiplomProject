import 'package:flutter/material.dart';
import 'package:p7/models/tutor_profile.dart';
import 'package:p7/models/user.dart';
import 'package:p7/pages/chat_page.dart';
import 'package:p7/pages/tutor_schedule_view_page.dart';

/// Страница детального профиля репетитора
///
/// Показывает полную информацию о репетиторе:
/// - Аватар, имя, рейтинг
/// - Предметы, цена, опыт, образование
/// - Формат занятий (онлайн/оффлайн)
/// - Биография
/// - Кнопки "Написать" и "Расписание"
class TutorProfilePage extends StatelessWidget {
  final TutorProfile tutorProfile;
  final UserProfile userProfile;

  const TutorProfilePage({
    super.key,
    required this.tutorProfile,
    required this.userProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Шапка с градиентом и аватаром
          _buildHeader(context),

          // Основной контент
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Рейтинг
                _buildRatingCard(context),

                const SizedBox(height: 16),

                // Информация
                _buildInfoCard(context),

                const SizedBox(height: 16),

                // О себе
                if (userProfile.bio.isNotEmpty) _buildBioCard(context),

                const SizedBox(height: 100), // Отступ для кнопок
              ],
            ),
          ),
        ],
      ),

      // Кнопки внизу
      bottomNavigationBar: _buildBottomButtons(context),
    );
  }

  /// Шапка с градиентом, аватаром и именем (как на макете)
  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue[400]!,
                Colors.blue[300]!,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40), // Отступ от AppBar

              // Большой круглый аватар
              CircleAvatar(
                radius: 70,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 67,
                  backgroundColor: Colors.blue[200],
                  backgroundImage: userProfile.avatarUrl != null &&
                          userProfile.avatarUrl!.isNotEmpty
                      ? NetworkImage(userProfile.avatarUrl!)
                      : null,
                  child: userProfile.avatarUrl == null ||
                          userProfile.avatarUrl!.isEmpty
                      ? Text(
                          userProfile.name.isNotEmpty
                              ? userProfile.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 50,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
              ),

              const SizedBox(height: 16),

              // Имя репетитора
              Text(
                userProfile.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Карточка с рейтингом (как на макете)
  Widget _buildRatingCard(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Звезда и рейтинг
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star, color: Colors.orange, size: 28),
                const SizedBox(width: 8),
                Text(
                  tutorProfile.isReallyNewbie
                      ? 'Новичок'
                      : tutorProfile.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            // Количество оплаченных занятий
            Text(
              tutorProfile.isReallyNewbie
                  ? 'Новичок на платформе'
                  : '(${tutorProfile.totalPaidLessons} ${_getPluralLessons(tutorProfile.totalPaidLessons)})',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Карточка "Информация" (как на макете)
  Widget _buildInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок "Информация"
          const Text(
            'Информация',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Предметы (синие чипы)
          if (tutorProfile.subjects.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tutorProfile.subjects.map((subject) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    subject,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Цена
          _buildInfoRow(
            Icons.payments_outlined,
            tutorProfile.getPriceDisplay(),
          ),

          const SizedBox(height: 12),

          // Опыт
          if (tutorProfile.experience != null)
            _buildInfoRow(
              Icons.school_outlined,
              '${tutorProfile.experience} ${_getPluralYears(tutorProfile.experience!)} опыта',
            ),

          const SizedBox(height: 12),

          // Образование
          if (tutorProfile.education != null &&
              tutorProfile.education!.isNotEmpty)
            _buildInfoRow(
              Icons.workspace_premium_outlined,
              tutorProfile.education!,
            ),

          const SizedBox(height: 16),

          // Формат занятий (зеленые чипы)
          if (tutorProfile.lessonFormat.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tutorProfile.lessonFormat.map((format) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    format == 'online' ? 'Онлайн' : 'Оффлайн',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Строка информации с иконкой
  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  /// Карточка "О себе" (как на макете)
  Widget _buildBioCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок "О себе"
          const Text(
            'О себе',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // Текст биографии
          Text(
            userProfile.bio,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[800],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Две кнопки внизу: "Написать" и "Расписание" (как на макете)
  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Кнопка "Написать" (белая с контуром)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatPage(
                        receiverName: userProfile.name,
                        receiverID: userProfile.uid,
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Написать',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Кнопка "Расписание" (синяя filled)
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  // Открываем расписание репетитора для просмотра и бронирования
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TutorScheduleViewPage(
                        tutorId: userProfile.uid,
                        tutorName: userProfile.name,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Расписание',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Склонение слова "занятие"
  String _getPluralLessons(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'оплаченное занятие';
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return 'оплаченных занятия';
    } else {
      return 'оплаченных занятий';
    }
  }

  /// Склонение слова "год"
  String _getPluralYears(int years) {
    if (years % 10 == 1 && years % 100 != 11) {
      return 'год';
    } else if ([2, 3, 4].contains(years % 10) &&
        ![12, 13, 14].contains(years % 100)) {
      return 'года';
    } else {
      return 'лет';
    }
  }
}
