# Publishing Guide for Zenmanage Flutter SDK

This guide covers publishing the Zenmanage Flutter SDK to pub.dev and other package repositories.

## Prerequisites

- Dart SDK 3.0+
- Flutter SDK 3.0+
- Git
- pub.dev account (at https://pub.dev)
- GitHub account (for publishing source)

## Pre-Publishing Checklist

### 1. Code Quality

```bash
# Run all quality checks
flutter analyze

# Run tests with coverage
flutter test --coverage

# Check code style
dart format --line-length=80 lib test example

# Verify tests pass
flutter test
```

Expected coverage: 90%+ for publishing (enforced in CI)

### 2. Documentation

Ensure all files are present and complete:

- [ ] `README.md` - Main package documentation
- [ ] `CHANGELOG.md` - Version history and changes
- [ ] `CONTRIBUTING.md` - Contribution guidelines
- [ ] `LICENSE` - MIT license file
- [ ] `example/` - Example code
- [ ] Inline code documentation - `/// ` doc comments
- [ ] API reference - Documented public APIs

### 3. Version Management

Update version in `pubspec.yaml`:

```yaml
version: 1.0.0  # Use semantic versioning (MAJOR.MINOR.PATCH)
```

### 4. CHANGELOG Update

Update `CHANGELOG.md`:

```markdown
## 1.0.0

### Features
- Initial public release
- Flag client for Dart and Flutter applications
- Async initialization and local caching
- Type-safe value accessors
- Support for contexts and personalization
- Multiple cache backends (InMemory, SharedPreferences, Null)
- Comprehensive error handling
- Full test coverage

### Breaking Changes
None

### Bug Fixes
None

### Deprecations
None
```

## Publishing to pub.dev

### Step 1: Setup Pub Credentials

First time only - authenticate with pub.dev:

```bash
pub login
```

This creates/updates `~/.pub-cache/credentials.json`

### Step 2: Validate Package

```bash
pub publish --dry-run
```

This verifies the package without publishing. Fix any errors reported.

### Step 3: Publish Package

```bash
pub publish
```

Confirm when prompted. The package will be published to pub.dev immediately.

### Step 4: Verify Publication

After ~2-3 minutes, check:

```bash
# View package on pub.dev
open https://pub.dev/packages/zenmanage

# Or check from command line
pub search zenmanage
```

## Publishing to Other Repositories

### GitHub Releases

1. Tag the release:
```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

2. Create GitHub Release:
   - Go to GitHub Releases page
   - Click "Create a new release"
   - Upload artifacts (optional)
   - Copy changelog into description

### GitHub Packages

1. Create `.github/workflows/publish.yml`:

```yaml
name: Publish to GitHub Packages

on:
  release:
    types: [created]

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v3
      
      - uses: dart-lang/setup-dart@v1
        with:
          sdk: stable
      
      - name: Install dependencies
        run: dart pub get
      
      - name: Run tests
        run: dart test
      
      - name: Publish to GitHub Packages
        run: dart pub publish
```

2. Configure `pubspec.yaml`:

```yaml
publish_to: 'https://pub.dev'  # or GitHub Packages
```

## Post-Publishing Steps

### 1. Update Documentation

- [ ] Update README.md with pub.dev link
- [ ] Update installation instructions
- [ ] Update API documentation links
- [ ] Add package shield badge:

```markdown
[![pub package](https://img.shields.io/pub/v/zenmanage.svg)](https://pub.dev/packages/zenmanage)
```

### 2. Announce Release

- [ ] Post on GitHub Releases
- [ ] Update Zenmanage website
- [ ] Notify stakeholders
- [ ] Share in documentation

### 3. Monitor & Support

- [ ] Watch pub.dev page for feedback
- [ ] Monitor GitHub issues
- [ ] Address bug reports
- [ ] Help with setup questions

## Versioning Strategy

Use Semantic Versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes (e.g., API changes)
- **MINOR**: New features (e.g., new cache backend)
- **PATCH**: Bug fixes (e.g., type conversion fix)

Examples:
- 1.0.0 → 1.0.1 (patch - bug fix)
- 1.0.0 → 1.1.0 (minor - new feature)
- 1.0.0 → 2.0.0 (major - breaking change)

## Breaking Changes

When making breaking changes:

1. Update version to next MAJOR
2. Create migration guide
3. Announce prominently in CHANGELOG
4. Update documentation
5. Provide deprecation period for old APIs if possible

Example:

```markdown
## 2.0.0

### Breaking Changes
- Renamed `FlagManager.evaluate()` to `FlagManager.single()`
- Removed deprecated `Config.create()` method
- Cache implementations now require initialization

### Migration Guide
See [UPGRADING.md](UPGRADING.md) for detailed migration instructions.
```

## Maintenance

### Regular Updates

- [ ] Keep dependencies updated: `flutter pub upgrade`
- [ ] Run tests monthly
- [ ] Address security issues promptly
- [ ] Monitor Flutter/Dart updates

### Dependency Management

```bash
# Check for outdated dependencies
flutter pub outdated

# Update dependencies
flutter pub upgrade

# Update specific dependency
flutter pub upgrade package_name
```

## Example Release Workflow

1. Create release branch:
   ```bash
   git checkout -b release/v1.0.0
   ```

2. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.0
   ```

3. Update `CHANGELOG.md` with release notes

4. Commit changes:
   ```bash
   git commit -m "Release v1.0.0"
   ```

5. Create pull request, review, and merge

6. Tag release:
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

7. Run quality checks:
   ```bash
   flutter analyze
   flutter test --coverage
   pub publish --dry-run
   ```

8. Publish to pub.dev:
   ```bash
   pub publish
   ```

9. Verify at pub.dev:
   ```bash
   open https://pub.dev/packages/zenmanage
   ```

10. Create GitHub Release with changelog

## Troubleshooting

### "Package name is not a valid Dart identifier"

Ensure package name in `pubspec.yaml` matches: `^[a-z][a-z0-9_]*$`

### "Package violates publisher policy"

Check that:
- All public APIs have documentation
- Code follows Dart style guide
- License file exists
- No private dependencies

### "Authorization failed"

Run `pub login` again to refresh credentials

### "Version already exists"

Version already published. Increment version number.

### Tests fail during publish

Run `pub publish --dry-run` first to catch issues:

```bash
pub publish --dry-run
```

## Advanced Topics

### Retiring Old Versions

To deprecate a version (don't use for new installs):

```bash
pub deprecated 0.9.0
```

Users still on that version get a warning.

### Conditional Dependencies

For Flutter-only features:

```yaml
dependencies:
  flutter:
    sdk: flutter
  shared_preferences: ^2.2.0
```

### Platform-Specific Code

Structure for platform-specific code:

```
lib/
  src/
    cache/
      shared_preferences_cache.dart  # Flutter-specific
```

## Resources

- [Pub.dev Publishing Guide](https://dart.dev/tools/pub/publishing)
- [Semantic Versioning](https://semver.org/)
- [Dart Code Style](https://dart.dev/guides/language/effective-dart/style)
- [Zenmanage Docs](https://zenmanage.com/docs)

## Support

For publishing issues:
- Check pub.dev publishing guide
- Open GitHub issue with [publishing] tag
- Contact Zenmanage support

## Checklist for Release

- [ ] Code reviewed and approved
- [ ] All tests passing with 90%+ coverage
- [ ] No linter warnings: `flutter analyze`
- [ ] Documentation complete and accurate
- [ ] CHANGELOG updated
- [ ] Version updated in pubspec.yaml
- [ ] No breaking changes (or properly documented)
- [ ] Dry-run successful: `pub publish --dry-run`
- [ ] Published to pub.dev: `pub publish`
- [ ] GitHub Release created
- [ ] Announcements posted
- [ ] README updated with pub.dev link
