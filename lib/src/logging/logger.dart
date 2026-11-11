/// Logging interface for SDK diagnostics
library zenmanage.logger;

/// Receives diagnostic messages from the SDK.
///
/// The SDK logs nothing by default ([NullLogger]). Pass your own
/// implementation to `ConfigBuilder.withLogger` to route SDK diagnostics
/// (rule fetch attempts, retries, failures) into your app's logging:
///
/// ```dart
/// class PrintLogger implements ZenmanageLogger {
///   @override
///   void debug(String message, [Map<String, Object?>? metadata]) =>
///       print('[zenmanage] $message ${metadata ?? ''}');
///   // ...info, warn and error the same way
/// }
/// ```
abstract interface class ZenmanageLogger {
  /// Verbose detail, such as each fetch attempt.
  void debug(String message, [Map<String, Object?>? metadata]);

  /// Notable but expected events, such as a successful rules fetch.
  void info(String message, [Map<String, Object?>? metadata]);

  /// Recoverable problems, such as a failed attempt that will be retried.
  void warn(String message, [Map<String, Object?>? metadata]);

  /// Failures the SDK could not recover from.
  void error(String message, [Map<String, Object?>? metadata]);
}

/// A [ZenmanageLogger] that discards everything. This is the default.
class NullLogger implements ZenmanageLogger {
  /// Creates a logger that does nothing
  const NullLogger();

  @override
  void debug(String message, [Map<String, Object?>? metadata]) {}

  @override
  void info(String message, [Map<String, Object?>? metadata]) {}

  @override
  void warn(String message, [Map<String, Object?>? metadata]) {}

  @override
  void error(String message, [Map<String, Object?>? metadata]) {}
}
