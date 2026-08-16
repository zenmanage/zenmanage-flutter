/// Exception classes for the Zenmanage SDK
library zenmanage.exceptions;

/// Base exception class for all Zenmanage errors
abstract base class ZenmanageException implements Exception {
  /// Creates a new ZenmanageException with an optional message
  ZenmanageException(this.message);

  /// The error message
  final String message;

  @override
  String toString() => 'ZenmanageException: $message';
}

/// Thrown when there's an issue with SDK configuration
final class ConfigurationException extends ZenmanageException {
  /// Creates a new ConfigurationException
  ConfigurationException(super.message);

  @override
  String toString() => 'ConfigurationException: $message';
}

/// Thrown when an API request fails
final class ApiException extends ZenmanageException {
  /// Creates a new ApiException
  ApiException(super.message, {this.statusCode, this.originalError});

  /// The HTTP status code, if applicable
  final int? statusCode;

  /// The original error that caused this exception
  final Object? originalError;

  @override
  String toString() {
    if (statusCode != null) {
      return 'ApiException (HTTP $statusCode): $message';
    }
    return 'ApiException: $message';
  }
}

/// Thrown when cache operations fail
final class CacheException extends ZenmanageException {
  /// Creates a new CacheException
  CacheException(super.message);

  @override
  String toString() => 'CacheException: $message';
}

/// Thrown when a flag is not found
final class FlagNotFoundException extends ZenmanageException {
  /// Creates a new FlagNotFoundException
  FlagNotFoundException(String flagKey)
      : super('Flag "$flagKey" not found');

  @override
  String toString() => 'FlagNotFoundException: $message';
}

/// Thrown when a type conversion fails
final class TypeConversionException extends ZenmanageException {
  /// Creates a new TypeConversionException
  TypeConversionException(String from, String to, {this.value})
      : super('Cannot convert $from to $to');

  /// The value that failed to convert
  final Object? value;

  @override
  String toString() => 'TypeConversionException: $message (value: $value)';
}

/// Thrown when rule evaluation fails
final class RuleEvaluationException extends ZenmanageException {
  /// Creates a new RuleEvaluationException
  RuleEvaluationException(super.message);

  @override
  String toString() => 'RuleEvaluationException: $message';
}
