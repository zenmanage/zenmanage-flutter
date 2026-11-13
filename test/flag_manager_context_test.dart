import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/src/api_client.dart';
import 'package:zenmanage/src/rule_engine.dart';
import 'package:zenmanage/zenmanage.dart';

const _rules = '{"flags":{"new-dashboard":{"value":true,"type":"boolean"}}}';

/// An [ApiClient] whose rules fetch waits for the test to release it, and
/// which records the context each usage report was made for.
class _GatedApiClient extends ApiClient {
  _GatedApiClient()
      : super(environmentToken: 'mob_test', enableUsageReporting: false);

  final List<Completer<void>> _gates = [];
  int fetches = 0;
  final List<Context?> reportedContexts = [];

  @override
  Future<Map<String, dynamic>> fetchRules({List<Context>? contexts}) async {
    fetches++;
    final gate = Completer<void>();
    _gates.add(gate);
    await gate.future;
    return {'rules': _rules};
  }

  void releaseAll() {
    for (final gate in _gates) {
      if (!gate.isCompleted) gate.complete();
    }
  }

  @override
  Future<void> reportUsage({
    required String flagKey,
    required dynamic flagValue,
    Context? context,
    dynamic defaultValue,
  }) async {
    reportedContexts.add(context);
  }
}

/// A [RuleEngine] that records the contexts it was asked to evaluate with.
class _RecordingRuleEngine extends RuleEngine {
  final List<List<Context>?> allFlagsContexts = [];

  @override
  List<Flag> evaluateAllFlags({
    required String rulesJson,
    List<Context>? contexts,
  }) {
    allFlagsContexts.add(contexts == null ? null : List.of(contexts));
    return super.evaluateAllFlags(rulesJson: rulesJson, contexts: contexts);
  }
}

void main() {
  group('FlagManager context isolation', () {
    late _GatedApiClient api;
    late _RecordingRuleEngine engine;
    late FlagManager root;

    final alice = Context.user(id: 'alice');
    final bob = Context.user(id: 'bob');

    setUp(() {
      api = _GatedApiClient();
      engine = _RecordingRuleEngine();
      root = FlagManager(
        apiClient: api,
        cache: NullCache(),
        ruleEngine: engine,
      );
    });

    test('two concurrent reads on forked managers keep their own contexts',
        () async {
      final first = root.fork().withContext(alice).single('new-dashboard');
      final second = root.fork().withContext(bob).single('new-dashboard');

      // Both reads are now waiting on the rules fetch.
      await Future<void>.delayed(Duration.zero);
      api.releaseAll();
      await Future.wait([first, second]);

      expect(api.reportedContexts, unorderedEquals(<Context?>[alice, bob]));
      // Each read must have been evaluated and reported for its own context,
      // not the other read's.
      expect(api.reportedContexts.where((c) => c == alice), hasLength(1));
      expect(api.reportedContexts.where((c) => c == bob), hasLength(1));
    });

    test('a read keeps the context it started with when its manager is reused',
        () async {
      final manager = root.fork();

      final first = manager.withContext(alice).single('new-dashboard');
      await Future<void>.delayed(Duration.zero);
      // Another read starts on the same manager while the first is waiting.
      final second = manager.withContext(bob).single('new-dashboard');

      await Future<void>.delayed(Duration.zero);
      api.releaseAll();
      await Future.wait([first, second]);

      expect(api.reportedContexts.first, equals(alice));
      expect(api.reportedContexts.last, equals(bob));
    });

    test('all() keeps the context it started with when its manager is reused',
        () async {
      final manager = root.fork();

      final first = manager.withContext(alice).all();
      await Future<void>.delayed(Duration.zero);
      manager.withContext(bob);

      api.releaseAll();
      await first;

      expect(engine.allFlagsContexts, hasLength(1));
      expect(engine.allFlagsContexts.single, equals(<Context>[alice]));
    });

    test('a forked manager starts with no context', () async {
      root.withContext(alice);

      final fork = root.fork();
      final read = fork.single('new-dashboard');
      await Future<void>.delayed(Duration.zero);
      api.releaseAll();
      await read;

      expect(api.reportedContexts, equals(<Context?>[null]));
    });

    test('a context set on a fork does not reach later forks', () async {
      root.fork().withContext(alice);

      final read = root.fork().single('new-dashboard');
      await Future<void>.delayed(Duration.zero);
      api.releaseAll();
      await read;

      expect(api.reportedContexts, equals(<Context?>[null]));
    });

    test('prefetch uses its contexts for that fetch only', () async {
      final prefetch = root.prefetch(contexts: <Context>[alice]);
      await Future<void>.delayed(Duration.zero);
      api.releaseAll();
      await prefetch;

      await root.single('new-dashboard');

      expect(api.reportedContexts, equals(<Context?>[null]));
    });

    test('forked managers share one copy of the rules', () async {
      final warm = root.fork().single('new-dashboard');
      await Future<void>.delayed(Duration.zero);
      api.releaseAll();
      await warm;

      await root.fork().withContext(bob).single('new-dashboard');
      await root.single('new-dashboard');

      expect(api.fetches, equals(1));
    });

    test('clearCache on a fork clears the rules every manager uses', () async {
      final warm = root.single('new-dashboard');
      await Future<void>.delayed(Duration.zero);
      api.releaseAll();
      await warm;

      await root.fork().clearCache();

      final again = root.single('new-dashboard');
      await Future<void>.delayed(Duration.zero);
      api.releaseAll();
      await again;

      expect(api.fetches, equals(2));
    });
  });

  group('Zenmanage.flags', () {
    test('returns a new manager on every call', () {
      final zenmanage = Zenmanage(
        ConfigBuilder.create().withEnvironmentToken('mob_test').build(),
      );

      expect(zenmanage.flags(), isNot(same(zenmanage.flags())));
    });
  });
}
