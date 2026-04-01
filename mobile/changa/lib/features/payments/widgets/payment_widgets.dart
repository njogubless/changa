import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';




class PaymentSectionLabel extends StatelessWidget {
  final String text;
  const PaymentSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTextStyles.label.copyWith(
          color: AppColors.forest,
          letterSpacing: 0.8,
        ),
      );
}



class PaymentErrorBanner extends StatelessWidget {
  final String message;
  const PaymentErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.07),
          borderRadius: AppRadius.mdAll,
          border:
              Border.all(color: AppColors.error.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style:
                    AppTextStyles.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
}



class PaymentProviderCard extends StatelessWidget {
  final String name;
  final Color color;
  final Widget logo;
  final bool selected;
  final VoidCallback onTap;

  const PaymentProviderCard({
    super.key,
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
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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



class PayButton extends StatelessWidget {
  final double? amount;
  final String provider;
  final bool canPay;
  final bool isLoading;
  final VoidCallback onPressed;

  const PayButton({
    super.key,
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
    final providerName = provider == 'mpesa' ? 'M-Pesa' : 'Airtel';
    final label = amount != null
        ? 'Pay ${CurrencyFormatter.format(amount!)} via $providerName'
        : 'Enter amount to continue';

    return ElevatedButton(
      onPressed: isLoading || !canPay ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: canPay ? color : AppColors.sand,
        disabledBackgroundColor:
            canPay ? color.withValues(alpha: 0.6) : AppColors.sand,
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



class MpesaLogo extends StatelessWidget {
  const MpesaLogo({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _MpesaLogoPainter());
}

class AirtelLogo extends StatelessWidget {
  const AirtelLogo({super.key});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _AirtelLogoPainter());
}

class _MpesaLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 2, size.width, size.height - 4),
        const Radius.circular(6),
      ),
      Paint()..color = AppColors.mpesaGreen,
    );
    _drawLabel(canvas, size, 'M-PESA');
  }

  @override
  bool shouldRepaint(_) => false;
}

class _AirtelLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 2, size.width, size.height - 4),
        const Radius.circular(6),
      ),
      Paint()..color = AppColors.airtelRed,
    );
    _drawLabel(canvas, size, 'AIRTEL');
  }

  @override
  bool shouldRepaint(_) => false;
}

void _drawLabel(Canvas canvas, Size size, String text) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
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
    Offset(size.width / 2 - tp.width / 2, size.height / 2 - tp.height / 2),
  );
}
