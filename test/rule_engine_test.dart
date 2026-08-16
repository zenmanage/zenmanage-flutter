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

    test('evaluateAllFlags applies a matching rule for a flag', () {
      const rulesJson =
          '{"flags":[{"key":"beta","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[{"position":1,"criteria":{"selector":"context","comparer":"equals","values":[{"identifier":"u1","type":"user"}]},"value":{"value":{"boolean":true}}}]}]}';

      final flags = engine.evaluateAllFlags(
        rulesJson: rulesJson,
        contexts: <Context>[Context.user(id: 'u1')],
      );

      expect(flags.single.isEnabled(), isTrue);
    });

    test('supports map-style flags keyed by flag key with target/rules', () {
      const rulesJson =
          '{"flags":{"checkout-flow":{"type":"string","target":{"value":{"value":{"string":"control"}}},"rules":[]}}}';

      final flag = engine.evaluateFlag(
        flagKey: 'checkout-flow',
        rulesJson: rulesJson,
      );

      expect(flag, isNotNull);
      expect(flag!.asString(), equals('control'));
    });

    test('extracts a nested number-typed value', () {
      const rulesJson =
          '{"flags":[{"key":"price","type":"number","target":{"value":{"value":{"number":42}}},"rules":[]}]}';

      final flag = engine.evaluateFlag(flagKey: 'price', rulesJson: rulesJson);

      expect(flag, isNotNull);
      expect(flag!.asNumber(), equals(42));
    });

    test('infers flag type from value when the type field is absent', () {
      const rulesJson =
          '{"flags":[{"key":"untyped","target":{"value":{"value":{"string":"hello"}}},"rules":[]}]}';

      final flag = engine.evaluateFlag(flagKey: 'untyped', rulesJson: rulesJson);

      expect(flag, isNotNull);
      expect(flag!.type, equals('string'));
    });

    test('rule matches via a clauses list requiring every condition', () {
      const rulesJson =
          '{"flags":[{"key":"multi-cond","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[{"position":1,"clauses":[{"selector":"attribute","selector_subtype":"country","comparer":"equals","values":["US"]},{"selector":"attribute","selector_subtype":"plan","comparer":"equals","values":["pro"]}],"value":{"value":{"boolean":true}}}]}]}';

      final matching = engine.evaluateFlag(
        flagKey: 'multi-cond',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'US', 'plan': 'pro'})
        ],
      );
      expect(matching!.isEnabled(), isTrue);

      final partial = engine.evaluateFlag(
        flagKey: 'multi-cond',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'US', 'plan': 'free'})
        ],
      );
      expect(partial!.isEnabled(), isFalse, reason: 'not every clause matched');
    });

    test('isnull matches when the attribute resolves to an empty list', () {
      const rulesJson =
          '{"flags":[{"key":"tag-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"tags","comparer":"isnull","values":[]},"value":{"value":{"string":"matched"}}}]}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'tag-flag',
        rulesJson: rulesJson,
        contexts: <Context>[
          Context.user(id: 'u1', attributes: <String, dynamic>{'tags': <String>[]})
        ],
      );

      expect(flag!.asString(), equals('matched'));
    });

    group('legacy shorthand selector (attribute key stored directly)', () {
      test('returns the default when no context is provided', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"country","comparer":"equals","values":["US"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(flagKey: 'legacy-flag', rulesJson: rulesJson);

        expect(flag!.asString(), equals('default'));
      });

      test('returns the default when the attribute is absent and the comparer is not negated', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"country","comparer":"equals","values":["US"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'legacy-flag',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'u1')],
        );

        expect(flag!.asString(), equals('default'));
      });

      test('isnull matches when the attribute is absent', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"country","comparer":"isnull","values":[]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'legacy-flag',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'u1')],
        );

        expect(flag!.asString(), equals('matched'));
      });

      test('negated comparer matches when the attribute value differs', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"country","comparer":"notequal","values":["US"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'legacy-flag',
          rulesJson: rulesJson,
          contexts: <Context>[
            Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'CA'})
          ],
        );

        expect(flag!.asString(), equals('matched'));
      });

      test('comparer matches the attribute value', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"country","comparer":"equals","values":["US"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'legacy-flag',
          rulesJson: rulesJson,
          contexts: <Context>[
            Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'US'})
          ],
        );

        expect(flag!.asString(), equals('matched'));
      });

      test('comparer falls back to default when the attribute does not match', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"country","comparer":"equals","values":["US"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'legacy-flag',
          rulesJson: rulesJson,
          contexts: <Context>[
            Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'CA'})
          ],
        );

        expect(flag!.asString(), equals('default'));
      });
    });

    group('condition value expressed via singular "value" key', () {
      test('a list produces one expected value per entry', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"country","comparer":"equals","value":["US","CA"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'legacy-flag',
          rulesJson: rulesJson,
          contexts: <Context>[
            Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'CA'})
          ],
        );

        expect(flag!.asString(), equals('matched'));
      });

      test('a map is used as a single expected value', () {
        const rulesJson =
            '{"flags":[{"key":"beta","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[{"position":1,"criteria":{"selector":"context","comparer":"equals","value":{"identifier":"user_1","type":"user"}},"value":{"value":{"boolean":true}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'beta',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'user_1')],
        );

        expect(flag!.isEnabled(), isTrue);
      });

      test('a scalar is used as a single expected value', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"country","comparer":"equals","value":"US"},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'legacy-flag',
          rulesJson: rulesJson,
          contexts: <Context>[
            Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'US'})
          ],
        );

        expect(flag!.asString(), equals('matched'));
      });
    });

    group('context selector operator support', () {
      test('the in comparer matches a comma-separated list', () {
        const rulesJson =
            '{"flags":[{"key":"legacy-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"country","comparer":"in","values":["US,CA,MX"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'legacy-flag',
          rulesJson: rulesJson,
          contexts: <Context>[
            Context.user(id: 'u1', attributes: <String, dynamic>{'country': 'CA'})
          ],
        );

        expect(flag!.asString(), equals('matched'));
      });

      test('gt matches a numeric attribute greater than the expected value', () {
        const rulesJson =
            '{"flags":[{"key":"age-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"age","comparer":"gt","values":["18"]},"value":{"value":{"string":"adult"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'age-flag',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'u1', attributes: <String, dynamic>{'age': 21})],
        );

        expect(flag!.asString(), equals('adult'));
      });

      test('gte matches a numeric attribute equal to the expected value', () {
        const rulesJson =
            '{"flags":[{"key":"score-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"score","comparer":"gte","values":["88.5"]},"value":{"value":{"string":"pass"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'score-flag',
          rulesJson: rulesJson,
          contexts: <Context>[
            Context.user(id: 'u1', attributes: <String, dynamic>{'score': 88.5})
          ],
        );

        expect(flag!.asString(), equals('pass'));
      });

      test('lt matches a numeric attribute less than the expected value', () {
        const rulesJson =
            '{"flags":[{"key":"age-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"age","comparer":"lt","values":["18"]},"value":{"value":{"string":"minor"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'age-flag',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'u1', attributes: <String, dynamic>{'age': 12})],
        );

        expect(flag!.asString(), equals('minor'));
      });

      test('lte matches a numeric attribute less than or equal to the expected value', () {
        const rulesJson =
            '{"flags":[{"key":"score-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"score","comparer":"lte","values":["50"]},"value":{"value":{"string":"fail"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'score-flag',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'u1', attributes: <String, dynamic>{'score': 50})],
        );

        expect(flag!.asString(), equals('fail'));
      });

      test('regex matches an attribute against a pattern', () {
        const rulesJson =
            '{"flags":[{"key":"email-flag","type":"string","target":{"value":{"value":{"string":"default"}}},"rules":[{"position":1,"criteria":{"selector":"attribute","selector_subtype":"email","comparer":"regex","values":["^.+@example\\\\.com\$"]},"value":{"value":{"string":"matched"}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'email-flag',
          rulesJson: rulesJson,
          contexts: <Context>[
            Context.user(id: 'u1', attributes: <String, dynamic>{'email': 'alice@example.com'})
          ],
        );

        expect(flag!.asString(), equals('matched'));
      });

      test('supports isnull directly against the context identifier', () {
        const rulesJson =
            '{"flags":[{"key":"beta","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[{"position":1,"criteria":{"selector":"context","comparer":"isnull","values":[{"identifier":"x"}]},"value":{"value":{"boolean":true}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'beta',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'user_1')],
        );

        expect(flag!.isEnabled(), isFalse, reason: 'the context identifier is not null');
      });

      test('supports notnull directly against the context identifier', () {
        const rulesJson =
            '{"flags":[{"key":"beta","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[{"position":1,"criteria":{"selector":"context","comparer":"notnull","values":[{"identifier":"x"}]},"value":{"value":{"boolean":true}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'beta',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'user_1')],
        );

        expect(flag!.isEnabled(), isTrue);
      });

      test('supports an underscore-prefixed negated comparer', () {
        const rulesJson =
            '{"flags":[{"key":"beta","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[{"position":1,"criteria":{"selector":"context","comparer":"not_equals","values":[{"identifier":"user_2"}]},"value":{"value":{"boolean":true}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'beta',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'user_1')],
        );

        expect(flag!.isEnabled(), isTrue);
      });

      test('supports a non-underscore negated comparer', () {
        const rulesJson =
            '{"flags":[{"key":"beta","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[{"position":1,"criteria":{"selector":"context","comparer":"notequal","values":[{"identifier":"user_2"}]},"value":{"value":{"boolean":true}}}]}]}';

        final flag = engine.evaluateFlag(
          flagKey: 'beta',
          rulesJson: rulesJson,
          contexts: <Context>[Context.user(id: 'user_1')],
        );

        expect(flag!.isEnabled(), isTrue);
      });
    });

    test('rollout percentage accepts a numeric (non-int) value', () {
      const rulesJson =
          '{"flags":[{"key":"new-dashboard","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[],"rollout":{"percentage":100.0,"salt":"abc123","target":{"value":{"value":{"boolean":true}}},"rules":[]}}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'new-dashboard',
        rulesJson: rulesJson,
        contexts: <Context>[Context.user(id: 'user_1')],
      );

      expect(flag!.isEnabled(), isTrue);
    });

    test('rollout percentage accepts a string value', () {
      const rulesJson =
          '{"flags":[{"key":"new-dashboard","type":"boolean","target":{"value":{"value":{"boolean":false}}},"rules":[],"rollout":{"percentage":"100","salt":"abc123","target":{"value":{"value":{"boolean":true}}},"rules":[]}}]}';

      final flag = engine.evaluateFlag(
        flagKey: 'new-dashboard',
        rulesJson: rulesJson,
        contexts: <Context>[Context.user(id: 'user_1')],
      );

      expect(flag!.isEnabled(), isTrue);
    });
  });
}
