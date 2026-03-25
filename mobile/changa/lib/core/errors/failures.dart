abstract class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

class ValidationFailure extends Failure {
  final Map<String, List<String>>? errors;
  const ValidationFailure(super.message, {this.errors});
}

class PaymentFailure extends Failure {
  const PaymentFailure([super.message = 'Payment failed']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found']);
}

class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'Something went wrong']);
}
