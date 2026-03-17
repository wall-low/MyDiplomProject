import 'package:flutter/material.dart';
import 'package:p7/models/schedule_slot.dart';
import 'package:p7/service/review_service.dart';

class ReviewDialog extends StatefulWidget {
  final ScheduleSlot slot;
  final String tutorId;
  final String studentId;
  final String tutorName;

  final bool isVerified;

  const ReviewDialog({
    super.key,
    required this.slot,
    required this.tutorId,
    required this.studentId,
    required this.tutorName,
    this.isVerified = true,
  });

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  final _reviewService = ReviewService();
  final _commentController = TextEditingController();

  int _selectedRating = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.isVerified && _selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите оценку'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!widget.isVerified && _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Напишите текст отзыва'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final review = await _reviewService.createReview(
      tutorId: widget.tutorId,
      studentId: widget.studentId,
      lessonId: widget.slot.id,
      rating: widget.isVerified ? _selectedRating : null,
      comment: _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
      isVerified: widget.isVerified,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (review != null) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Отзыв отправлен, спасибо!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Не удалось отправить отзыв. Попробуйте позже.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Иконка
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: widget.isVerified
                    ? Colors.amber.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isVerified ? Icons.star_rounded : Icons.rate_review_outlined,
                color: widget.isVerified ? Colors.amber : Colors.grey[500],
                size: 30,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              widget.isVerified ? 'Оцените занятие' : 'Написать отзыв',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Репетитор: ${widget.tutorName}',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            Text(
              '${widget.slot.date.day}.${widget.slot.date.month.toString().padLeft(2, '0')}.${widget.slot.date.year}  ${widget.slot.startTime}–${widget.slot.endTime}',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),

            if (widget.isVerified) ...[
              // Звёзды
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final star = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedRating = star),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        star <= _selectedRating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: star <= _selectedRating
                            ? Colors.amber
                            : Colors.grey[400],
                        size: 40,
                      ),
                    ),
                  );
                }),
              ),
              if (_selectedRating > 0) ...[
                const SizedBox(height: 6),
                Text(
                  _ratingLabel(_selectedRating),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '⭐ Оценка в звёздах доступна только при оплате через приложение — это влияет на рейтинг репетитора в поиске.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: _commentController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: widget.isVerified
                    ? 'Напишите отзыв (необязательно)...'
                    : 'Поделитесь впечатлением о занятии...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.tertiary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Пропустить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Отправить',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Очень плохо';
      case 2:
        return 'Плохо';
      case 3:
        return 'Нормально';
      case 4:
        return 'Хорошо';
      case 5:
        return 'Отлично!';
      default:
        return '';
    }
  }
}
