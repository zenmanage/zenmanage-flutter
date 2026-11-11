library;

import 'package:flutter/widgets.dart';

import '../context/context.dart';
import '../flag/flag.dart';
import '../zenmanage.dart';

/// Provides a [Zenmanage] instance to the widget subtree.
class ZenmanageProvider extends InheritedWidget {
  /// Creates a Zenmanage provider.
  const ZenmanageProvider({
    super.key,
    required this.zenmanage,
    required super.child,
  });

  /// The SDK instance available to descendants.
  final Zenmanage zenmanage;

  /// Returns the nearest [Zenmanage] instance from context.
  static Zenmanage of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<ZenmanageProvider>();
    assert(provider != null, 'No ZenmanageProvider found in widget tree.');
    return provider!.zenmanage;
  }

  @override
  bool updateShouldNotify(ZenmanageProvider oldWidget) =>
      zenmanage != oldWidget.zenmanage;
}

/// Initializes the SDK asynchronously and exposes it via [ZenmanageProvider].
class ZenmanageInitializer extends StatefulWidget {
  /// Creates a startup wrapper that initializes Zenmanage before rendering [child].
  const ZenmanageInitializer({
    super.key,
    required this.zenmanage,
    required this.child,
    this.contexts = const <Context>[],
    this.loadingBuilder,
    this.errorBuilder,
  });

  /// SDK instance to initialize and provide.
  final Zenmanage zenmanage;

  /// Child subtree that can consume [ZenmanageProvider].
  final Widget child;

  /// Optional contexts used during initial prefetch.
  final List<Context> contexts;

  /// Optional loading UI while initialization is in progress.
  final WidgetBuilder? loadingBuilder;

  /// Optional error UI when initialization fails.
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  @override
  State<ZenmanageInitializer> createState() => _ZenmanageInitializerState();
}

class _ZenmanageInitializerState extends State<ZenmanageInitializer> {
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = widget.zenmanage.initialize(
      contexts: widget.contexts,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          if (widget.errorBuilder != null) {
            return widget.errorBuilder!(
              context,
              snapshot.error!,
              snapshot.stackTrace,
            );
          }
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState != ConnectionState.done) {
          if (widget.loadingBuilder != null) {
            return widget.loadingBuilder!(context);
          }
          return const SizedBox.shrink();
        }

        return ZenmanageProvider(
          zenmanage: widget.zenmanage,
          child: widget.child,
        );
      },
    );
  }
}

/// Widget-level helper for reading and rendering one feature flag.
class ZenmanageFlagBuilder extends StatefulWidget {
  /// Creates a flag-aware widget.
  const ZenmanageFlagBuilder({
    super.key,
    required this.flagKey,
    required this.builder,
    this.defaultValue,
    this.context,
  });

  /// Flag key to evaluate.
  final String flagKey;

  /// Optional default value used when the flag does not exist.
  final dynamic defaultValue;

  /// Optional evaluation context for this widget.
  final Context? context;

  /// Builder that receives loading/error/data states.
  final Widget Function(BuildContext, AsyncSnapshot<Flag>) builder;

  @override
  State<ZenmanageFlagBuilder> createState() => _ZenmanageFlagBuilderState();
}

class _ZenmanageFlagBuilderState extends State<ZenmanageFlagBuilder> {
  late Future<Flag> _flagFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _flagFuture = _loadFlag(context);
  }

  @override
  void didUpdateWidget(covariant ZenmanageFlagBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flagKey != widget.flagKey ||
        oldWidget.defaultValue != widget.defaultValue ||
        oldWidget.context != widget.context) {
      _flagFuture = _loadFlag(context);
    }
  }

  Future<Flag> _loadFlag(BuildContext context) async {
    final zenmanage = ZenmanageProvider.of(context);
    final manager = zenmanage.flags();

    if (widget.context != null) {
      manager.withContext(widget.context!);
    } else {
      manager.clearContext();
    }

    if (widget.defaultValue != null) {
      return manager.singleOrDefault(
        widget.flagKey,
        Flag(
          key: widget.flagKey,
          value: widget.defaultValue,
          type: _inferFlagType(widget.defaultValue),
        ),
      );
    }

    return manager.single(widget.flagKey);
  }

  static String _inferFlagType(dynamic value) {
    if (value is bool) return 'boolean';
    if (value is num) return 'number';
    if (value is String) return 'string';
    if (value is List || value is Map) return 'json';
    return 'boolean';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Flag>(
      future: _flagFuture,
      builder: widget.builder,
    );
  }
}
