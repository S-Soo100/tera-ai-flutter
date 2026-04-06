class AppException implements Exception {
  final String message;
  final String? code;

  const AppException({required this.message, this.code});

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

class NetworkException extends AppException {
  const NetworkException({required super.message, super.code});
}

class NotFoundException extends AppException {
  const NotFoundException({required super.message, super.code});
}
