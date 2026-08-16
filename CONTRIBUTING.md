# Contributing to Zenmanage Flutter SDK

Thank you for your interest in contributing to the Zenmanage Flutter SDK! We welcome contributions of all kinds - bug reports, feature requests, documentation improvements, and code contributions.

## Code of Conduct

This project adheres to the Contributor Covenant [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

- Dart 3.0+
- Flutter 3.0+
- Git

### Setup Development Environment

1. Fork and clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/zenmanage-flutter.git
cd zenmanage-flutter
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run tests to verify setup:
```bash
flutter test
```

4. Verify code quality:
```bash
flutter analyze
dart format --line-length=80 lib test example
```

## Development Workflow

### Creating a Feature Branch

```bash
git checkout -b feature/your-feature-name
```

Branch naming conventions:
- `feature/` for new features
- `fix/` for bug fixes
- `docs/` for documentation
- `test/` for test improvements
- `refactor/` for code refactoring

### Making Changes

1. Make your changes in focused commits
2. Write or update tests for your changes
3. Keep commits atomic and descriptive
4. Reference issues in commit messages: `Fix #123: Description`

### Code Style

This project follows the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).

Format code before committing:
```bash
dart format --line-length=80 lib test example
```

### Testing

All code must have tests. Coverage goal: 90%+

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/flag_test.dart

# Watch mode (re-run on changes)
flutter test --watch
```

### Documentation

- Add doc comments (`/// `) to all public APIs
- Update README.md for user-facing changes
- Update CHANGELOG.md with your changes
- Include examples for new features

Example doc comment:
```dart
/// Evaluates a single flag by key
///
/// Fetches rules from the API if not cached, then evaluates locally.
/// Throws [FlagNotFoundException] if the flag doesn't exist.
/// Throws [ApiException] if the API request fails and no cached rules exist.
///
/// Example:
/// ```dart
/// final flag = await zenmanage.flags().single('new-dashboard');
/// if (flag.isEnabled()) {
///   showNewDashboard();
/// }
/// ```
Future<Flag> single(String flagKey, {dynamic defaultValue}) async { }
```

## Submitting Changes

### Before You Submit

1. Run full test suite:
```bash
flutter test
```

2. Check code quality:
```bash
flutter analyze
dart format --line-length=80 --check lib test example
```

3. Run coverage check:
```bash
flutter test --coverage
```

4. Update documentation and CHANGELOG.md

5. Ensure no merge conflicts

### Create a Pull Request

1. Push your branch:
```bash
git push origin feature/your-feature-name
```

2. Go to GitHub and open a Pull Request
3. Fill out the PR template:
   - Describe what your PR does
   - Link related issues
   - List breaking changes (if any)
   - Add screenshots/examples (if applicable)

4. Address review feedback
5. Once approved, it will be merged

## Reporting Issues

### Bug Reports

Include:
- SDK version
- Flutter/Dart version
- Minimal reproduction case
- Expected vs actual behavior
- Error messages and stack traces

### Feature Requests

Include:
- Use case and motivation
- Proposed API/behavior
- Examples of how it would be used
- Alternative solutions you considered

## Project Structure

```
lib/
  zenmanage.dart                 # Main entry point
  src/
    zenmanage.dart              # Zenmanage class
    api_client.dart             # API client
    rule_engine.dart            # Rule evaluation
    config/
      config.dart               # Configuration model
      config_builder.dart       # Configuration builder
    context/
      context.dart              # Context model
    flag/
      flag.dart                 # Flag model
      flag_manager.dart         # Flag manager
    cache/
      cache.dart                # Cache interface
      in_memory_cache.dart      # In-memory cache
      null_cache.dart           # No-op cache
      shared_preferences_cache.dart  # SharedPreferences cache
    exceptions/
      exceptions.dart           # Exception classes

test/
  config_test.dart              # Configuration tests
  flag_test.dart                # Flag model tests
  context_test.dart             # Context model tests
  cache_test.dart               # Cache tests
  exceptions_test.dart          # Exception tests

example/
  simple_flags.dart             # Basic usage
  context_based_flags.dart      # Context usage
  ab_testing.dart               # A/B testing
  percentage_rollouts.dart      # Gradual rollouts
  caching.dart                  # Caching strategies
  defaults.dart                 # Defaults and error handling
```

## Coding Guidelines

### Naming Conventions

- Classes: PascalCase (`Flag`, `FlagManager`)
- Methods: camelCase (`single()`, `withContext()`)
- Constants: UPPER_CASE (`CACHE_TTL`)
- Private members: Leading underscore (`_cache`)

### Error Handling

- Use typed exceptions from `exceptions.dart`
- Provide meaningful error messages
- Don't swallow exceptions silently

### Async/Await

- Use `async`/`await` instead of callbacks
- Prefer `Future<T>` over `Future.delayed()`
- Handle errors properly

### Comments

- Use `///` for public API documentation
- Use `//` for inline comments
- Keep comments up-to-date with code

## Pull Request Process

1. Update CHANGELOG.md
2. Update documentation
3. Add tests (coverage goal: 90%+)
4. Run `flutter test`
5. Run `flutter analyze`
6. Format code: `dart format --line-length=80 lib test example`
7. Request review
8. Address feedback
9. Merge once approved

## Release Process

See [docs/PUBLISHING.md](docs/PUBLISHING.md) for the full release process.

## Questions?

- 📚 Check [README.md](README.md) for usage examples
- 💬 Open a GitHub Discussion
- 🐛 Open an Issue
- 📧 Contact Zenmanage support

## License

By contributing, you agree that your contributions will be licensed under the same MIT License that covers the project.

## Recognition

Contributors will be:
- Listed in CHANGELOG.md
- Thanked in release notes
- Credited in documentation

Thank you for contributing! 🙏
