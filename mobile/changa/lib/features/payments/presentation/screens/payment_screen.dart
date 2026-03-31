import 'package:changa/core/constants/app_constants.dart';
import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/payments/presentation/providers/payments_provider.dart';
import 'package:changa/features/projects/data/models/project_models.dart';
import 'package:changa/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String projectId;
  const PaymentScreen({super.key, required this.projectId});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with SingleTickerProviderStateMixin {
  final _amountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  double? _selectedAmount;
  String _provider = 'mpesa'; // 'mpesa' | 'airtel'
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );

    // Pre-fill phone from user profile
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProvider);
      if (user != null) _phoneCtrl.text = user.phone;
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _phoneCtrl.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  double? get _amount {
    if (_selectedAmount != null) return _selectedAmount;
    final text = _amountCtrl.text.replaceAll(',', '');
    return double.tryParse(text);
  }

  bool get _canPay {
    final amount = _amount;
    if (amount == null || amount < 1) return false;
    final phone = _phoneCtrl.text.trim();
    return RegExp(r'^254[17]\d{8}$').hasMatch(phone);
  }

  Future<void> _pay() async {
    if (!_canPay) {
      _shakeCtrl.forward(from: 0);
      return;
    }

    final notifier = ref.read(paymentInitProvider.notifier);
    if (_provider == 'mpesa') {
      await notifier.payMpesa(
        projectId: widget.projectId,
        amount: _amount!,
        phone: _phoneCtrl.text.trim(),
      );
    } else {
      await notifier.payAirtel(
        projectId: widget.projectId,
        amount: _amount!,
        phone: _phoneCtrl.text.trim(),
      );
    }

    final state = ref.read(paymentInitProvider);
    if (state is PaymentInitSuccess && mounted) {
      context.pushReplacement(
        AppRoutes.paymentStatusPath(
          state.contribution.reference,
          state.contribution.amount,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(paymentInitProvider);
    final isLoading = initState is PaymentInitLoading;
    final error = initState is PaymentInitError ? initState.message : null;

    final projectAsync = ref.watch(projectDetailProvider(widget.projectId));
    final project = projectAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('Contribute'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(paymentInitProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Project summary card ───────────────────────────────────────
            if (project != null) _ProjectSummaryCard(project: project),
            const SizedBox(height: 24),

            // ── Amount section ─────────────────────────────────────────────
            _SectionLabel('How much?'),
            const SizedBox(height: 12),

            // Quick amount chips
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppConstants.quickAmounts.map((amt) {
                final selected = _selectedAmount == amt;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedAmount = selected ? null : amt;
                      if (!selected) _amountCtrl.clear();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.forest : Colors.white,
                      borderRadius: AppRadius.pillAll,
                      border: Border.all(
                        color: selected ? AppColors.forest : AppColors.sand,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      CurrencyFormatter.formatCompact(amt),
                      style: AppTextStyles.button.copyWith(
                        color: selected ? AppColors.cream : AppColors.forest,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Custom amount
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                  _shakeAnim.value > 0
                      ? ((_shakeAnim.value * 6) % 2 == 0 ? 6 : -6) *
                          _shakeAnim.value
                      : 0,
                  0,
                ),
                child: child,
              ),
              child: TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTextStyles.amount.copyWith(
                  color: AppColors.forest,
                  fontSize: 28,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter amount',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.grey.shade400,
                  ),
                  prefixText: 'KES  ',
                  prefixStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.green,
                  ),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (_) => setState(() => _selectedAmount = null),
              ),
            ),

            const SizedBox(height: 28),

            // ── Provider selector ──────────────────────────────────────────
            _SectionLabel('Pay with'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ProviderCard(
                    name: 'M-Pesa',
                    color: AppColors.mpesaGreen,
                    logo: _MpesaLogo(),
                    selected: _provider == 'mpesa',
                    onTap: () => setState(() => _provider = 'mpesa'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProviderCard(
                    name: 'Airtel Money',
                    color: AppColors.airtelRed,
                    logo: _AirtelLogo(),
                    selected: _provider == 'airtel',
                    onTap: () => setState(() => _provider = 'airtel'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Phone number ───────────────────────────────────────────────
            _SectionLabel(
              _provider == 'mpesa' ? 'M-Pesa number' : 'Airtel number',
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.charcoal),
              decoration: InputDecoration(
                hintText: '254XXXXXXXXX',
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 12, right: 8),
                  child: Icon(
                    Icons.phone_android,
                    color: _provider == 'mpesa'
                        ? AppColors.mpesaGreen
                        : AppColors.airtelRed,
                    size: 20,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                    minWidth: 40, minHeight: 40),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text(
              'A payment prompt will be sent to this number',
              style: AppTextStyles.caption.copyWith(color: AppColors.green),
            ),

            // ── Error ──────────────────────────────────────────────────────
            if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(message: error),
            ],

            const SizedBox(height: 32),

            // ── Pay button ─────────────────────────────────────────────────
            _PayButton(
              amount: _amount,
              provider: _provider,
              canPay: _canPay,
              isLoading: isLoading,
              onPressed: _pay,
            ),

            const SizedBox(height: 16),

            // Security note
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline,
                      size: 13, color: AppColors.sage),
                  const SizedBox(width: 5),
                  Text(
                    'Payments secured by Safaricom & Airtel Africa',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.sage),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Project summary card ──────────────────────────────────────────────────────

class _ProjectSummaryCard extends StatelessWidget {
  final ProjectModel project;
  const _ProjectSummaryCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.forest.withValues(alpha: 0.06),
        borderRadius: AppRadius.lgAll,
        border: Border.all(
            color: AppColors.forest.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: AppRadius.mdAll,
            ),
            child: Center(
              child: Text(
                project.title[0].toUpperCase(),
                style: AppTextStyles.h3.copyWith(color: AppColors.cream),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  project.title,
                  style: AppTextStyles.h4.copyWith(color: AppColors.forest),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '${CurrencyFormatter.formatPercent(project.percentageFunded)} funded · '
                  '${CurrencyFormatter.format(project.deficit)} remaining',
                  style: AppTextStyles.caption.copyWith(color: AppColors.green),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Provider card ─────────────────────────────────────────────────────────────

class _ProviderCard extends StatelessWidget {
  final String name;
  final Color color;
  final Widget logo;
  final bool selected;
  final VoidCallback onTap;

  const _ProviderCard({
    required this.name,
    required this.color,
    required this.logo,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: selected ? color : AppColors.sand,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            SizedBox(width: 48, height: 28, child: logo),
            const SizedBox(height: 8),
            Text(
              name,
              style: AppTextStyles.caption.copyWith(
                color: selected ? color : AppColors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? color : Colors.transparent,
                border: Border.all(
                  color: selected ? color : AppColors.sand,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pay button ────────────────────────────────────────────────────────────────

class _PayButton extends StatelessWidget {
  final double? amount;
  final String provider;
  final bool canPay;
  final bool isLoading;
  final VoidCallback onPressed;

  const _PayButton({
    required this.amount,
    required this.provider,
    required this.canPay,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        provider == 'mpesa' ? AppColors.mpesaGreen : AppColors.airtelRed;
    final label = amount != null
        ? 'Pay ${CurrencyFormatter.format(amount!)} via ${provider == 'mpesa' ? 'M-Pesa' : 'Airtel'}'
        : 'Enter amount to continue';

    return ElevatedButton(
      onPressed: isLoading || !canPay ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: canPay ? color : AppColors.sand,
        disabledBackgroundColor: canPay ? color.withValues(alpha: 0.6) : AppColors.sand,
        foregroundColor: Colors.white,
      ),
      child: isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Colors.white),
            )
          : Text(label,
              style: AppTextStyles.button.copyWith(color: Colors.white)),
    );
  }
}

// ── Logos (drawn with CustomPaint) ────────────────────────────────────────────

class _MpesaLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MpesaLogoPainter());
  }
}

class _MpesaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final green = Paint()..color = AppColors.mpesaGreen;
    final white = Paint()..color = Colors.white;

    // Green rounded rect background
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 2, size.width, size.height - 4),
        const Radius.circular(6),
      ),
      green,
    );

    // M-PESA text
    final tp = TextPainter(
      text: const TextSpan(
        text: 'M-PESA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        size.width / 2 - tp.width / 2,
        size.height / 2 - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _AirtelLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AirtelLogoPainter());
  }
}

class _AirtelLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final red = Paint()..color = AppColors.airtelRed;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 2, size.width, size.height - 4),
        const Radius.circular(6),
      ),
      red,
    );

    final tp = TextPainter(
      text: const TextSpan(
        text: 'AIRTEL',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        size.width / 2 - tp.width / 2,
        size.height / 2 - tp.height / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: AppColors.forest,
          letterSpacing: 0.8,
        ),
      );
}

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.07),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
}
