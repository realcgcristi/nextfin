class AppException implements Exception {
  const AppException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final Object? details;

  @override
  String toString() => 'AppException($code, $message)';
}

class AuthenticationException extends AppException {
  const AuthenticationException(super.message, {super.code, super.details});
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code, super.details});
}

class CompatibilityException extends AppException {
  const CompatibilityException(super.message, {super.code, super.details});
}
