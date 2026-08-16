/// Defaults and error handling example
///
/// This example demonstrates using default values and handling missing flags gracefully.

import 'package:zenmanage/zenmanage.dart';

Future<void> main() async {
  print('=== Defaults and Error Handling ===\n');

  final zenmanage = Zenmanage(
    ConfigBuilder.create()
        .withEnvironmentToken('mob_your_environment_token_here')
        .build(),
  );

  try {
    // Example 1: Using singleOrDefault
    print('1. Using singleOrDefault\n');

    final defaultFlag = Flag(
      key: 'optional-feature',
      value: false,
      type: 'boolean',
    );

    final flag = await zenmanage.flags()
        .singleOrDefault('optional-feature', defaultFlag);

    print('   Flag value: ${flag.value}');
    print('   isEnabled: ${flag.isEnabled()}\n');

    // Example 2: Using catchError for custom handling
    print('2. Using catchError\n');

    final flag2 = await zenmanage.flags()
        .single('advanced-feature')
        .catchError((error) {
      print('   Flag not found, using default');
      return Flag(key: 'advanced-feature', value: true, type: 'boolean');
    });

    print('   Flag value: ${flag2.value}\n');

    // Example 3: Type-safe defaults
    print('3. Type-Safe Defaults\n');

    final stringDefault = Flag(
      key: 'ui-theme',
      value: 'light',
      type: 'string',
    );

    final themeFlag = await zenmanage.flags()
        .singleOrDefault('ui-theme', stringDefault);

    print('   Theme: ${themeFlag.asString()}');
    print('   Default used: true\n');

    // Example 4: Number defaults
    print('4. Number Defaults\n');

    final numberDefault = Flag(
      key: 'max-connections',
      value: 10,
      type: 'number',
    );

    final maxConnFlag = await zenmanage.flags()
        .singleOrDefault('max-connections', numberDefault);

    print('   Max connections: ${maxConnFlag.asInt()}\n');

    // Example 5: JSON/Map defaults
    print('5. JSON/Map Defaults\n');

    final configDefault = Flag(
      key: 'app-config',
      value: {
        'timeout': 30,
        'retries': 3,
        'enableLogging': true,
      },
      type: 'json',
    );

    final configFlag = await zenmanage.flags()
        .singleOrDefault('app-config', configDefault);

    final config = configFlag.asJson();
    print('   Config: $config\n');

    // Example 6: Batch flag retrieval with fallback
    print('6. Batch Retrieval with Fallback\n');

    try {
      final allFlags = await zenmanage.flags().all();
      print('   Retrieved ${allFlags.length} flags');
    } catch (e) {
      print('   Failed to retrieve flags: $e');
      print('   Using local defaults\n');

      final defaults = [
        Flag(key: 'feature-a', value: false, type: 'boolean'),
        Flag(key: 'feature-b', value: 'default', type: 'string'),
        Flag(key: 'feature-c', value: 100, type: 'number'),
      ];

      print('   Using ${defaults.length} local defaults');
      for (final flag in defaults) {
        print('      - ${flag.key}: ${flag.value}');
      }
    }

    print('');

    // Example 7: Safe type conversions
    print('7. Safe Type Conversions\n');

    final mixedFlag = Flag(
      key: 'mixed-value',
      value: '42',
      type: 'string',
    );

    try {
      final asNumber = mixedFlag.asNumber();
      print('   String "42" as number: $asNumber');
    } catch (e) {
      print('   Conversion failed: $e');
    }

    try {
      final asBool = mixedFlag.asBool();
      print('   String "42" as bool: $asBool\n');
    } catch (e) {
      print('   Conversion failed: $e\n');
    }
  } catch (e) {
    print('   Unexpected error: $e');
  }

  print('Examples completed!');
}
