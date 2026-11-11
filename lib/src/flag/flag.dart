/// Flag model for type-safe access to feature flag values
library;

import '../exceptions/exceptions.dart';

/// Represents a feature flag with type-safe value accessors
class Flag {
  /// Creates a flag with the given key, value, and type
  Flag({
    required this.key,
    required this.value,
    required this.type,
  });

  /// The unique key/identifier for this flag
  final String key;

  /// The raw value of the flag
  final dynamic value;

  /// The type of the flag value (boolean, string, number, json)
  final String type;

  /// Returns true if the flag is enabled (boolean true or truthy value)
  bool isEnabled() {
    if (type == 'boolean') {
      return value is bool ? value as bool : false;
    }
    // For non-boolean types, consider it enabled if truthy
    return _isTruthy(value);
  }

  /// Gets the raw flag value
  dynamic getValue() => value;

  /// Converts the flag value to a boolean
  ///
  /// Throws [TypeConversionException] if conversion fails
  bool asBool() {
    try {
      if (value is bool) {
        return value as bool;
      }
      if (value is String) {
        final str = (value as String).toLowerCase();
        return str == 'true' || str == '1' || str == 'yes';
      }
      if (value is int) {
        return (value as int) != 0;
      }
      if (value is double) {
        return (value as double) != 0.0;
      }
      if (value is Map || value is List) {
        // A json-typed flag's value is never a lossy conversion target for
        // asBool(): it's simply "not the boolean type", so it's always
        // true, regardless of whether the decoded json is empty.
        return true;
      }
      return _isTruthy(value);
    } catch (e) {
      throw TypeConversionException('${value.runtimeType}', 'bool',
          value: value);
    }
  }

  /// Converts the flag value to a string
  ///
  /// Throws [TypeConversionException] if conversion fails
  String asString() {
    try {
      if (value is String) {
        return value as String;
      }
      if (value is bool) {
        return (value as bool) ? 'true' : 'false';
      }
      if (value is num) {
        return value.toString();
      }
      if (value == null) {
        return '';
      }
      if (value is Map || value is List) {
        // A json-typed flag's value has no lossy string form to fall back
        // to (unlike toString() on a Dart Map/List, which would leak
        // internal representation), so asString() returns the same safe
        // zero value it uses for any other non-string type.
        return '';
      }
      return value.toString();
    } catch (e) {
      throw TypeConversionException('${value.runtimeType}', 'String',
          value: value);
    }
  }

  /// Converts the flag value to a number (int or double)
  ///
  /// Throws [TypeConversionException] if conversion fails
  num asNumber() {
    try {
      if (value is num) {
        return value as num;
      }
      if (value is String) {
        final str = value as String;
        // Try parsing as int first, then as double
        try {
          return int.parse(str);
        } catch (_) {
          return double.parse(str);
        }
      }
      if (value is bool) {
        return (value as bool) ? 1 : 0;
      }
      if (value is Map || value is List) {
        // A json-typed flag's value never converts to a number; fall back
        // to the same safe zero value as any other non-number type instead
        // of throwing.
        return 0;
      }
      throw TypeConversionException('${value.runtimeType}', 'num',
          value: value);
    } catch (e) {
      if (e is TypeConversionException) rethrow;
      throw TypeConversionException('${value.runtimeType}', 'num',
          value: value);
    }
  }

  /// Converts the flag value to an integer
  ///
  /// Throws [TypeConversionException] if conversion fails
  int asInt() => asNumber().toInt();

  /// Converts the flag value to a double
  ///
  /// Throws [TypeConversionException] if conversion fails
  double asDouble() => asNumber().toDouble();

  /// Converts the flag value to a JSON object/map
  ///
  /// Returns an empty map `{}` for a non-json flag, or for a json flag
  /// whose decoded value is list-shaped rather than map-shaped — the same
  /// safe zero-value fallback the other typed accessors use, never a
  /// lossy conversion or a thrown exception. Use [asList] for list-shaped
  /// json values.
  Map<String, dynamic> asJson() {
    if (value is Map<String, dynamic>) {
      return value as Map<String, dynamic>;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return <String, dynamic>{};
  }

  /// Converts the flag value to a list
  ///
  /// Returns an empty list `[]` for a non-json flag, or for a json flag
  /// whose decoded value is map-shaped rather than list-shaped — the same
  /// safe zero-value fallback the other typed accessors use, never a
  /// lossy conversion or a thrown exception. Use [asJson] for map-shaped
  /// json values.
  List<T> asList<T>() {
    if (value is List<T>) {
      return value as List<T>;
    }
    if (value is List) {
      return List<T>.from(value as List);
    }
    return <T>[];
  }

  /// Helper to check if a value is truthy
  static bool _isTruthy(dynamic value) {
    if (value is bool) return value;
    if (value is String) return value.isNotEmpty;
    if (value is num) return value != 0;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return value != null;
  }

  @override
  String toString() => 'Flag(key: $key, value: $value, type: $type)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Flag &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value &&
          type == other.type;

  @override
  int get hashCode => key.hashCode ^ value.hashCode ^ type.hashCode;
}
