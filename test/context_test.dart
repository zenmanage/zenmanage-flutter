// Tests for Context model
import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';

void main() {
  group('Context', () {
    group('Creation', () {
      test('creates context with required fields', () {
        final context = Context(
          type: 'user',
          identifier: 'user_123',
        );

        expect(context.type, equals('user'));
        expect(context.identifier, equals('user_123'));
        expect(context.name, isNull);
        expect(context.attributes, isEmpty);
      });

      test('creates context with all fields', () {
        final attributes = {'country': 'US', 'plan': 'premium'};
        final context = Context(
          type: 'user',
          identifier: 'user_123',
          name: 'John Doe',
          attributes: attributes,
        );

        expect(context.type, equals('user'));
        expect(context.identifier, equals('user_123'));
        expect(context.name, equals('John Doe'));
        expect(context.attributes, equals(attributes));
      });

      test('throws assertion error for empty type', () {
        expect(
          () => Context(
            type: '',
            identifier: 'user_123',
          ),
          throwsAssertionError,
        );
      });
    });

    group('Factory Constructors', () {
      test('Context.user creates user context', () {
        final context = Context.user(
          id: 'user_123',
          name: 'John',
          attributes: {'plan': 'premium'},
        );

        expect(context.type, equals('user'));
        expect(context.identifier, equals('user_123'));
        expect(context.name, equals('John'));
        expect(context.attributes['plan'], equals('premium'));
      });

      test('Context.organization creates organization context', () {
        final context = Context.organization(
          id: 'org_456',
          name: 'Acme Corp',
          attributes: {'tier': 'enterprise'},
        );

        expect(context.type, equals('organization'));
        expect(context.identifier, equals('org_456'));
        expect(context.name, equals('Acme Corp'));
        expect(context.attributes['tier'], equals('enterprise'));
      });

      test('Context.account creates account context', () {
        final context = Context.account(
          id: 'acc_789',
          name: 'Business Account',
          attributes: {'status': 'active'},
        );

        expect(context.type, equals('account'));
        expect(context.identifier, equals('acc_789'));
        expect(context.name, equals('Business Account'));
        expect(context.attributes['status'], equals('active'));
      });

      test('factory constructors with null name', () {
        final context = Context.user(id: 'user_123');
        expect(context.name, isNull);
      });

      test('factory constructors with null attributes', () {
        final context = Context.user(id: 'user_123');
        expect(context.attributes, isEmpty);
      });
    });

    group('JSON Serialization', () {
      test('toJson with all fields', () {
        final context = Context(
          type: 'user',
          identifier: 'user_123',
          name: 'John',
          attributes: {'country': 'US'},
        );

        final json = context.toJson();

        expect(json['type'], equals('user'));
        expect(json['identifier'], equals('user_123'));
        expect(json['name'], equals('John'));
        expect(json['attributes']['country'], equals('US'));
      });

      test('toJson without optional fields', () {
        final context = Context(
          type: 'user',
          identifier: 'user_123',
        );

        final json = context.toJson();

        expect(json.containsKey('name'), isFalse);
        expect(json.containsKey('attributes'), isFalse);
      });

      test('toJson with empty attributes not included', () {
        final context = Context(
          type: 'user',
          identifier: 'user_123',
          attributes: {},
        );

        final json = context.toJson();

        expect(json.containsKey('attributes'), isFalse);
      });
    });

    group('copyWith', () {
      test('copyWith creates new instance with overrides', () {
        final original = Context(
          type: 'user',
          identifier: 'user_123',
          name: 'John',
          attributes: {'country': 'US'},
        );

        final copy = original.copyWith(name: 'Jane');

        expect(copy.type, equals('user'));
        expect(copy.identifier, equals('user_123'));
        expect(copy.name, equals('Jane'));
        expect(copy.attributes['country'], equals('US'));
      });

      test('copyWith preserves original instance', () {
        final original = Context(
          type: 'user',
          identifier: 'user_123',
          name: 'John',
        );

        final copy = original.copyWith(name: 'Jane');

        expect(original.name, equals('John'));
        expect(copy.name, equals('Jane'));
      });

      test('copyWith with new attributes', () {
        final original = Context(
          type: 'user',
          identifier: 'user_123',
          attributes: {'country': 'US'},
        );

        final copy = original.copyWith(
          attributes: {'country': 'UK', 'plan': 'pro'},
        );

        expect(copy.attributes['country'], equals('UK'));
        expect(copy.attributes['plan'], equals('pro'));
      });

      test('copyWith with null overrides uses original values', () {
        final original = Context(
          type: 'user',
          identifier: 'user_123',
          name: 'John',
        );

        final copy = original.copyWith();

        expect(copy.type, equals(original.type));
        expect(copy.identifier, equals(original.identifier));
        expect(copy.name, equals(original.name));
      });
    });

    group('toString', () {
      test('returns readable string representation', () {
        final context = Context(
          type: 'user',
          identifier: 'user_123',
          name: 'John',
        );

        final str = context.toString();

        expect(str, contains('Context'));
        expect(str, contains('user'));
        expect(str, contains('user_123'));
        expect(str, contains('John'));
      });
    });
  });
}
