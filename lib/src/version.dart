/// SDK version constant
library;

/// The SDK version reported to the API in the `X-ZEN-CLIENT-AGENT` header
/// (as `zenmanage-flutter/<version>`).
///
/// This is the single source of truth for the version at runtime. A test
/// fails if it disagrees with `pubspec.yaml` or the top entry of
/// `CHANGELOG.md`, so bump all three together when releasing.
const String zenmanageSdkVersion = '1.0.0';
