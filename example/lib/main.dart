// The widgets here need Material, and package:material_ui isn't available on
// the older Flutter versions this package still supports.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:zenmanage/zenmanage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final zenmanage = Zenmanage(
    ConfigBuilder.create()
        .withEnvironmentToken('mob_your_environment_token_here')
        .withCache(InMemoryCache())
        .build(),
  );

  runApp(MyApp(zenmanage: zenmanage));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.zenmanage});

  final Zenmanage zenmanage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zenmanage Flutter Example',
      home: ZenmanageInitializer(
        zenmanage: zenmanage,
        loadingBuilder: (_) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        errorBuilder: (_, error, __) => Scaffold(
          body: Center(
            child: Text('Initialization failed: $error'),
          ),
        ),
        child: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final userContext = Context.user(
      id: 'user_123',
      name: 'Taylor',
      attributes: const {'plan': 'premium'},
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Zenmanage Flutter Example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('App-wide SDK initialization + widget-level flags'),
            const SizedBox(height: 16),
            ZenmanageFlagBuilder(
              flagKey: 'new-dashboard',
              defaultValue: false,
              context: userContext,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Text('Loading new-dashboard...');
                }
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                final enabled = snapshot.data?.isEnabled() ?? false;
                return Text(
                  enabled
                      ? 'new-dashboard is enabled'
                      : 'new-dashboard is disabled',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
