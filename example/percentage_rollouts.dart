/// Percentage rollouts example
///
/// This example demonstrates gradual feature rollouts using percentage-based targeting.

import 'package:zenmanage/zenmanage.dart';

Future<void> main() async {
  print('=== Percentage Rollouts ===\n');

  final zenmanage = Zenmanage(
    ConfigBuilder.create()
        .withEnvironmentToken('mob_your_environment_token_here')
        .build(),
  );

  try {
    // Example 1: 10% rollout to all users
    print('1. Gradual 10% Rollout\n');
    print('   Feature: new-recommendation-engine');
    print('   Rollout: 10% of all users\n');

    for (int i = 0; i < 5; i++) {
      final userId = 'user_$i';
      final userContext = Context.user(id: userId);

      final flag = await zenmanage.flags()
          .withContext(userContext)
          .single('new-recommendation-engine')
          .catchError((e) =>
              Flag(key: 'new-recommendation-engine', value: false, type: 'boolean'));

      print('   User $userId: ${flag.isEnabled() ? 'enabled' : 'disabled'}');
    }

    print('');

    // Example 2: Progressive rollout strategy
    print('2. Progressive Rollout Strategy\n');
    print('   Week 1: 1% rollout');
    print('   Week 2: 5% rollout');
    print('   Week 3: 25% rollout');
    print('   Week 4: 100% rollout (all users)\n');

    final rolloutPhases = [
      {'week': '1', 'percentage': 1, 'users': 100},
      {'week': '2', 'percentage': 5, 'users': 500},
      {'week': '3', 'percentage': 25, 'users': 2500},
      {'week': '4', 'percentage': 100, 'users': 10000},
    ];

    for (final phase in rolloutPhases) {
      print('   Week ${phase['week']}: ${phase['percentage']}% '
          '(${phase['users']} users)');
    }

    print('');

    // Example 3: Segment-based rollout
    print('3. Segment-Based Rollout\n');
    print('   Target: Premium users only (100% rollout)');
    print('   Target: Free users: 10% rollout\n');

    final segments = [
      {'name': 'premium', 'percentage': 100},
      {'name': 'professional', 'percentage': 50},
      {'name': 'free', 'percentage': 10},
    ];

    for (int i = 0; i < 3; i++) {
      final segment = segments[i];
      final userContext = Context.user(
        id: 'user_${segment['name']}_$i',
        attributes: {'plan': segment['name']},
      );

      final flag = await zenmanage.flags()
          .withContext(userContext)
          .single('advanced-analytics')
          .catchError((e) =>
              Flag(key: 'advanced-analytics', value: false, type: 'boolean'));

      print('   ${segment['name']}: ${flag.isEnabled() ? 'enabled' : 'disabled'} '
          '(${segment['percentage']}%)');
    }

    print('');

    // Example 4: Beta program (opt-in)
    print('4. Beta Program (Opt-In)\n');

    final betaUsers = ['user_john', 'user_jane', 'user_mike'];

    for (final userId in betaUsers) {
      final userContext = Context.user(
        id: userId,
        attributes: {'betaTester': true},
      );

      final flag = await zenmanage.flags()
          .withContext(userContext)
          .single('beta-experimental-ui')
          .catchError((e) =>
              Flag(key: 'beta-experimental-ui', value: false, type: 'boolean'));

      print('   $userId: ${flag.isEnabled() ? 'enrolled' : 'not enrolled'}');
    }

    print('');

    // Example 5: Canary deployment
    print('5. Canary Deployment\n');
    print('   Stage 1: 0.1% (canary - detect critical issues)');
    print('   Stage 2: 1% (small batch - verify performance)');
    print('   Stage 3: 10% (expanded - catch edge cases)');
    print('   Stage 4: 100% (full deployment - all users)\n');
  } catch (e) {
    print('   Error: $e');
  }

  print('Examples completed!');
}
