import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/schedule_slot.dart';
import '../service/card_storage_service.dart';
import '../service/payment_service.dart';
import '../service/schedule_service.dart';
import '../service/auth.dart';

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) {
      return oldValue;
    }
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class PaymentDialog extends StatefulWidget {
  final ScheduleSlot slot;
  final String tutorId;
  final String tutorName;
  final double? suggestedAmount;

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
  final _cardStorage = CardStorageService();
  final _auth = Auth();

  final _amountController = TextEditingController();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _holderController = TextEditingController();

  bool _isProcessing = false;
  String _paymentMethod = 'app';

  SavedCard? _savedCard;
  bool _useSavedCard = false;
  bool _cvvVisible = false;

  @override
  void initState() {
    super.initState();
    if (widget.suggestedAmount != null) {
      _amountController.text = widget.suggestedAmount!.toInt().toString();
    }
    _loadSavedCard();
  }

  Future<void> _loadSavedCard() async {
    final card = await _cardStorage.getSavedCard();
    if (mounted && card != null) {
      setState(() {
        _savedCard = card;
        _useSavedCard = true;
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _holderController.dispose();
    super.dispose();
  }


  Future<void> _processPayment() async {
    if (_paymentMethod == 'app') {
      if (!_useSavedCard || _savedCard == null) {
        final error = _validateCardForm();
        if (error != null) {
          _showError(error);
          return;
        }
      }
    }

    setState(() => _isProcessing = true);

    try {
      final slotExists = await _checkSlotExists();
      if (!slotExists) {
        throw Exception('Занятие не найдено. Возможно, оно было удалено репетитором.');
      }

      if (_paymentMethod == 'app') {
        await _processAppPayment();
      } else {
        await _processExternalPayment();
      }
    } catch (e) {
      debugPrint('[PaymentDialog] ❌ Ошибка оплаты: $e');
      _showError('Ошибка оплаты: $e');
      setState(() => _isProcessing = false);
    }
  }

  String? _validateCardForm() {
    final digits =
        _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 16) return 'Введите корректный номер карты (16 цифр)';

    final expiry = _expiryController.text;
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiry)) {
      return 'Введите срок действия карты (ММ/ГГ)';
    }
    final parts = expiry.split('/');
    final month = int.tryParse(parts[0]) ?? 0;
    final year = int.tryParse(parts[1]) ?? 0;
    if (month < 1 || month > 12) return 'Некорректный месяц срока действия';
    final now = DateTime.now();
    final expDate =
        DateTime(2000 + year, month + 1); // первый день следующего месяца
    if (expDate.isBefore(now)) return 'Срок действия карты истёк';

    if (_cvvController.text.length < 3) return 'Введите CVV (3 цифры)';
    if (_holderController.text.trim().isEmpty) {
      return 'Введите имя держателя карты';
    }
    return null;
  }

  Future<bool> _checkSlotExists() async {
    try {
      final slot = await _scheduleService.getSlotById(widget.slot.id);
      return slot != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _processAppPayment() async {
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

    final payment = await _paymentService.createPayment(
      studentId: _auth.getCurrentUid(),
      tutorId: widget.tutorId,
      slotId: widget.slot.id,
      amount: amount,
    );
    if (payment == null) throw Exception('Не удалось создать платёж');

    await _scheduleService.updateSlotFields(widget.slot.id, {'isPaid': true});

    if (!_useSavedCard && mounted) {
      await _offerSaveCard();
    }

    if (mounted) {
      Navigator.of(context).pop('app');
      _showSuccess('Оплата прошла успешно! 🎉');
    }
  }

  Future<void> _processExternalPayment() async {
    await _scheduleService.updateSlotFields(widget.slot.id, {'isPaid': true});
    if (mounted) {
      Navigator.of(context).pop('external');
      _showSuccess('Занятие помечено как оплаченное ✅');
    }
  }

  Future<void> _offerSaveCard() async {
    final digits =
        _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final last4 = digits.substring(digits.length - 4);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Сохранить карту?'),
        content: Text('Сохранить карту •••• $last4 для быстрой оплаты?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Нет'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final card = SavedCard(
        last4: last4,
        expiry: _expiryController.text,
        holder: _holderController.text.trim().toUpperCase(),
        network: SavedCard.detectNetwork(
            _cardNumberController.text),
      );
      await _cardStorage.saveCard(card);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    String msg = message;
    if (msg.contains('404') || msg.contains('not found')) {
      msg = 'Занятие не найдено. Возможно, оно было удалено.';
    } else if (msg.contains('ClientException')) {
      msg = 'Ошибка подключения к серверу.';
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white),
        const SizedBox(width: 12),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(colorScheme),
              const SizedBox(height: 20),
              _buildLessonInfo(colorScheme),
              const SizedBox(height: 20),
              _buildMethodSelector(colorScheme),
              const SizedBox(height: 20),
              if (_paymentMethod == 'app') ...[
                _buildAmountField(colorScheme),
                const SizedBox(height: 20),
                _buildCardSection(colorScheme),
                const SizedBox(height: 20),
              ] else ...[
                _buildExternalInfo(colorScheme),
                const SizedBox(height: 20),
              ],
              _buildActions(colorScheme),
              const SizedBox(height: 12),
              if (_paymentMethod == 'app') _buildMockNote(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.payment, color: colorScheme.primary, size: 28),
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
              Text(
                'Имитация оплаты для диплома',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLessonInfo(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _infoRow(Icons.person, 'Репетитор', widget.tutorName, colorScheme),
          const SizedBox(height: 10),
          _infoRow(
            Icons.calendar_today,
            'Дата',
            '${widget.slot.date.day.toString().padLeft(2, '0')}.${widget.slot.date.month.toString().padLeft(2, '0')}.${widget.slot.date.year}',
            colorScheme,
          ),
          const SizedBox(height: 10),
          _infoRow(
            Icons.access_time,
            'Время',
            '${widget.slot.startTime} — ${widget.slot.endTime}',
            colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon, String label, String value, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.primary),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(
                fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6))),
        Expanded(
          child: Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildMethodSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Способ оплаты',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _methodButton(
                  method: 'app',
                  icon: Icons.credit_card,
                  label: 'Через\nприложение',
                  cs: colorScheme),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _methodButton(
                  method: 'external',
                  icon: Icons.handshake_outlined,
                  label: 'Сторонняя\nоплата',
                  cs: colorScheme),
            ),
          ],
        ),
      ],
    );
  }

  Widget _methodButton({
    required String method,
    required IconData icon,
    required String label,
    required ColorScheme cs,
  }) {
    final selected = _paymentMethod == method;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = method),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.1)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                size: 30,
                color:
                    selected ? cs.primary : cs.onSurface.withValues(alpha: 0.5)),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: 0.7),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Сумма оплаты',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface)),
        const SizedBox(height: 8),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Введите сумму в рублях',
            prefixIcon:
                Icon(Icons.currency_ruble, color: colorScheme.primary),
            suffixText: '₽',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
        if (widget.suggestedAmount != null) ...[
          const SizedBox(height: 6),
          Text(
            'Рекомендуемая стоимость: ${widget.suggestedAmount!.toInt()} ₽',
            style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurface.withValues(alpha: 0.55)),
          ),
        ],
      ],
    );
  }


  Widget _buildCardSection(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Данные карты',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface)),
        const SizedBox(height: 12),


        if (_savedCard != null) ...[
          _buildSavedCardTile(colorScheme),
          const SizedBox(height: 8),
          _buildNewCardTile(colorScheme),
        ] else ...[
          _buildCardForm(colorScheme),
        ],

        if (_savedCard != null && !_useSavedCard) ...[
          const SizedBox(height: 12),
          _buildCardForm(colorScheme),
        ],
      ],
    );
  }

  Widget _buildSavedCardTile(ColorScheme colorScheme) {
    final card = _savedCard!;
    return InkWell(
      onTap: () => setState(() => _useSavedCard = true),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _useSavedCard
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _useSavedCard
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: _useSavedCard ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: true,
              groupValue: _useSavedCard,
              onChanged: (_) => setState(() => _useSavedCard = true),
              activeColor: colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            _cardNetworkIcon(card.network),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.displayName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${card.holder}  •  ${card.expiry}',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            colorScheme.onSurface.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline,
                  size: 20, color: colorScheme.error),
              tooltip: 'Удалить карту',
              onPressed: () async {
                await _cardStorage.removeCard();
                setState(() {
                  _savedCard = null;
                  _useSavedCard = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewCardTile(ColorScheme colorScheme) {
    return InkWell(
      onTap: () => setState(() => _useSavedCard = false),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: !_useSavedCard
              ? colorScheme.primary.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: !_useSavedCard
                ? colorScheme.primary
                : colorScheme.outline.withValues(alpha: 0.3),
            width: !_useSavedCard ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Radio<bool>(
              value: false,
              groupValue: _useSavedCard,
              onChanged: (_) => setState(() => _useSavedCard = false),
              activeColor: colorScheme.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 4),
            Icon(Icons.add_card_outlined,
                size: 22, color: colorScheme.onSurface.withValues(alpha: 0.7)),
            const SizedBox(width: 10),
            Text('Другая карта',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color:
                        colorScheme.onSurface.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _buildCardForm(ColorScheme colorScheme) {
    return Column(
      children: [
        TextField(
          controller: _cardNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: [_CardNumberFormatter()],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: '0000 0000 0000 0000',
            labelText: 'Номер карты',
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _cardNetworkIcon(SavedCard.detectNetwork(
                  _cardNumberController.text)),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Срок + CVV
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expiryController,
                keyboardType: TextInputType.number,
                inputFormatters: [_ExpiryFormatter()],
                decoration: InputDecoration(
                  labelText: 'ММ/ГГ',
                  hintText: '12/28',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _cvvController,
                keyboardType: TextInputType.number,
                obscureText: !_cvvVisible,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                decoration: InputDecoration(
                  labelText: 'CVV',
                  hintText: '•••',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _cvvVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _cvvVisible = !_cvvVisible),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color:
                            colorScheme.outline.withValues(alpha: 0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _holderController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Имя держателя карты',
            hintText: 'IVAN IVANOV',
            prefixIcon: Icon(Icons.person_outline, color: colorScheme.primary),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: colorScheme.outline.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExternalInfo(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Вы договорились об оплате вне приложения. Занятие будет помечено как оплаченное.',
              style: TextStyle(
                  fontSize: 13, color: Colors.blue[700], height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed:
                _isProcessing ? null : () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Отмена',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface)),
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
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _paymentMethod == 'app' ? 'Оплатить' : 'Подтвердить',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMockNote(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Реальные деньги не списываются. Это имитация для демонстрации.',
              style: TextStyle(
                  fontSize: 11, color: Colors.orange[700], height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  /// Иконка/бейдж платёжной сети
  Widget _cardNetworkIcon(String network) {
    switch (network) {
      case 'visa':
        return _networkBadge('VISA', Colors.blue[700]!);
      case 'mastercard':
        return _networkBadge('MC', Colors.orange[800]!);
      case 'mir':
        return _networkBadge('МИР', Colors.green[700]!);
      default:
        return Icon(Icons.credit_card, size: 22, color: Colors.grey[500]);
    }
  }

  Widget _networkBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

}
