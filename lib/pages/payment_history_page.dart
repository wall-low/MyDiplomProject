import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../models/payment.dart';
import '../service/auth.dart';
import '../service/databases.dart';
import '../service/payment_service.dart';

class PaymentHistoryPage extends StatefulWidget {
  const PaymentHistoryPage({super.key});

  @override
  State<PaymentHistoryPage> createState() => _PaymentHistoryPageState();
}

class _PaymentHistoryPageState extends State<PaymentHistoryPage> {
  final PaymentService _paymentService = PaymentService();
  final Auth _auth = Auth();
  final Databases _db = Databases();

  bool _isLoading = true;
  List<Payment> _payments = [];
  double _totalAmount = 0;
  bool _isTutor = false;

  // Статистика текущего месяца (только для репетиторов)
  double _thisMonthEarnings = 0;
  int _thisMonthCount = 0;

  // Кэш имён пользователей
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ru', null).then((_) => _loadPayments());
  }

  Future<void> _loadPayments() async {
    try {
      final userId = _auth.getCurrentUid();
      final user = await _db.getUserFromPocketBase(userId);
      _isTutor = user?.role == 'Репетитор';

      if (_isTutor) {
        _payments = await _paymentService.getPaymentsByTutor(userId);
        _totalAmount = await _paymentService.getTutorTotalEarnings(userId);
        final monthStats = await _paymentService.getTutorThisMonthStats(userId);
        _thisMonthEarnings = monthStats['earnings'] as double;
        _thisMonthCount = monthStats['count'] as int;
      } else {
        _payments = await _paymentService.getPaymentsByStudent(userId);
        _totalAmount = await _paymentService.getStudentTotalSpending(userId);
      }

      // Загружаем имена
      final ids = _isTutor
          ? _payments.map((p) => p.studentId).toSet()
          : _payments.map((p) => p.tutorId).toSet();
      for (final id in ids) {
        if (id.isEmpty) continue;
        try {
          final u = await _db.getUserFromPocketBase(id);
          _nameCache[id] = u?.name ?? 'Пользователь';
        } catch (_) {
          _nameCache[id] = 'Пользователь';
        }
      }
    } catch (e) {
      debugPrint('[PaymentHistory] Error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  /// Группирует платежи по месяцу: "Март 2026" → [payments]
  Map<String, List<Payment>> _groupByMonth(List<Payment> payments) {
    final grouped = <String, List<Payment>>{};
    for (final p in payments) {
      final key = DateFormat('LLLL yyyy', 'ru').format(p.created);
      grouped.putIfAbsent(key, () => []).add(p);
    }
    return grouped;
  }

  Future<void> _showAddManualPaymentDialog(ColorScheme colorScheme) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оплата вне приложения'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Сумма, ₽',
                prefixIcon: Icon(Icons.payments),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Примечание (необязательно)',
                hintText: 'Имя ученика, предмет...',
                prefixIcon: Icon(Icons.notes),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text.trim());
              if (amount == null || amount <= 0) return;
              Navigator.pop(ctx);
              final userId = _auth.getCurrentUid();
              await _paymentService.createManualPayment(
                tutorId: userId,
                amount: amount,
                note: noteCtrl.text.trim(),
              );
              await _loadPayments();
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      floatingActionButton: _isTutor
          ? FloatingActionButton(
              onPressed: () => _showAddManualPaymentDialog(colorScheme),
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              tooltip: 'Добавить оплату вручную',
              child: const Icon(Icons.add),
            )
          : null,
      appBar: AppBar(
        title: Text(
          _isTutor ? 'Доходы' : 'Расходы',
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : _payments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 80,
                        color: colorScheme.secondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Нет платежей',
                        style: TextStyle(
                          color: colorScheme.secondary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Итого
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isTutor ? Icons.trending_up : Icons.account_balance_wallet,
                            color: colorScheme.onPrimary,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isTutor ? 'Общий доход' : 'Общие расходы',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_totalAmount.toInt()} \u20BD',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${_payments.length} платежей',
                            style: TextStyle(
                              color: colorScheme.onPrimary.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Карточки текущего месяца (только для репетитора)
                    if (_isTutor) ...[
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildMiniStat(
                                colorScheme: colorScheme,
                                icon: Icons.calendar_month,
                                label: 'В этом месяце',
                                value: '${_thisMonthEarnings.toInt()} \u20BD',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMiniStat(
                                colorScheme: colorScheme,
                                icon: Icons.school,
                                label: 'Занятий в месяце',
                                value: '$_thisMonthCount',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildMiniStat(
                                colorScheme: colorScheme,
                                icon: Icons.calculate,
                                label: 'Средний чек',
                                value: _payments.isNotEmpty
                                    ? '${(_totalAmount / _payments.length).toInt()} \u20BD'
                                    : '—',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),

                    // Список, сгруппированный по месяцам
                    Expanded(
                      child: _buildGroupedList(colorScheme),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMiniStat({
    required ColorScheme colorScheme,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList(ColorScheme colorScheme) {
    final grouped = _groupByMonth(_payments);

    // Собираем плоский список: заголовок + платежи
    final items = <dynamic>[];
    for (final entry in grouped.entries) {
      final monthTotal = entry.value
          .where((p) => p.isCompleted)
          .fold<double>(0.0, (sum, p) => sum + p.amount);
      items.add({'header': entry.key, 'total': monthTotal});
      items.addAll(entry.value);
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item is Map && item.containsKey('header')) {
          // Заголовок месяца
          return Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _capitalize(item['header'] as String),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (_isTutor)
                  Text(
                    '${(item['total'] as double).toInt()} \u20BD',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          );
        }

        // Карточка платежа
        final payment = item as Payment;
        final isManual = payment.isManual;
        final isExternal = payment.isExternal;
        final otherId = _isTutor ? payment.studentId : payment.tutorId;
        final otherName = isManual
            ? (otherId.isNotEmpty ? otherId : 'Вне приложения')
            : (_nameCache[otherId] ?? 'Пользователь');

        Color cardColor;
        Color? borderColor;
        Color iconBg;
        Color iconColor;
        IconData iconData;

        if (isManual) {
          cardColor = Colors.amber.withValues(alpha: 0.08);
          borderColor = Colors.amber.withValues(alpha: 0.4);
          iconBg = Colors.amber.withValues(alpha: 0.15);
          iconColor = Colors.amber.shade700;
          iconData = Icons.payments_outlined;
        } else if (isExternal) {
          cardColor = Colors.teal.withValues(alpha: 0.07);
          borderColor = Colors.teal.withValues(alpha: 0.35);
          iconBg = Colors.teal.withValues(alpha: 0.12);
          iconColor = Colors.teal.shade700;
          iconData = Icons.handshake_outlined;
        } else {
          cardColor = colorScheme.primaryContainer.withValues(alpha: 0.3);
          borderColor = null;
          iconBg = payment.isCompleted
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1);
          iconColor = payment.isCompleted ? Colors.green : Colors.orange;
          iconData = payment.isCompleted ? Icons.check_circle : Icons.pending;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1)
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            otherName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isManual) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'наличные',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.amber.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ] else if (isExternal) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'вне приложения',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.teal.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      payment.getCreatedDisplay(),
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_isTutor ? '+' : '-'}${payment.getAmountDisplay()}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _isTutor ? Colors.green : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
