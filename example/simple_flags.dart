/// Simple flags example
///
/// This example demonstrates basic flag retrieval and type-safe value access.

import 'package:zenmanage/zenmanage.dart';

Future<void> main() async {
  print('=== Simple Flag Operations ===\n');

  // Initialize the SDK
  final zenmanage = Zenmanage(
    ConfigBuilder.create()
        .withEnvironmentToken('mob_your_environment_token_here')
        .build(),
  );

  try {
    // Example 1: Boolean flags
    print('1. Boolean Flags\n');

    final boolFlag =
        await zenmanage.flags().single('example-boolean-flag').catchError(
      (e) => Flag(key: 'example-boolean-flag', value: false, type: 'boolean'),
    );
    print('   Boolean Flag: ${boolFlag.asBool()}');

    final enabledFlag = await zenmanage.flags()
        .single('example-feature-enabled')
        .catchError(
          (e) =>
              Flag(key: 'example-feature-enabled', value: true, type: 'boolean'),
        );
    print('   Feature Enabled: ${enabledFlag.isEnabled() ? 'Yes' : 'No'}\n');

    // Example 2: String flags
    print('2. String Flags\n');

    final stringFlag = await zenmanage.flags()
        .single('example-string-flag')
        .catchError(
          (e) => Flag(
              key: 'example-string-flag', value: 'default-value', type: 'string'),
        );
    print('   String Flag: ${stringFlag.asString()}');

    final variantFlag = await zenmanage.flags()
        .single('example-variant-flag')
        .catchError(
          (e) =>
              Flag(key: 'example-variant-flag', value: 'control', type: 'string'),
        );
    print('   Variant Flag: ${variantFlag.asString()}\n');

    // Example 3: Number flags
    print('3. Number Flags\n');

    final numberFlag = await zenmanage.flags()
        .single('example-number-flag')
        .catchError(
          (e) => Flag(key: 'example-number-flag', value: 0, type: 'number'),
        );
    print('   Number Flag: ${numberFlag.asNumber()}');

    final limitFlag = await zenmanage.flags()
        .single('example-limit-flag')
        .catchError(
          (e) => Flag(key: 'example-limit-flag', value: 100, type: 'number'),
        );
    print('   Limit Flag: ${limitFlag.asNumber()}\n');

    // Example 4: Get all flags
    print('4. Retrieving All Flags\n');

    final flags = await zenmanage.flags().all();
    print('   Total flags: ${flags.length}\n');

    for (final flag in flags.take(5)) {
      final value = flag.isEnabled() ? 'enabled' : flag.getValue();
      print('   - ${flag.key} (${flag.type}): $value');
    }

    print('\n=== Type-Safe Access ===\n');

    final flag = await zenmanage.flags()
        .single('example-number-flag')
        .catchError(
          (e) => Flag(key: 'example-number-flag', value: 42, type: 'number'),
        );

    print('   getValue(): ${flag.getValue()}');
    print('   asString(): ${flag.asString()}');
    print('   asNumber(): ${flag.asNumber()}');
    print('   asBool(): ${flag.asBool()}');
    print('   isEnabled(): ${flag.isEnabled()}\n');
  } catch (e) {
    print('   Error: $e');
  }

  print('Examples completed!');
}
