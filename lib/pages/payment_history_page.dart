import 'package:flutter/material.dart';
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

  // Кэш имён пользователей
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    try {
      final userId = _auth.getCurrentUid();
      final user = await _db.getUserFromPocketBase(userId);
      _isTutor = user?.role == 'Репетитор';

      if (_isTutor) {
        _payments = await _paymentService.getPaymentsByTutor(userId);
        _totalAmount = await _paymentService.getTutorTotalEarnings(userId);
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
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
                      margin: const EdgeInsets.all(16),
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
                    // Список
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _payments.length,
                        itemBuilder: (context, index) {
                          final payment = _payments[index];
                          final otherId = _isTutor ? payment.studentId : payment.tutorId;
                          final otherName = _nameCache[otherId] ?? 'Пользователь';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: payment.isCompleted
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.orange.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    payment.isCompleted
                                        ? Icons.check_circle
                                        : Icons.pending,
                                    color: payment.isCompleted ? Colors.green : Colors.orange,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        otherName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: colorScheme.onSurface,
                                        ),
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
                      ),
                    ),
                  ],
                ),
    );
  }
}
