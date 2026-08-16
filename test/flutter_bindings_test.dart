import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';

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
    });
  });
}
