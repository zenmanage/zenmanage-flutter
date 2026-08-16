import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/src/context/context.dart';
import 'package:zenmanage/src/rule_engine.dart';

void main() {
  group('RuleEngine', () {
    final engine = RuleEngine();

    test('evaluateFlag returns flag for map-based rule', () {
      const rulesJson = '{"flags":{"new-dashboard":{"value":true,"type":"boolean"}}}';

      final flag = engine.evaluateFlag(
        flagKey: 'new-dashboard',
        rulesJson: rulesJson,
      );

      expect(flag, isNotNull);
      expect(flag!.key, equals('new-dashboard'));
      expect(flag.value, isTrue);
      expect(flag.type, equals('boolean'));
    });

    test('evaluateFlag returns null when flag is missing', () {
      const rulesJson = '{"flags":{"existing":{"value":true,"type":"boolean"}}}';

      final flag = engine.evaluateFlag(
        flagKey: 'missing',
        rulesJson: rulesJson,
      );

      expect(flag, isNull);
    });

    test('evaluateFlag handles primitive flag values', () {
      const rulesJson = '{"flags":{"toggle":true}}';

      final flag = engine.evaluateFlag(
        flagKey: 'toggle',
        rulesJson: rulesJson,
      );

      expect(flag, isNotNull);
      expect(flag!.type, equals('boolean'));
      expect(flag.value, isTrue);
    });

    test('evaluateFlag returns null for invalid JSON', () {
      final flag = engine.evaluateFlag(
        flagKey: 'toggle',
        rulesJson: '{invalid json',
      );

      expect(flag, isNull);
    });

    test('evaluateAllFlags returns every flag from rules', () {
      const rulesJson =
          '{"flags":{"a":{"value":true,"type":"boolean"},"b":{"value":"test","type":"string"},"c":123}}';

      final flags = engine.evaluateAllFlags(rulesJson: rulesJson);

      expect(flags.length, equals(3));
      expect(flags.map((f) => f.key), containsAll(<String>['a', 'b', 'c']));
    });

    test('evaluateAllFlags returns empty list for invalid JSON', () {
      final flags = engine.evaluateAllFlags(rulesJson: '{invalid json');
      expect(flags, isEmpty);
    });

    test('supports API style flags array with target object', () {
      const rulesJson =
          '{"flags":[{"key":"checkout-flow","type":"string","target":{"value":{"value":{"string":"control"}}},"rules":[]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'checkout-flow',
        rulesJson: rulesJson,
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('control'));
    });

    test('context selector rule overrides target when matched', () {
      const rulesJson =
          '{"flags":[{"key":"beta-program","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[{"position":1,"criteria":{"selector":"context","comparer":"equals","values":[{"identifier":"user_123","type":"user"}]},"value":{"value":{"boolean":true}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'beta-program',
        rulesJson: rulesJson,
        contexts: <Context>[Context.user(id: 'user_123')],
      );

      expect(flag, isNotNull);
      expect(flag!.isEnabled(), isTrue);
    });

    test('attribute selector with starts_with operator matches correctly', () {
      const rulesJson =
          '{"flags":[{"key":"ui-theme","type":"string","target":{"value":{"value":{"string":"light"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"country","comparer":"starts_with","values":["US"]},"value":{"value":{"string":"dark"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'ui-theme',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'USA'})
        ],
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('dark'));
    });

    test('attribute selector with contains comparer matches correctly', () {
      const rulesJson =
          '{"flags":[{"key":"email-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"email","comparer":"contains","values":["@example.com"]},"value":{"value":{"string":"matched"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'email-flag',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'email': 'alice@example.com'})
        ],
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('matched'));
    });

    test('attribute selector with notcontains comparer matches correctly', () {
      const rulesJson =
          '{"flags":[{"key":"email-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"email","comparer":"notcontains","values":["@other.com"]},"value":{"value":{"string":"matched"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'email-flag',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'email': 'alice@example.com'})
        ],
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('matched'));
    });

    test('attribute selector with notstartswith comparer matches correctly', () {
      const rulesJson =
          '{"flags":[{"key":"email-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"email","comparer":"notstartswith","values":["admin"]},"value":{"value":{"string":"matched"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'email-flag',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'email': 'alice@example.com'})
        ],
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('matched'));
    });

    test('attribute selector with notendswith comparer matches correctly', () {
      const rulesJson =
          '{"flags":[{"key":"email-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"email","comparer":"notendswith","values":[".org"]},"value":{"value":{"string":"matched"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'email-flag',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'email': 'alice@example.com'})
        ],
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('matched'));
    });

    test('rollout bucket uses rollout target for in-bucket context', () {
      const rulesJson =
          '{"flags":[{"key":"new-dashboard","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[],"rollout":{"percentage":100,"salt":"abc123","target":{"value":{"value":{"boolean":true}}},"rules":[]}}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'new-dashboard',
        rulesJson: rulesJson,
        contexts: <Context>[Context.user(id: 'user_1')],
      );

      expect(flag, isNotNull);
      expect(flag!.isEnabled(), isTrue);
    });

    test('rollout bucket keeps fallback target for 0 percent rollout', () {
      const rulesJson =
          '{"flags":[{"key":"new-dashboard","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[],"rollout":{"percentage":0,"salt":"abc123","target":{"value":{"value":{"boolean":true}}},"rules":[]}}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'new-dashboard',
        rulesJson: rulesJson,
        contexts: <Context>[Context.user(id: 'user_1')],
      );

      expect(flag, isNotNull);
      expect(flag!.isEnabled(), isFalse);
    });

    test('isnull matches when attribute is absent', () {
      const rulesJson =
          '{"flags":[{"key":"null-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"tag","comparer":"isnull","values":[]},"value":{"value":{"string":"matched"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'null-flag',
        rulesJson: rulesJson,
        contexts: <Context>[Context.user(id: 'u1')],
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('matched'));
    });

    test('notnull matches when attribute has a value', () {
      const rulesJson =
          '{"flags":[{"key":"null-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"tag","comparer":"notnull","values":[]},"value":{"value":{"string":"matched"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'null-flag',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'tag': 'active'})
        ],
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('matched'));
    });

    test('notnull does not match when attribute is absent', () {
      const rulesJson =
          '{"flags":[{"key":"null-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"tag","comparer":"notnull","values":[]},"value":{"value":{"string":"matched"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'null-flag',
        rulesJson: rulesJson,
        contexts: <Context>[Context.user(id: 'u1')],
      );

      expect(flag!.asString(), equals('default'));
    });

    test('negative operators match when attribute is absent', () {
      for (final op in ['notequal', 'notin', 'notcontains', 'notstartswith', 'notendswith']) {
        final rulesJson =
            '{"flags":[{"key":"neg-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"missing","comparer":"$op","values":["x"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'neg-flag',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'u1')],
        );

        expect(flag!.asString(), equals('matched'), reason: '$op should match absent attr');
      }
    });

  });
}
