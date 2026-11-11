import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';
import 'package:zenmanage/src/api_client.dart';
import 'package:zenmanage/src/rule_engine.dart';

/// flutter_test's TestWidgetsFlutterBinding stubs every real HttpClient
/// request to return 400, so widget tests can't rely on a real HTTP server.
/// These fakes let tests drive [ZenmanageInitializer]/[ZenmanageFlagBuilder]
/// through realistic success/failure paths without any real I/O.
class _FakeApiClient extends ApiClient {
  _FakeApiClient({required this.rulesJson, this.shouldFail = false})
      : super(environmentToken: 'mob_test_token', enableUsageReporting: false);

  final String rulesJson;
  final bool shouldFail;

  @override
  Future<Map<String, dynamic>> fetchRules({List<Context>? contexts}) async {
    if (shouldFail) {
      throw ApiException('simulated failure');
    }
    return {'rules': rulesJson};
  }

  @override
  Future<void> reportUsage({
    required String flagKey,
    required dynamic flagValue,
    Context? context,
    dynamic defaultValue,
  }) async {}
}

class _FakeZenmanage extends Zenmanage {
  _FakeZenmanage({required String rulesJson, bool shouldFail = false})
      : _flagManager = FlagManager(
          apiClient: _FakeApiClient(rulesJson: rulesJson, shouldFail: shouldFail),
          cache: NullCache(),
          ruleEngine: RuleEngine(),
        ),
        super(ConfigBuilder.create().withEnvironmentToken('mob_test_token').build());

  final FlagManager _flagManager;

  @override
  FlagManager flags() => _flagManager;

  @override
  Future<void> initialize({List<Context>? contexts}) =>
      _flagManager.prefetch(contexts: contexts);
}

const _rulesWithDashboard =
    '{"flags":{"new-dashboard":{"value":true,"type":"boolean"}}}';


/// Lets real network I/O (a refused connection to the dead endpoint these
/// tests use) and the SDK's fake-time retry backoff run until [done] holds.
///
/// A rules fetch retries with a short backoff, so a test that only pumps once
/// would end with the SDK's retry timer still pending.
Future<void> _settle(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('Flutter bindings', () {
    testWidgets('ZenmanageProvider exposes SDK instance', (tester) async {
      final zenmanage = Zenmanage(
        ConfigBuilder.create()
            .withEnvironmentToken('mob_test_token')
            .build(),
      );

      late Zenmanage resolved;

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageProvider(
            zenmanage: zenmanage,
            child: Builder(
              builder: (context) {
                resolved = ZenmanageProvider.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolved, same(zenmanage));
    });

    testWidgets('ZenmanageInitializer shows loading while initializing',
        (tester) async {
      final zenmanage = Zenmanage(
        ConfigBuilder.create()
            .withEnvironmentToken('mob_test_token')
            .withApiEndpoint('http://127.0.0.1:1')
            .build(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageInitializer(
            zenmanage: zenmanage,
            loadingBuilder: (_) => const Text('loading'),
            errorBuilder: (_, __, ___) => const Text('error'),
            child: const Text('ready'),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);

      // The endpoint is unreachable, so once the retries are exhausted the
      // initializer must show the error state rather than stay on loading.
      await _settle(tester, () => find.text('error').evaluate().isNotEmpty);
      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('ZenmanageFlagBuilder renders default value path',
        (tester) async {
      final zenmanage = Zenmanage(
        ConfigBuilder.create()
            .withEnvironmentToken('mob_test_token')
            .withApiEndpoint('http://127.0.0.1:1')
            .build(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageProvider(
            zenmanage: zenmanage,
            child: ZenmanageFlagBuilder(
              flagKey: 'missing-flag',
              defaultValue: false,
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('loading');
                }
                return Text(snapshot.data!.isEnabled().toString());
              },
            ),
          ),
        ),
      );

      expect(find.text('loading'), findsOneWidget);

      // With the endpoint unreachable the call-site default is what renders.
      await _settle(tester, () => find.text('false').evaluate().isNotEmpty);
      expect(find.text('false'), findsOneWidget);
    });

    testWidgets('ZenmanageInitializer renders child once initialization succeeds',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageInitializer(
            zenmanage: zenmanage,
            child: Builder(
              builder: (context) {
                final resolved = ZenmanageProvider.of(context);
                return Text(resolved == zenmanage ? 'ready' : 'wrong');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ready'), findsOneWidget);
    });

    testWidgets('ZenmanageInitializer uses defaults when no builders are given',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageInitializer(
            zenmanage: zenmanage,
            child: const Text('ready'),
          ),
        ),
      );

      // Still loading; default loadingBuilder is an empty SizedBox.
      expect(find.text('ready'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.text('ready'), findsOneWidget);
    });

    testWidgets('ZenmanageInitializer shows errorBuilder when initialization fails',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: '', shouldFail: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageInitializer(
            zenmanage: zenmanage,
            errorBuilder: (_, error, __) => Text('error: $error'),
            child: const Text('ready'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('error:'), findsOneWidget);
    });

    testWidgets('ZenmanageInitializer defaults to an empty box on error',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: '', shouldFail: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageInitializer(
            zenmanage: zenmanage,
            child: const Text('ready'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ready'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('ZenmanageFlagBuilder resolves the actual flag value',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageProvider(
            zenmanage: zenmanage,
            child: ZenmanageFlagBuilder(
              flagKey: 'new-dashboard',
              defaultValue: false,
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('loading');
                }
                return Text(snapshot.data!.isEnabled().toString());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('ZenmanageFlagBuilder applies a per-widget context',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageProvider(
            zenmanage: zenmanage,
            child: ZenmanageFlagBuilder(
              flagKey: 'new-dashboard',
              defaultValue: false,
              context: Context.user(id: 'user-1'),
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('loading');
                }
                return Text(snapshot.data!.isEnabled().toString());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('ZenmanageFlagBuilder reloads when flagKey changes',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      Widget buildFor(String flagKey) => MaterialApp(
            home: ZenmanageProvider(
              zenmanage: zenmanage,
              child: ZenmanageFlagBuilder(
                flagKey: flagKey,
                defaultValue: false,
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('loading');
                  }
                  return Text(snapshot.data!.isEnabled().toString());
                },
              ),
            ),
          );

      await tester.pumpWidget(buildFor('new-dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('true'), findsOneWidget);

      await tester.pumpWidget(buildFor('missing-flag'));
      await tester.pumpAndSettle();
      expect(find.text('false'), findsOneWidget);
    });

    testWidgets(
        'ZenmanageFlagBuilder reloads when defaultValue changes with the same flagKey',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      Widget buildFor(dynamic defaultValue) => MaterialApp(
            home: ZenmanageProvider(
              zenmanage: zenmanage,
              child: ZenmanageFlagBuilder(
                flagKey: 'missing-flag',
                defaultValue: defaultValue,
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('loading');
                  }
                  return Text(snapshot.data!.getValue().toString());
                },
              ),
            ),
          );

      await tester.pumpWidget(buildFor(false));
      await tester.pumpAndSettle();
      expect(find.text('false'), findsOneWidget);

      await tester.pumpWidget(buildFor(true));
      await tester.pumpAndSettle();
      expect(find.text('true'), findsOneWidget);
    });

    testWidgets(
        'ZenmanageFlagBuilder reloads when context changes with the same flagKey',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      Widget buildFor(Context context) => MaterialApp(
            home: ZenmanageProvider(
              zenmanage: zenmanage,
              child: ZenmanageFlagBuilder(
                flagKey: 'new-dashboard',
                defaultValue: false,
                context: context,
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('loading');
                  }
                  return Text(snapshot.data!.isEnabled().toString());
                },
              ),
            ),
          );

      await tester.pumpWidget(buildFor(Context.user(id: 'user-1')));
      await tester.pumpAndSettle();

      await tester.pumpWidget(buildFor(Context.user(id: 'user-2')));
      await tester.pumpAndSettle();

      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('ZenmanageFlagBuilder without a defaultValue evaluates the flag directly',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageProvider(
            zenmanage: zenmanage,
            child: ZenmanageFlagBuilder(
              flagKey: 'new-dashboard',
              builder: (_, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('loading');
                }
                return Text(snapshot.data!.isEnabled().toString());
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('true'), findsOneWidget);
    });

    testWidgets('ZenmanageFlagBuilder without a defaultValue surfaces lookup errors',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      await tester.pumpWidget(
        MaterialApp(
          home: ZenmanageProvider(
            zenmanage: zenmanage,
            child: ZenmanageFlagBuilder(
              flagKey: 'missing-flag',
              builder: (_, snapshot) {
                if (snapshot.hasError) {
                  return const Text('error');
                }
                return const Text('loading');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('error'), findsOneWidget);
    });

    testWidgets('ZenmanageFlagBuilder infers the default value type for the fallback flag',
        (tester) async {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      Future<void> expectInferredType(dynamic defaultValue, String expectedType) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ZenmanageProvider(
              zenmanage: zenmanage,
              child: ZenmanageFlagBuilder(
                flagKey: 'missing-flag',
                defaultValue: defaultValue,
                builder: (_, snapshot) {
                  if (!snapshot.hasData) {
                    return const Text('loading');
                  }
                  return Text(snapshot.data!.type);
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(expectedType), findsOneWidget);
      }

      await expectInferredType(42, 'number');
      await expectInferredType('control', 'string');
      await expectInferredType(<String>['a'], 'json');
    });

    test('updateShouldNotify is true only when the SDK instance changes', () {
      final zenmanage = _FakeZenmanage(rulesJson: _rulesWithDashboard);
      final other = _FakeZenmanage(rulesJson: _rulesWithDashboard);

      final widget = ZenmanageProvider(zenmanage: zenmanage, child: const SizedBox());
      final sameInstance = ZenmanageProvider(zenmanage: zenmanage, child: const SizedBox());
      final differentInstance = ZenmanageProvider(zenmanage: other, child: const SizedBox());

      expect(widget.updateShouldNotify(sameInstance), isFalse);
      expect(widget.updateShouldNotify(differentInstance), isTrue);
    });
  });
}
