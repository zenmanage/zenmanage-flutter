/// Rule engine for local flag evaluation
library;

import 'dart:convert';
import 'dart:developer' as developer;

import 'context/context.dart';
import 'flag/flag.dart';

/// Evaluates feature flag rules locally
///
/// Rules are fetched from the API and cached. This engine evaluates them
/// against the provided context for fast, sub-millisecond evaluation times.
class RuleEngine {
  static final List<int> _crc32Table = _createCrc32Table();

  /// Evaluates a single flag against the given rules and context
  ///
  /// Returns the flag value or null if the flag is not found
  Flag? evaluateFlag({
    required String flagKey,
    required String rulesJson,
    List<Context>? contexts,
    dynamic defaultValue,
  }) {
    try {
      final payload = _decodePayload(rulesJson);
      if (payload == null) {
        return null;
      }

      final flagData = _findFlag(payload, flagKey);
      if (flagData == null) {
        return null;
      }

      final selected = _selectTargetAndRules(
        flagData,
        contexts ?? const <Context>[],
      );

      final targetValue = _extractTypedValue(selected.target);
      final matched = _evaluateMatchingRule(
        selected.rules,
        contexts ?? const <Context>[],
      );

      final value = matched != null
          ? _extractTypedValue(matched['value'])
          : targetValue;

      final resolved = value ?? defaultValue;
      if (resolved == null) {
        return null;
      }

      return Flag(
        key: flagKey,
        value: resolved,
        type: _resolveFlagType(flagData, resolved),
      );
    } catch (_) {
      return null;
    }
  }

  /// Evaluates all flags against the given rules
  ///
  /// Returns a list of all available flags
  List<Flag> evaluateAllFlags({
    required String rulesJson,
    List<Context>? contexts,
  }) {
    final flags = <Flag>[];

    try {
      final payload = _decodePayload(rulesJson);
      if (payload == null) {
        return flags;
      }

      final normalized = _normalizeFlags(payload);
      for (final flagData in normalized) {
        final key = flagData['key'] as String?;
        if (key == null || key.isEmpty) {
          continue;
        }

        final selected = _selectTargetAndRules(
          flagData,
          contexts ?? const <Context>[],
        );
        final targetValue = _extractTypedValue(selected.target);
        final matched = _evaluateMatchingRule(
          selected.rules,
          contexts ?? const <Context>[],
        );
        final resolved = matched != null
            ? _extractTypedValue(matched['value'])
            : targetValue;

        if (resolved == null) {
          continue;
        }

        flags.add(
          Flag(
            key: key,
            value: resolved,
            type: _resolveFlagType(flagData, resolved),
          ),
        );
      }
    } catch (_) {
      // Silently ignore parsing errors
    }

    return flags;
  }

  Map<String, dynamic>? _decodePayload(String rulesJson) {
    final decoded = jsonDecode(rulesJson);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    return decoded;
  }

  Map<String, dynamic>? _findFlag(Map<String, dynamic> payload, String key) {
    final normalized = _normalizeFlags(payload);
    for (final flag in normalized) {
      if (flag['key'] == key) {
        return flag;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _normalizeFlags(Map<String, dynamic> payload) {
    final rawFlags = payload['flags'];
    if (rawFlags is List) {
      return rawFlags
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (rawFlags is Map) {
      return rawFlags.entries
          .where((e) => e.value is Map || e.value is bool || e.value is num || e.value is String)
          .map((entry) {
        final value = entry.value;
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          if (map.containsKey('target') || map.containsKey('rules') || map.containsKey('rollout')) {
            map.putIfAbsent('key', () => entry.key.toString());
            return map;
          }

          // Simplified shape: {"value": ..., "type": ...} directly, without
          // the nested target/rules/rollout structure.
          final rawValue = map['value'];
          return <String, dynamic>{
            'key': entry.key.toString(),
            'target': <String, dynamic>{
              'value': <String, dynamic>{
                'value': rawValue,
              },
            },
            'type': map['type']?.toString() ?? _inferType(rawValue),
            'rules': const <Map<String, dynamic>>[],
          };
        }

        return <String, dynamic>{
          'key': entry.key.toString(),
          'target': <String, dynamic>{
            'value': <String, dynamic>{
              'value': value,
            },
          },
          'type': _inferType(value),
          'rules': const <Map<String, dynamic>>[],
        };
      }).toList();
    }

    return const <Map<String, dynamic>>[];
  }

  ({Map<String, dynamic>? target, List<Map<String, dynamic>> rules})
      _selectTargetAndRules(
    Map<String, dynamic> flag,
    List<Context> contexts,
  ) {
    Map<String, dynamic>? target = _asMap(flag['target']);
    var rules = _asMapList(flag['rules']);

    final rollout = _asMap(flag['rollout']);
    if (rollout != null) {
      final percentage = _toInt(rollout['percentage']);
      final salt = rollout['salt']?.toString() ?? '';
      final contextIdentifier = _resolveContextIdentifier(contexts);

      if (percentage != null &&
          percentage >= 0 &&
          percentage <= 100 &&
          _isInBucket(salt, contextIdentifier, percentage)) {
        target = _asMap(rollout['target']) ?? target;
        final rolloutRules = _asMapList(rollout['rules']);
        if (rolloutRules.isNotEmpty) {
          rules = rolloutRules;
        }
      }
    }

    return (target: target, rules: rules);
  }

  Map<String, dynamic>? _evaluateMatchingRule(
    List<Map<String, dynamic>> rules,
    List<Context> contexts,
  ) {
    if (rules.isEmpty) {
      return null;
    }

    final sorted = List<Map<String, dynamic>>.from(rules)
      ..sort((a, b) => (_toInt(a['position']) ?? 0).compareTo(_toInt(b['position']) ?? 0));

    for (final rule in sorted) {
      if (_ruleMatches(rule, contexts)) {
        return rule;
      }
    }

    return null;
  }

  bool _ruleMatches(Map<String, dynamic> rule, List<Context> contexts) {
    final criteria = _asMap(rule['criteria']);
    if (criteria != null) {
      return _conditionMatches(criteria, contexts);
    }

    final clauses = rule['clauses'];
    if (clauses is List && clauses.isNotEmpty) {
      return clauses.whereType<Map>().every(
            (c) => _conditionMatches(Map<String, dynamic>.from(c), contexts),
          );
    }

    return true;
  }

  bool _conditionMatches(Map<String, dynamic> condition, List<Context> contexts) {
    // Supports both modern shape (selector/comparer/values) and legacy (attribute/operator/value).
    final selector = (condition['selector'] ?? condition['attribute'])?.toString();
    final subtype = (condition['selector_subtype'] ?? condition['selectorSubtype'])?.toString();
    final comparer = (condition['comparer'] ?? condition['operator'])?.toString();

    if (selector == null || comparer == null) {
      return false;
    }

    final values = _extractConditionValues(condition);
    if (values.isEmpty && _requiresExpectedValue(comparer)) {
      return false;
    }

    if (selector == 'context' || selector == 'segment') {
      final context = _resolveContextForType(contexts, values.map((v) => v.type).whereType<String>().toSet());
      if (context == null || context.identifier.isEmpty) {
        return false;
      }
      return values.any((v) {
        if (v.type != null && v.type != context.type) {
          return false;
        }
        return _evaluateOperator(comparer, context.identifier, v.identifier);
      });
    }

    if (selector == 'attribute') {
      if (subtype == null || subtype.isEmpty) {
        return false;
      }

      final context = _resolveAnyContext(contexts);
      if (context == null) {
        return false;
      }

      final actual = context.attributes[subtype];
      if (actual == null) {
        if (comparer == 'isnull') return true;
        if (comparer == 'notnull') return false;
        return comparer.startsWith('not');
      }

      final actualValues = _toValueList(actual);
      if (comparer == 'isnull') {
        return actualValues.isEmpty || actualValues.every((v) => v == null || v.toString().isEmpty);
      }
      if (comparer == 'notnull') {
        return actualValues.any((v) => v != null && v.toString().isNotEmpty);
      }
      final positiveComparer = _toPositiveComparer(comparer);
      if (positiveComparer != null) {
        // Negated operator: condition passes only if no positive match exists.
        for (final actualValue in actualValues) {
          for (final expected in values) {
            if (_evaluateOperator(positiveComparer, actualValue, expected.identifier)) {
              return false;
            }
          }
        }
        return true;
      }
      for (final actualValue in actualValues) {
        for (final expected in values) {
          if (_evaluateOperator(comparer, actualValue, expected.identifier)) {
            return true;
          }
        }
      }

      return false;
    }

    // Legacy shorthand where selector stores attribute key directly.
    final context = _resolveAnyContext(contexts);
    if (context == null) {
      return false;
    }

    final actual = context.attributes[selector];
    if (actual == null) {
      if (comparer == 'isnull') return true;
      if (comparer == 'notnull') return false;
      return comparer.startsWith('not');
    }

    final actualValues = _toValueList(actual);
    final expectedValues = values.map((e) => e.identifier).toList();
    final legacyPositive = _toPositiveComparer(comparer);
    if (legacyPositive != null) {
      for (final actualValue in actualValues) {
        for (final expected in expectedValues) {
          if (_evaluateOperator(legacyPositive, actualValue, expected)) {
            return false;
          }
        }
      }
      return true;
    }
    for (final actualValue in actualValues) {
      for (final expected in expectedValues) {
        if (_evaluateOperator(comparer, actualValue, expected)) {
          return true;
        }
      }
    }

    return false;
  }

  List<_ConditionValue> _extractConditionValues(Map<String, dynamic> condition) {
    final values = condition['values'];
    if (values is List) {
      return values.map((value) {
        if (value is Map) {
          final map = Map<String, dynamic>.from(value);
          return _ConditionValue(
            identifier: map['identifier']?.toString() ?? '',
            type: map['type']?.toString(),
          );
        }
        return _ConditionValue(identifier: value.toString(), type: null);
      }).where((v) => v.identifier.isNotEmpty).toList();
    }

    final value = condition['value'];
    if (value is List) {
      return value.map((v) => _ConditionValue(identifier: v.toString(), type: null)).toList();
    }

    if (value != null) {
      if (value is Map) {
        return <_ConditionValue>[
          _ConditionValue(
            identifier: value['identifier']?.toString() ?? '',
            type: value['type']?.toString(),
          )
        ].where((v) => v.identifier.isNotEmpty).toList();
      }

      return <_ConditionValue>[
        _ConditionValue(identifier: value.toString(), type: null)
      ];
    }

    return const <_ConditionValue>[];
  }

  /// Returns the positive (non-negated) form of a negated comparer, or null
  /// if the comparer is already positive or is a special case (notnull, isnull).
  String? _toPositiveComparer(String comparer) {
    final normalized = comparer.toLowerCase().replaceAll('-', '_');
    if (normalized == 'notnull' || normalized == 'isnull') return null;
    if (normalized.startsWith('not_')) return normalized.substring(4);
    if (normalized.startsWith('not') && normalized.length > 3) return normalized.substring(3);
    return null;
  }

  bool _evaluateOperator(String operator, dynamic actual, String expectedRaw) {
    final normalized = operator.toLowerCase().replaceAll('-', '_');
    bool negate = false;
    String base;
    if (normalized.startsWith('not_')) {
      negate = true;
      base = normalized.substring(4);
    } else if (normalized.startsWith('not') && normalized.length > 3) {
      negate = true;
      base = normalized.substring(3);
    } else {
      base = normalized;
    }

    // Comparer names arrive in a few equivalent spellings (e.g. "equals" vs
    // "equal", "starts_with" vs "startswith") — collapse underscores so a
    // single set of switch cases handles all of them.
    final baseKey = base.replaceAll('_', '');

    bool result;
    switch (baseKey) {
      case 'equal':
      case 'equals':
        result = '$actual' == expectedRaw;
        break;
      case 'contains':
        result = '$actual'.contains(expectedRaw);
        break;
      case 'in':
        result = expectedRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .contains('$actual');
        break;
      case 'startswith':
        result = '$actual'.startsWith(expectedRaw);
        break;
      case 'endswith':
        result = '$actual'.endsWith(expectedRaw);
        break;
      case 'gt':
        result = (_toDouble(actual) ?? double.negativeInfinity) >
            (_toDouble(expectedRaw) ?? double.infinity);
        break;
      case 'gte':
        result = (_toDouble(actual) ?? double.negativeInfinity) >=
            (_toDouble(expectedRaw) ?? double.infinity);
        break;
      case 'lt':
        result = (_toDouble(actual) ?? double.infinity) <
            (_toDouble(expectedRaw) ?? double.negativeInfinity);
        break;
      case 'lte':
        result = (_toDouble(actual) ?? double.infinity) <=
            (_toDouble(expectedRaw) ?? double.negativeInfinity);
        break;
      case 'isnull':
        result = actual == null || actual.toString().isEmpty;
        break;
      case 'notnull':
        result = actual != null && actual.toString().isNotEmpty;
        break;
      case 'regex':
        result = RegExp(expectedRaw).hasMatch('$actual');
        break;
      default:
        result = false;
    }

    return negate ? !result : result;
  }

  bool _requiresExpectedValue(String comparer) {
    final normalized = comparer.toLowerCase().replaceAll('-', '_');
    return normalized != 'isnull' && normalized != 'notnull';
  }

  dynamic _extractTypedValue(dynamic source) {
    final map = _asMap(source);
    if (map == null) {
      return source;
    }

    final valueWrapper = _asMap(map['value']) ?? map;
    final typed = _asMap(valueWrapper['value']) ?? valueWrapper;

    if (typed.containsKey('boolean')) {
      return typed['boolean'];
    }
    if (typed.containsKey('string')) {
      return typed['string'];
    }
    if (typed.containsKey('number')) {
      return typed['number'];
    }
    if (typed.containsKey('json')) {
      return typed['json'];
    }
    if (typed.containsKey('value')) {
      return typed['value'];
    }

    // Wrapper key isn't one this SDK release knows how to unwrap (for
    // example a still-newer flag type this release predates). Treat it
    // the same as a flag that couldn't be resolved rather than handing
    // back the raw wrapper map, so evaluation falls back to the call-site
    // default instead of returning garbage.
    _logUnsupportedValue(typed);
    return null;
  }

  /// Logs (once per call) that a flag's value wrapper used a key this SDK
  /// release doesn't recognize, so evaluation is falling back to the
  /// call-site default instead of returning the raw wrapper.
  void _logUnsupportedValue(Map<String, dynamic> typed) {
    developer.log(
      'Unsupported flag value type encountered (keys: ${typed.keys.join(', ')}). '
      'Falling back to the call-site default. Upgrade the zenmanage SDK to '
      'add support for this type.',
      name: 'zenmanage.rule_engine',
      level: 900, // warning
    );
  }

  String _resolveFlagType(Map<String, dynamic> flag, dynamic value) {
    final explicit = flag['type']?.toString();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return _inferType(value);
  }

  String _inferType(dynamic value) {
    if (value is bool) return 'boolean';
    if (value is num) return 'number';
    if (value is String) return 'string';
    return 'json';
  }

  static List<int> _createCrc32Table() {
    final table = List<int>.filled(256, 0);
    for (var i = 0; i < 256; i++) {
      var crc = i;
      for (var j = 0; j < 8; j++) {
        if ((crc & 1) == 1) {
          crc = (crc >> 1) ^ 0xedb88320;
        } else {
          crc = crc >> 1;
        }
      }
      table[i] = crc;
    }
    return table;
  }

  bool _isInBucket(String salt, String? contextIdentifier, int percentage) {
    if (contextIdentifier == null) {
      return false;
    }

    var crc = 0xffffffff;
    final input = '$salt:$contextIdentifier'.codeUnits;
    for (final byte in input) {
      crc = (crc >> 8) ^ _crc32Table[(crc ^ (byte & 0xff)) & 0xff];
    }

    final unsigned = (crc ^ 0xffffffff) & 0xffffffff;
    return (unsigned % 100) < percentage;
  }

  String? _resolveContextIdentifier(List<Context> contexts) {
    final context = _resolveAnyContext(contexts);
    if (context == null || context.identifier.isEmpty) {
      return null;
    }
    return context.identifier;
  }

  Context? _resolveContextForType(List<Context> contexts, Set<String> types) {
    if (contexts.isEmpty) {
      return null;
    }
    if (types.isEmpty) {
      return contexts.first;
    }

    for (final context in contexts) {
      if (types.contains(context.type)) {
        return context;
      }
    }
    return null;
  }

  Context? _resolveAnyContext(List<Context> contexts) {
    if (contexts.isEmpty) {
      return null;
    }
    return contexts.first;
  }

  List<dynamic> _toValueList(dynamic actual) {
    if (actual is List) {
      return actual;
    }
    return <dynamic>[actual];
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }
}

final class _ConditionValue {
  const _ConditionValue({required this.identifier, required this.type});

  final String identifier;
  final String? type;
}
