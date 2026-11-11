/// Context models for providing user and entity information to Zenmanage
library;

/// Represents context information about a user, organization, or other entity
/// for feature flag evaluation
class Context {
  /// Creates a context with the given type, identifier, name, and attributes
  Context({
    required this.type,
    required this.identifier,
    this.name,
    this.attributes = const {},
  }) : assert(type.isNotEmpty, 'Context type cannot be empty');

  /// The type of entity (e.g., 'user', 'organization', 'account')
  final String type;

  /// Unique identifier for the entity
  final String identifier;

  /// Optional display name
  final String? name;

  /// Additional attributes for targeting and personalization
  final Map<String, dynamic> attributes;

  /// Creates a context for a user
  factory Context.user({
    required String id,
    String? name,
    Map<String, dynamic>? attributes,
  }) =>
      Context(
        type: 'user',
        identifier: id,
        name: name,
        attributes: attributes ?? {},
      );

  /// Creates a context for an organization
  factory Context.organization({
    required String id,
    String? name,
    Map<String, dynamic>? attributes,
  }) =>
      Context(
        type: 'organization',
        identifier: id,
        name: name,
        attributes: attributes ?? {},
      );

  /// Creates a context for an account
  factory Context.account({
    required String id,
    String? name,
    Map<String, dynamic>? attributes,
  }) =>
      Context(
        type: 'account',
        identifier: id,
        name: name,
        attributes: attributes ?? {},
      );

  /// Converts context to JSON for API requests
  Map<String, dynamic> toJson() => {
        'type': type,
        'identifier': identifier,
        if (name != null) 'name': name,
        if (attributes.isNotEmpty) 'attributes': attributes,
      };

  /// Creates a copy of this context with optional overrides
  Context copyWith({
    String? type,
    String? identifier,
    String? name,
    Map<String, dynamic>? attributes,
  }) =>
      Context(
        type: type ?? this.type,
        identifier: identifier ?? this.identifier,
        name: name ?? this.name,
        attributes: attributes ?? this.attributes,
      );

  @override
  String toString() =>
      'Context(type: $type, identifier: $identifier, name: $name)';
}
