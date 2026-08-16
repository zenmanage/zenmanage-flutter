/// A/B Testing example
///
/// This example demonstrates using Zenmanage for A/B testing and experimentation.

import 'package:zenmanage/zenmanage.dart';

Future<void> main() async {
  print('=== A/B Testing ===\n');

  final zenmanage = Zenmanage(
    ConfigBuilder.create()
        .withEnvironmentToken('mob_your_environment_token_here')
        .build(),
  );

  try {
    // Example 1: Checkout flow A/B test
    print('1. Checkout Flow Variant Assignment\n');

    final userId = 'user_789';
    final userContext = Context.user(
      id: userId,
      name: 'Alice Smith',
      attributes: {'plan': 'premium'},
    );

    final checkoutVariant = await zenmanage.flags()
        .withContext(userContext)
        .single('checkout-flow')
        .catchError((e) =>
            Flag(key: 'checkout-flow', value: 'control', type: 'string'));

    final variant = checkoutVariant.asString();
    print('   User ID: $userId');
    print('   Assigned Variant: $variant\n');

    if (variant == 'control') {
      print('   Using standard checkout experience');
    } else if (variant == 'test_v1') {
      print('   Using optimized checkout (v1)');
    } else if (variant == 'test_v2') {
      print('   Using optimized checkout (v2)');
    }

    print();

    // Example 2: Conversion tracking for A/B test
    print('2. Tracking Test Results\n');

    print('   Variant: $variant');
    print('   Checkout Completed: true');
    print('   Time to Complete: 2.3 seconds');
    print('   Revenue: \$49.99\n');

    // Example 3: Multiple concurrent tests
    print('3. Multiple Tests Per User\n');

    final tests = [
      'checkout-flow',
      'dashboard-redesign',
      'recommendation-engine',
    ];

    for (final test in tests) {
      try {
        final testFlag = await zenmanage.flags()
            .withContext(userContext)
            .single(test)
            .catchError((e) => Flag(key: test, value: 'control', type: 'string'));

        print('   $test: ${testFlag.asString()}');
      } catch (e) {
        print('   $test: not found');
      }
    }

    print('\n4. Impact Analysis\n');
    print('   - Control Group: 5000 users');
    print('   - Test Group: 5000 users');
    print('   - Control Conversion Rate: 3.2%');
    print('   - Test Conversion Rate: 4.1%');
    print('   - Improvement: +28%');
    print('   - Confidence: 99.5%\n');
  } catch (e) {
    print('   Error: $e');
  }

  print('Examples completed!');
}
