/// Environment token validation
library;

import '../exceptions/exceptions.dart';

/// Checks that [token] is a key this SDK may use, and throws
/// [ConfigurationException] otherwise.
///
/// Flutter apps ship to devices (and the browser), so only a mobile key
/// (`mob_...`) or a client key (`cli_...`) is accepted. A server key
/// (`srv_...`) is rejected: a secret bundled into an app can be extracted by
/// anyone who downloads it.
void validateEnvironmentToken(String token) {
  if (token.startsWith('srv_')) {
    throw ConfigurationException(
      'Server keys (srv_) cannot be used in a Flutter app: a key bundled into '
      'an app can be extracted by anyone. Use a mobile key (mob_) or, for '
      'Flutter web, a client key (cli_). Get your token from https://zenmanage.com',
    );
  }

  if (!token.startsWith('mob_') && !token.startsWith('cli_')) {
    throw ConfigurationException(
      'Invalid environment token. Expected a mobile key (mob_) or a client key '
      '(cli_). Get your token from https://zenmanage.com',
    );
  }
}
