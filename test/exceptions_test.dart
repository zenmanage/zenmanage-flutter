// Tests for exception classes
import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';

/// Minimal concrete subclass so the base [ZenmanageException.toString] can
/// be exercised directly, since every SDK-defined subclass overrides it.
base class _CustomZenmanageException extends ZenmanageException {
  _CustomZenmanageException(super.message);
}

void main() {
  group('Exceptions', () {
    group('ZenmanageException', () {
      test('base toString includes the exception type and message', () {
        final exception = _CustomZenmanageException('custom failure');
        expect(
          exception.toString(),
          equals('ZenmanageException: custom failure'),
        );
      });
    });

    group('ConfigurationException', () {
      test('creates exception with message', () {
        const message = 'Invalid configuration';
        final exception = ConfigurationException(message);

        expect(exception.message, equals(message));
        expect(exception.toString(), contains(message));
      });

      test('is a ZenmanageException', () {
        final exception = ConfigurationException('test');
        expect(exception, isA<ZenmanageException>());
      });

      test('toString includes the exception type and message', () {
        final exception = ConfigurationException('bad config');
        expect(
          exception.toString(),
          equals('ConfigurationException: bad config'),
        );
      });
    });

    group('ApiException', () {
      test('creates exception with message', () {
        const message = 'API request failed';
        final exception = ApiException(message);

        expect(exception.message, equals(message));
        expect(exception.statusCode, isNull);
        expect(exception.originalError, isNull);
      });

      test('creates exception with status code', () {
        const message = 'API request failed';
        final exception = ApiException(message, statusCode: 500);

        expect(exception.statusCode, equals(500));
        expect(exception.toString(), contains('500'));
      });

      test('creates exception with original error', () {
        const message = 'API request failed';
        final originalError = Exception('Network error');
        final exception =
            ApiException(message, originalError: originalError);

        expect(exception.originalError, equals(originalError));
      });

      test('is a ZenmanageException', () {
        final exception = ApiException('test');
        expect(exception, isA<ZenmanageException>());
      });

      test('toString omits status code when not provided', () {
        final exception = ApiException('request failed');
        expect(exception.toString(), equals('ApiException: request failed'));
      });

      test('toString includes status code when provided', () {
        final exception = ApiException('request failed', statusCode: 404);
        expect(
          exception.toString(),
          equals('ApiException (HTTP 404): request failed'),
        );
      });
    });

    group('CacheException', () {
      test('creates exception with message', () {
        const message = 'Cache operation failed';
        final exception = CacheException(message);

        expect(exception.message, equals(message));
      });

      test('is a ZenmanageException', () {
        final exception = CacheException('test');
        expect(exception, isA<ZenmanageException>());
      });

      test('toString includes the exception type and message', () {
        final exception = CacheException('disk full');
        expect(exception.toString(), equals('CacheException: disk full'));
      });
    });

    group('FlagNotFoundException', () {
      test('creates exception for missing flag', () {
        const flagKey = 'missing-flag';
        final exception = FlagNotFoundException(flagKey);

        expect(exception.message, contains(flagKey));
      });

      test('is a ZenmanageException', () {
        final exception = FlagNotFoundException('test');
        expect(exception, isA<ZenmanageException>());
      });

      test('toString includes the exception type and message', () {
        final exception = FlagNotFoundException('missing-flag');
        expect(
          exception.toString(),
          equals('FlagNotFoundException: Flag "missing-flag" not found'),
        );
      });
    });

    group('TypeConversionException', () {
      test('creates exception with type info', () {
        final exception = TypeConversionException('String', 'int');

        expect(exception.message, contains('String'));
        expect(exception.message, contains('int'));
      });

      test('includes value in message', () {
        final exception = TypeConversionException('String', 'int', value: 'abc');

        expect(exception.value, equals('abc'));
        expect(exception.toString(), contains('abc'));
      });

      test('is a ZenmanageException', () {
        final exception = TypeConversionException('String', 'int');
        expect(exception, isA<ZenmanageException>());
      });

      test('toString includes the exception type, message, and value', () {
        final exception =
            TypeConversionException('String', 'int', value: 'abc');
        expect(
          exception.toString(),
          equals(
            'TypeConversionException: Cannot convert String to int (value: abc)',
          ),
        );
      });

      test('value is null when not provided', () {
        final exception = TypeConversionException('String', 'int');
        expect(exception.value, isNull);
      });
    });

    group('RuleEvaluationException', () {
      test('creates exception with message', () {
        const message = 'Invalid rule format';
        final exception = RuleEvaluationException(message);

        expect(exception.message, equals(message));
      });

      test('is a ZenmanageException', () {
        final exception = RuleEvaluationException('test');
        expect(exception, isA<ZenmanageException>());
      });

      test('toString includes the exception type and message', () {
        final exception = RuleEvaluationException('bad rule');
        expect(
          exception.toString(),
          equals('RuleEvaluationException: bad rule'),
        );
      });
    });

    group('Exception Hierarchy', () {
      test('all exceptions extend ZenmanageException', () {
        expect(ConfigurationException('test'), isA<ZenmanageException>());
        expect(ApiException('test'), isA<ZenmanageException>());
        expect(CacheException('test'), isA<ZenmanageException>());
        expect(FlagNotFoundException('test'), isA<ZenmanageException>());
        expect(
          TypeConversionException('a', 'b'),
          isA<ZenmanageException>(),
        );
        expect(RuleEvaluationException('test'), isA<ZenmanageException>());
      });

      test('all exceptions are Exceptions', () {
        expect(ConfigurationException('test'), isA<Exception>());
        expect(ApiException('test'), isA<Exception>());
        expect(CacheException('test'), isA<Exception>());
        expect(FlagNotFoundException('test'), isA<Exception>());
        expect(
          TypeConversionException('a', 'b'),
          isA<Exception>(),
        );
        expect(RuleEvaluationException('test'), isA<Exception>());
      });
    });
  });
}
