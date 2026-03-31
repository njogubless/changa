import 'dart:async';
import 'package:changa/core/constants/api_constants.dart';
import 'package:changa/features/auth/presentation/providers/auth_provider.dart';
import 'package:changa/features/payments/data/models/payment_models.dart';
import 'package:changa/features/payments/data/repository/payments_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.watch(apiClientProvider)),
);



sealed class PaymentInitState {
  const PaymentInitState();
}

class PaymentInitIdle extends PaymentInitState {
  const PaymentInitIdle();
}

class PaymentInitLoading extends PaymentInitState {
  const PaymentInitLoading();
}

class PaymentInitSuccess extends PaymentInitState {
  final ContributionModel contribution;
  const PaymentInitSuccess(this.contribution);
}

class PaymentInitError extends PaymentInitState {
  final String message;
  const PaymentInitError(this.message);
}

// ── Payment initiator notifier ────────────────────────────────────────────────

class PaymentInitNotifier extends StateNotifier<PaymentInitState> {
  final PaymentsRepository _repo;

  PaymentInitNotifier(this._repo) : super(const PaymentInitIdle());

  Future<void> payMpesa({
    required String projectId,
    required double amount,
    required String phone,
  }) async {
    state = const PaymentInitLoading();
    try {
      final contribution = await _repo.contributeMpesa(
        projectId: projectId,
        amount: amount,
        phone: phone,
      );
      state = PaymentInitSuccess(contribution);
    } catch (e) {
      state = PaymentInitError(_friendlyError(e.toString()));
    }
  }

  Future<void> payAirtel({
    required String projectId,
    required double amount,
    required String phone,
  }) async {
    state = const PaymentInitLoading();
    try {
      final contribution = await _repo.contributeAirtel(
        projectId: projectId,
        amount: amount,
        phone: phone,
      );
      state = PaymentInitSuccess(contribution);
    } catch (e) {
      state = PaymentInitError(_friendlyError(e.toString()));
    }
  }

  void reset() => state = const PaymentInitIdle();

  String _friendlyError(String raw) {
    if (raw.contains('502') || raw.contains('M-Pesa')) {
      return 'Could not reach M-Pesa. Please try again.';
    }
    if (raw.contains('Airtel')) {
      return 'Could not reach Airtel Money. Please try again.';
    }
    if (raw.contains('Network') || raw.contains('connection')) {
      return 'No internet connection.';
    }
    if (raw.contains('active')) {
      return 'This project is not accepting contributions.';
    }
    return 'Payment failed. Please try again.';
  }
}

final paymentInitProvider =
    StateNotifierProvider<PaymentInitNotifier, PaymentInitState>(
  (ref) => PaymentInitNotifier(ref.watch(paymentsRepositoryProvider)),
);



enum PollStatus { polling, success, failed, timeout }

class PaymentPollState {
  final PollStatus status;
  final ContributionStatusModel? result;
  final int attempts;
  final String? failureReason;

  const PaymentPollState({
    required this.status,
    this.result,
    this.attempts = 0,
    this.failureReason,
  });
}

class PaymentPollNotifier extends StateNotifier<PaymentPollState> {
  final PaymentsRepository _repo;
  Timer? _timer;

  PaymentPollNotifier(this._repo)
      : super(const PaymentPollState(status: PollStatus.polling));

  void startPolling(String reference) {
    _timer?.cancel();
    _poll(reference);
    _timer = Timer.periodic(ApiConstants.pollInterval, (_) {
      _poll(reference);
    });
  }

  Future<void> _poll(String reference) async {
    if (state.attempts >= ApiConstants.pollMaxAttempts) {
      _timer?.cancel();
      state = PaymentPollState(
        status: PollStatus.timeout,
        attempts: state.attempts,
        failureReason: 'Payment confirmation timed out. Check your M-Pesa messages.',
      );
      return;
    }

    try {
      final result = await _repo.getStatus(reference);

      switch (result.status) {
        case ContributionStatus.success:
          _timer?.cancel();
          state = PaymentPollState(
            status: PollStatus.success,
            result: result,
            attempts: state.attempts + 1,
          );
        case ContributionStatus.failed:
          _timer?.cancel();
          state = PaymentPollState(
            status: PollStatus.failed,
            result: result,
            attempts: state.attempts + 1,
            failureReason: 'Payment was declined. Please try again.',
          );
        case ContributionStatus.cancelled:
          _timer?.cancel();
          state = PaymentPollState(
            status: PollStatus.failed,
            result: result,
            attempts: state.attempts + 1,
            failureReason: 'Payment was cancelled.',
          );
        case ContributionStatus.pending:
          state = PaymentPollState(
            status: PollStatus.polling,
            result: result,
            attempts: state.attempts + 1,
          );
      }
    } catch (_) {
      // Network blip — keep polling, don't fail
      state = PaymentPollState(
        status: PollStatus.polling,
        attempts: state.attempts + 1,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final paymentPollProvider =
    StateNotifierProvider.autoDispose<PaymentPollNotifier, PaymentPollState>(
  (ref) => PaymentPollNotifier(ref.watch(paymentsRepositoryProvider)),
);



final myContributionsProvider =
    FutureProvider.autoDispose<List<ContributionModel>>((ref) async {
  return ref.watch(paymentsRepositoryProvider).getMyContributions();
});
