import 'package:changa/core/constants/app_constants.dart';
import 'package:changa/core/router/app_router.dart';
import 'package:changa/core/themes/app_theme.dart';
import 'package:changa/core/utils/currency_formatter.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/payments/presentation/providers/payments_provider.dart';
import 'package:changa/features/payments/widgets/payment_widgets.dart';
import 'package:changa/features/payments/widgets/project_summary_card.dart';
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
  String _provider = 'mpesa';

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
    return double.tryParse(_amountCtrl.text.replaceAll(',', ''));
  }

  bool get _canPay {
    final amount = _amount;
    if (amount == null || amount < 1) return false;
    return RegExp(r'^254[17]\d{8}$').hasMatch(_phoneCtrl.text.trim());
  }

  Future<void> _pay() async {
    if (!_canPay) {
      _shakeCtrl.forward(from: 0);
      return;
    }

    final notifier = ref.read(paymentInitProvider.notifier);
    _provider == 'mpesa'
        ? await notifier.payMpesa(
            projectId: widget.projectId,
            amount: _amount!,
            phone: _phoneCtrl.text.trim(),
          )
        : await notifier.payAirtel(
            projectId: widget.projectId,
            amount: _amount!,
            phone: _phoneCtrl.text.trim(),
          );

    final state = ref.read(paymentInitProvider);
    if (state is PaymentInitSuccess && mounted) {
      context.pushReplacement(
        AppRoutes.paymentStatusPath(
            state.contribution.reference, state.contribution.amount),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final initState = ref.watch(paymentInitProvider);
    final isLoading = initState is PaymentInitLoading;
    final error = initState is PaymentInitError ? initState.message : null;
    final project =
        ref.watch(projectDetailProvider(widget.projectId)).valueOrNull;

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
            if (project != null) ...[
              ProjectSummaryCard(project: project),
              const SizedBox(height: 24),
            ],


            const PaymentSectionLabel('How much?'),
            const SizedBox(height: 12),
            _AmountChips(
              selected: _selectedAmount,
              onSelect: (amt) => setState(() {
                _selectedAmount = _selectedAmount == amt ? null : amt;
                if (_selectedAmount != null) _amountCtrl.clear();
              }),
            ),
            const SizedBox(height: 12),
            _AmountTextField(
              controller: _amountCtrl,
              shakeAnim: _shakeAnim,
              onChanged: () => setState(() => _selectedAmount = null),
            ),
            const SizedBox(height: 28),

          
            const PaymentSectionLabel('Pay with'),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: PaymentProviderCard(
                  name: 'M-Pesa',
                  color: AppColors.mpesaGreen,
                  logo: const MpesaLogo(),
                  selected: _provider == 'mpesa',
                  onTap: () => setState(() => _provider = 'mpesa'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PaymentProviderCard(
                  name: 'Airtel Money',
                  color: AppColors.airtelRed,
                  logo: const AirtelLogo(),
                  selected: _provider == 'airtel',
                  onTap: () => setState(() => _provider = 'airtel'),
                ),
              ),
            ]),
            const SizedBox(height: 28),

           
            PaymentSectionLabel(
                _provider == 'mpesa' ? 'M-Pesa number' : 'Airtel number'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.charcoal),
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
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 6),
            Text(
              'A payment prompt will be sent to this number',
              style: AppTextStyles.caption.copyWith(color: AppColors.green),
            ),

            if (error != null) ...[
              const SizedBox(height: 16),
              PaymentErrorBanner(message: error),
            ],
            const SizedBox(height: 32),

      
            PayButton(
              amount: _amount,
              provider: _provider,
              canPay: _canPay,
              isLoading: isLoading,
              onPressed: _pay,
            ),
            const SizedBox(height: 16),

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



class _AmountChips extends StatelessWidget {
  final double? selected;
  final void Function(double) onSelect;

  const _AmountChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: AppConstants.quickAmounts.map((amt) {
        final isSelected = selected == amt;
        return GestureDetector(
          onTap: () => onSelect(amt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.forest : Colors.white,
              borderRadius: AppRadius.pillAll,
              border: Border.all(
                color: isSelected ? AppColors.forest : AppColors.sand,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              CurrencyFormatter.formatCompact(amt),
              style: AppTextStyles.button.copyWith(
                color: isSelected ? AppColors.cream : AppColors.forest,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}



class _AmountTextField extends StatelessWidget {
  final TextEditingController controller;
  final Animation<double> shakeAnim;
  final VoidCallback onChanged;

  const _AmountTextField({
    required this.controller,
    required this.shakeAnim,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(
          shakeAnim.value > 0
              ? ((shakeAnim.value * 6) % 2 == 0 ? 6 : -6) * shakeAnim.value
              : 0,
          0,
        ),
        child: child,
      ),
      child: TextFormField(
        controller: controller,
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
          prefixStyle:
              AppTextStyles.bodyMedium.copyWith(color: AppColors.green),
          fillColor: Colors.white,
          filled: true,
        ),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
