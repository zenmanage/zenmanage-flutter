// Tests for Flag model
import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';

void main() {
  group('Flag', () {
    group('isEnabled', () {
      test('returns true for boolean true', () {
        final flag = Flag(key: 'test', value: true, type: 'boolean');
        expect(flag.isEnabled(), isTrue);
      });

      test('returns false for boolean false', () {
        final flag = Flag(key: 'test', value: false, type: 'boolean');
        expect(flag.isEnabled(), isFalse);
      });

      test('returns true for non-empty string', () {
        final flag = Flag(key: 'test', value: 'enabled', type: 'string');
        expect(flag.isEnabled(), isTrue);
      });

      test('returns false for empty string', () {
        final flag = Flag(key: 'test', value: '', type: 'string');
        expect(flag.isEnabled(), isFalse);
      });

      test('returns true for non-zero number', () {
        final flag = Flag(key: 'test', value: 42, type: 'number');
        expect(flag.isEnabled(), isTrue);
      });

      test('returns false for zero', () {
        final flag = Flag(key: 'test', value: 0, type: 'number');
        expect(flag.isEnabled(), isFalse);
      });

      test('returns false for null', () {
        final flag = Flag(key: 'test', value: null, type: 'null');
        expect(flag.isEnabled(), isFalse);
      });
    });

    group('asBool', () {
      test('converts boolean directly', () {
        expect(
          Flag(key: 'test', value: true, type: 'boolean').asBool(),
          isTrue,
        );
      });

      test('converts string "true" to true', () {
        expect(
          Flag(key: 'test', value: 'true', type: 'string').asBool(),
          isTrue,
        );
      });

      test('converts string "1" to true', () {
        expect(
          Flag(key: 'test', value: '1', type: 'string').asBool(),
          isTrue,
        );
      });

      test('converts int 1 to true', () {
        expect(
          Flag(key: 'test', value: 1, type: 'number').asBool(),
          isTrue,
        );
      });

      test('converts int 0 to false', () {
        expect(
          Flag(key: 'test', value: 0, type: 'number').asBool(),
          isFalse,
        );
      });

      test('converts double 0.0 to false', () {
        expect(
          Flag(key: 'test', value: 0.0, type: 'number').asBool(),
          isFalse,
        );
      });

      test('converts non-empty list to true', () {
        expect(
          Flag(key: 'test', value: [1, 2, 3], type: 'json').asBool(),
          isTrue,
        );
      });
    });

    group('asString', () {
      test('returns string value directly', () {
        expect(
          Flag(key: 'test', value: 'hello', type: 'string').asString(),
          equals('hello'),
        );
      });

      test('converts boolean to string', () {
        expect(
          Flag(key: 'test', value: true, type: 'boolean').asString(),
          equals('true'),
        );
      });

      test('converts number to string', () {
        expect(
          Flag(key: 'test', value: 42, type: 'number').asString(),
          equals('42'),
        );
      });

      test('converts null to empty string', () {
        expect(
          Flag(key: 'test', value: null, type: 'null').asString(),
          equals(''),
        );
      });
    });

    group('asNumber', () {
      test('returns number value directly', () {
        expect(
          Flag(key: 'test', value: 42, type: 'number').asNumber(),
          equals(42),
        );
      });

      test('converts double directly', () {
        expect(
          Flag(key: 'test', value: 3.14, type: 'number').asNumber(),
          equals(3.14),
        );
      });

      test('parses string as int', () {
        expect(
          Flag(key: 'test', value: '42', type: 'string').asNumber(),
          equals(42),
        );
      });

      test('parses string as double', () {
        expect(
          Flag(key: 'test', value: '3.14', type: 'string').asNumber(),
          equals(3.14),
        );
      });

      test('converts boolean to number', () {
        expect(
          Flag(key: 'test', value: true, type: 'boolean').asNumber(),
          equals(1),
        );
      });

      test('throws on invalid string', () {
        expect(
          () =>
              Flag(key: 'test', value: 'invalid', type: 'string').asNumber(),
          throwsA(isA<TypeConversionException>()),
        );
      });

      test('throws for a value that is not num, string, or bool', () {
        expect(
          () => Flag(key: 'test', value: <int>[1, 2], type: 'json')
              .asNumber(),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('asInt and asDouble', () {
      test('asInt converts to integer', () {
        expect(
          Flag(key: 'test', value: 3.7, type: 'number').asInt(),
          equals(3),
        );
      });

      test('asDouble converts to double', () {
        expect(
          Flag(key: 'test', value: 42, type: 'number').asDouble(),
          equals(42.0),
        );
      });
    });

    group('asJson', () {
      test('returns map value directly', () {
        final map = {'key': 'value'};
        final flag = Flag(key: 'test', value: map, type: 'json');
        expect(flag.asJson(), equals(map));
      });

      test('converts generic map to typed map', () {
        final map = {'key': 'value'} as Map;
        final flag = Flag(key: 'test', value: map, type: 'json');
        expect(flag.asJson(), isA<Map<String, dynamic>>());
      });

      test('throws for non-map value', () {
        expect(
          () => Flag(key: 'test', value: 'not a map', type: 'string')
              .asJson(),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('asList', () {
      test('returns list value directly', () {
        final list = [1, 2, 3];
        final flag = Flag(key: 'test', value: list, type: 'json');
        expect(flag.asList<int>(), equals(list));
      });

      test('throws for non-list value', () {
        expect(
          () => Flag(key: 'test', value: 'not a list', type: 'string')
              .asList<String>(),
          throwsA(isA<TypeConversionException>()),
        );
      });
    });

    group('getValue', () {
      test('returns the raw value', () {
        const value = 'raw value';
        final flag = Flag(key: 'test', value: value, type: 'string');
        expect(flag.getValue(), equals(value));
      });
    });

    group('Equality and Hashing', () {
      test('two flags with same properties are equal', () {
        final flag1 = Flag(key: 'test', value: true, type: 'boolean');
        final flag2 = Flag(key: 'test', value: true, type: 'boolean');
        expect(flag1, equals(flag2));
      });

      test('flags with different values are not equal', () {
        final flag1 = Flag(key: 'test', value: true, type: 'boolean');
        final flag2 = Flag(key: 'test', value: false, type: 'boolean');
        expect(flag1, isNot(equals(flag2)));
      });

      test('hash code is consistent', () {
        final flag1 = Flag(key: 'test', value: true, type: 'boolean');
        final flag2 = Flag(key: 'test', value: true, type: 'boolean');
        expect(flag1.hashCode, equals(flag2.hashCode));
      });
    });

    group('toString', () {
      test('returns readable string representation', () {
        final flag = Flag(key: 'test', value: true, type: 'boolean');
        expect(
          flag.toString(),
          contains('Flag'),
        );
        expect(flag.toString(), contains('test'));
      });
    });
  });
}
