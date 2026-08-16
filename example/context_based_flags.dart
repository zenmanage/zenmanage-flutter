/// Context-based flags example
///
/// This example demonstrates using context for personalized flag evaluation.

import 'package:zenmanage/zenmanage.dart';

Future<void> main() async {
  print('=== Context-Based Flags ===\n');

  final zenmanage = Zenmanage(
    ConfigBuilder.create()
        .withEnvironmentToken('mob_your_environment_token_here')
        .build(),
  );

  // Create user context
  final userContext = Context.user(
    id: 'user_123',
    name: 'John Doe',
    attributes: {
      'country': 'US',
      'plan': 'premium',
      'signupDate': '2023-01-15',
    },
  );

  print('User Context:\n');
  print('   ID: ${userContext.identifier}');
  print('   Name: ${userContext.name}');
  print('   Country: ${userContext.attributes['country']}');
  print('   Plan: ${userContext.attributes['plan']}\n');

  try {
    // Example 1: Beta program access
    print('1. Beta Program Access\n');

    final betaAccess = await zenmanage.flags()
        .withContext(userContext)
        .single('beta-program')
        .catchError((e) => Flag(
              key: 'beta-program',
              value: false,
              type: 'boolean',
            ));

    print('   Beta Access: ${betaAccess.isEnabled() ? 'Yes' : 'No'}\n');

    // Example 2: Feature rollout with context
    print('2. Premium Features\n');

    final premiumFeatures = await zenmanage.flags()
        .withContext(userContext)
        .single('premium-dashboard')
        .catchError((e) => Flag(
              key: 'premium-dashboard',
              value: false,
              type: 'boolean',
            ));

    print('   Premium Dashboard: ${premiumFeatures.isEnabled() ? 'Yes' : 'No'}\n');

    // Example 3: Multiple contexts
    print('3. Multiple Contexts (User + Organization)\n');

    final orgContext = Context.organization(
      id: 'org_456',
      name: 'Acme Corp',
      attributes: {
        'tier': 'enterprise',
        'employees': 500,
      },
    );

    final enterpriseFeature = await zenmanage.flags()
        .withContexts([userContext, orgContext])
        .single('enterprise-analytics')
        .catchError((e) => Flag(
              key: 'enterprise-analytics',
              value: false,
              type: 'boolean',
            ));

    print('   Enterprise Analytics: ${enterpriseFeature.isEnabled() ? 'Yes' : 'No'}\n');

    // Example 4: Feature variants for A/B testing
    print('4. Variant Assignment\n');

    final variant = await zenmanage.flags()
        .withContext(userContext)
        .single('checkout-flow')
        .catchError((e) =>
            Flag(key: 'checkout-flow', value: 'control', type: 'string'));

    print('   Assigned Variant: ${variant.asString()}\n');
  } catch (e) {
    print('   Error: $e');
  }

  print('Examples completed!');
}
