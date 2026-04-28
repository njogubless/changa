import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/payments/presentation/providers/payments_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';


class PaymentStatusScreen extends ConsumerStatefulWidget {
  final String reference;
  final double amount;

  const PaymentStatusScreen({
    super.key,
    required this.reference,
    required this.amount,
  });

  @override
  ConsumerState<PaymentStatusScreen> createState() =>
      _PaymentStatusScreenState();
}

class _PaymentStatusScreenState extends ConsumerState<PaymentStatusScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Start polling after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paymentPollProvider.notifier).startPolling(widget.reference);
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pollState = ref.watch(paymentPollProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: _buildBody(pollState),
      ),
    );
  }

  Widget _buildBody(PaymentPollState pollState) {
    return switch (pollState.status) {
      PollStatus.polling => _PendingView(
          amount: widget.amount,
          reference: widget.reference,
          attempts: pollState.attempts,
          pulseAnim: _pulseAnim,
        ),
      PollStatus.success => _SuccessView(
          amount: pollState.result?.amount ?? widget.amount,
          reference: widget.reference,
          receipt: pollState.result?.providerReference,
          onDone: () => context.go(AppRoutes.home),
        ),
      PollStatus.failed || PollStatus.timeout => _FailedView(
          reason: pollState.failureReason ?? 'Payment was not completed.',
          onRetry: () => context.pop(),
          onHome: () => context.go(AppRoutes.home),
        ),
    };
  }
}

// ── Pending / polling view ────────────────────────────────────────────────────

class _PendingView extends StatelessWidget {
  final double amount;
  final String reference;
  final int attempts;
  final Animation<double> pulseAnim;

  const _PendingView({
    required this.amount,
    required this.reference,
    required this.attempts,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie loading animation
          ScaleTransition(
            scale: pulseAnim,
            child: SizedBox(
              width: 160,
              height: 160,
              child: Lottie.asset(
                'assets/animations/loading.json',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _FallbackLoader(),
              ),
            ),
          ),
          const SizedBox(height: 32),

          Text(
            'Waiting for payment',
            style: AppTextStyles.h2.copyWith(color: AppColors.forest),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Amount
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.07),
              borderRadius: AppRadius.pillAll,
            ),
            child: Text(
              CurrencyFormatter.format(amount),
              style: AppTextStyles.amount.copyWith(
                color: AppColors.forest,
                fontSize: 28,
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Check your phone and enter your M-Pesa PIN\nto complete the payment.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.green,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Polling dots
          _PollingDots(),
          const SizedBox(height: 12),

          Text(
            'Confirming payment...',
            style: AppTextStyles.caption.copyWith(color: AppColors.sage),
          ),
          const SizedBox(height: 48),

          // Reference
          Text(
            'Reference: $reference',
            style: AppTextStyles.caption.copyWith(
              color: AppColors.green.withValues(alpha: 0.5),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}



class _SuccessView extends StatelessWidget {
  final double amount;
  final String reference;
  final String? receipt;
  final VoidCallback onDone;

  const _SuccessView({
    required this.amount,
    required this.reference,
    this.receipt,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Lottie success
          SizedBox(
            width: 160,
            height: 160,
            child: Lottie.asset(
              'assets/animations/success.json',
              fit: BoxFit.contain,
              repeat: false,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 100,
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Payment successful!',
            style: AppTextStyles.h1.copyWith(color: AppColors.forest),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Text(
            'Thank you for your contribution.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
          ),
          const SizedBox(height: 32),

          // Receipt card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.forest,
              borderRadius: AppRadius.lgAll,
            ),
            child: Column(
              children: [
                _ReceiptRow(
                  label: 'Amount paid',
                  value: CurrencyFormatter.format(amount),
                  valueStyle: AppTextStyles.h3.copyWith(color: AppColors.gold),
                ),
                if (receipt != null) ...[
                  const Divider(color: Colors.white12, height: 24),
                  _ReceiptRow(
                    label: 'M-Pesa receipt',
                    value: receipt!,
                    valueStyle: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.mint),
                  ),
                ],
                const Divider(color: Colors.white12, height: 24),
                _ReceiptRow(
                  label: 'Reference',
                  value: reference,
                  valueStyle: AppTextStyles.caption.copyWith(
                    color: AppColors.cream.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          ElevatedButton(
            onPressed: onDone,
            child: const Text('Back to projects'),
          ),
          const SizedBox(height: 12),

          TextButton(
            onPressed: onDone,
            child: Text(
              'View all my contributions',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.sage),
            ),
          ),
        ],
      ),
    );
  }
}



class _FailedView extends StatelessWidget {
  final String reason;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  const _FailedView({
    required this.reason,
    required this.onRetry,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: AppColors.error,
              size: 52,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Payment not completed',
            style: AppTextStyles.h2.copyWith(color: AppColors.forest),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.07),
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2)),
            ),
            child: Text(
              reason,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.error,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try again'),
          ),
          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: onHome,
            child: const Text('Back to projects'),
          ),
        ],
      ),
    );
  }
}



class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle valueStyle;

  const _ReceiptRow({
    required this.label,
    required this.value,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.cream.withValues(alpha: 0.6),
          ),
        ),
        Text(value, style: valueStyle),
      ],
    );
  }
}



class _PollingDots extends StatefulWidget {
  @override
  State<_PollingDots> createState() => _PollingDotsState();
}

class _PollingDotsState extends State<_PollingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = ((_ctrl.value + i * 0.33) % 1.0);
            final opacity = (t < 0.5 ? t * 2 : (1 - t) * 2)
                .clamp(0.2, 1.0);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.forest.withValues(alpha: opacity),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}



class _FallbackLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.forest,
        strokeWidth: 3,
      ),
    );
  }
}
