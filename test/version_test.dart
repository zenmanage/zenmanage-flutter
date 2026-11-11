import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zenmanage/zenmanage.dart';

void main() {
  test('the runtime version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml has no version line');
    expect(zenmanageSdkVersion, equals(match!.group(1)));
  });

  test('the runtime version matches the newest released CHANGELOG entry', () {
    final changelog = File('CHANGELOG.md').readAsStringSync();
    // Skip "## [Unreleased]"; take the first "## [x.y.z]" heading.
    final match = RegExp(r'^## \[(\d+\.\d+\.\d+)\]', multiLine: true).firstMatch(changelog);

    expect(match, isNotNull, reason: 'CHANGELOG.md has no released version heading');
    expect(zenmanageSdkVersion, equals(match!.group(1)));
  });

  test('the config and builder default to the runtime version', () {
    final config = ConfigBuilder.create().withEnvironmentToken('mob_test').build();

    expect(config.sdkVersion, equals(zenmanageSdkVersion));
  });
}
