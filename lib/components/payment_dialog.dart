import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/schedule_slot.dart';
import '../service/payment_service.dart';
import '../service/schedule_service.dart';
import '../service/auth.dart';

/// Диалог имитации оплаты занятия (для диплома)
///
/// Показывается после прошедшего занятия, если slot.isPaid = false
///
/// Процесс:
/// 1. Ученик вводит сумму (или берётся цена репетитора)
/// 2. Нажимает "Оплатить"
/// 3. Создаётся запись в payments
/// 4. Обновляется slot.isPaid = true
/// 5. (TODO в будущем) Показывается форма отзыва
class PaymentDialog extends StatefulWidget {
  final ScheduleSlot slot;
  final String tutorId;
  final String tutorName;
  final double? suggestedAmount; // Рекомендуемая сумма (из профиля репетитора)

  const PaymentDialog({
    super.key,
    required this.slot,
    required this.tutorId,
    required this.tutorName,
    this.suggestedAmount,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  final _paymentService = PaymentService();
  final _scheduleService = ScheduleService();
  final _auth = Auth();
  final _amountController = TextEditingController();
  bool _isProcessing = false;

  // Способ оплаты: 'app' (через приложение) или 'external' (сторонняя)
  String _paymentMethod = 'app';

  @override
  void initState() {
    super.initState();
    // Устанавливаем рекомендуемую сумму (если есть)
    if (widget.suggestedAmount != null) {
      _amountController.text = widget.suggestedAmount!.toInt().toString();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Обработка оплаты
  Future<void> _processPayment() async {
    setState(() => _isProcessing = true);

    try {
      // Сначала проверяем, существует ли слот
      final slotExists = await _checkSlotExists();
      if (!slotExists) {
        throw Exception('Занятие не найдено. Возможно, оно было удалено репетитором.');
      }

      if (_paymentMethod == 'app') {
        // Оплата через приложение - требует сумму
        await _processAppPayment();
      } else {
        // Сторонняя оплата - просто помечаем как оплачено
        await _processExternalPayment();
      }
    } catch (e) {
      debugPrint('[PaymentDialog] ❌ Ошибка оплаты: $e');
      _showError('Ошибка оплаты: $e');
      setState(() => _isProcessing = false);
    }
  }

  /// Проверка существования слота
  Future<bool> _checkSlotExists() async {
    try {
      debugPrint('[PaymentDialog] 🔍 Проверяю существование слота: ${widget.slot.id}');
      debugPrint('[PaymentDialog] 📋 Данные слота: tutorId=${widget.slot.tutorId}, studentId=${widget.slot.studentId}, isBooked=${widget.slot.isBooked}');

      final slot = await _scheduleService.getSlotById(widget.slot.id);

      if (slot != null) {
        debugPrint('[PaymentDialog] ✅ Слот найден: ${slot.id}');
      } else {
        debugPrint('[PaymentDialog] ❌ Слот НЕ найден (null)');
      }

      return slot != null;
    } catch (e, stackTrace) {
      debugPrint('[PaymentDialog] ⚠️ Ошибка проверки слота: $e');
      debugPrint('[PaymentDialog] 📚 StackTrace: $stackTrace');
      return false;
    }
  }

  /// Оплата через приложение (mock)
  Future<void> _processAppPayment() async {
    // Валидация суммы
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showError('Введите сумму оплаты');
      setState(() => _isProcessing = false);
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showError('Некорректная сумма');
      setState(() => _isProcessing = false);
      return;
    }

    debugPrint('[PaymentDialog] 💳 Оплата через приложение...');

    // 1. Создаём платёж
    final payment = await _paymentService.createPayment(
      studentId: _auth.getCurrentUid(),
      tutorId: widget.tutorId,
      slotId: widget.slot.id,
      amount: amount,
    );

    if (payment == null) {
      throw Exception('Не удалось создать платёж');
    }

    debugPrint('[PaymentDialog] ✅ Платёж создан: ${payment.id}');

    // 2. Обновляем slot.isPaid = true
    await _scheduleService.updateSlotFields(
      widget.slot.id,
      {'isPaid': true},
    );

    debugPrint('[PaymentDialog] ✅ Слот помечен как оплаченный');

    // 3. Закрываем диалог с результатом success
    if (mounted) {
      Navigator.of(context).pop(true); // true = оплата успешна
      _showSuccess('Оплата через приложение прошла успешно! 🎉');
    }
  }

  /// Сторонняя оплата (без участия приложения)
  Future<void> _processExternalPayment() async {
    debugPrint('[PaymentDialog] 💵 Сторонняя оплата (без payment записи)...');

    // Просто помечаем слот как оплаченный, НЕ создаём payment
    await _scheduleService.updateSlotFields(
      widget.slot.id,
      {'isPaid': true},
    );

    debugPrint('[PaymentDialog] ✅ Слот помечен как оплаченный (внешняя оплата)');

    // Закрываем диалог
    if (mounted) {
      Navigator.of(context).pop(true);
      _showSuccess('Занятие помечено как оплаченное ✅');
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    // Упрощаем текст ошибки для пользователя
    String userMessage = message;
    if (message.contains('404') || message.contains('not found') || message.contains('wasn\'t found')) {
      userMessage = 'Занятие не найдено. Возможно, оно было удалено.';
    } else if (message.contains('ClientException')) {
      userMessage = 'Ошибка подключения к серверу. Проверьте интернет.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(userMessage)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.payment,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Оплата занятия',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Имитация оплаты для диплома',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Информация о занятии
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    Icons.person,
                    'Репетитор',
                    widget.tutorName,
                    colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.calendar_today,
                    'Дата',
                    '${widget.slot.date.day}.${widget.slot.date.month}.${widget.slot.date.year}',
                    colorScheme,
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.access_time,
                    'Время',
                    '${widget.slot.startTime} - ${widget.slot.endTime}',
                    colorScheme,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Выбор способа оплаты
            Text(
              'Способ оплаты',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Кнопки выбора способа
            Row(
              children: [
                Expanded(
                  child: _buildPaymentMethodButton(
                    method: 'app',
                    icon: Icons.credit_card,
                    label: 'Через\nприложение',
                    colorScheme: colorScheme,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPaymentMethodButton(
                    method: 'external',
                    icon: Icons.handshake_outlined,
                    label: 'Сторонняя\nоплата',
                    colorScheme: colorScheme,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Поле ввода суммы (только для оплаты через приложение)
            if (_paymentMethod == 'app') ...[
              Text(
                'Сумма оплаты',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                hintText: 'Введите сумму в рублях',
                prefixIcon: Icon(Icons.currency_ruble, color: colorScheme.primary),
                suffixText: '₽',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),

              if (widget.suggestedAmount != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Рекомендуемая стоимость: ${widget.suggestedAmount!.toInt()} ₽',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ] else ...[
              // Информация о сторонней оплате
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Вы договорились об оплате вне приложения. Занятие будет помечено как оплаченное, но сумма не будет зафиксирована в системе.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue[700],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Кнопки действий
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Отмена',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _paymentMethod == 'app'
                                ? 'Оплатить'
                                : 'Подтвердить',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Уведомление о mock-оплате (только для оплаты через приложение)
            if (_paymentMethod == 'app')
              Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange[700],
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Реальные деньги не списываются. Это имитация для демонстрации работы приложения.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.orange[700],
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Кнопка выбора способа оплаты
  Widget _buildPaymentMethodButton({
    required String method,
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _paymentMethod == method;

    return InkWell(
      onTap: () {
        setState(() {
          _paymentMethod = method;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withOpacity(0.1)
              : colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.8),
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value,
    ColorScheme colorScheme,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
