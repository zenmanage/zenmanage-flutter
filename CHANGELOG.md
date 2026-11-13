# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- `single()` now returns the `defaultValue` you pass when the rules can't be loaded (for example an invalid key or no network) and nothing is cached. In 1.0.0 it threw an `ApiException` instead, even though the 1.0.0 notes said it wouldn't. Without a `defaultValue`, `single()` still throws.
- `zenmanage.flags()` now returns a new `FlagManager` on every call, so a context set with `withContext()` or `withContexts()` applies to that read only. Before, every call returned the same manager: a context stuck until you called `clearContext()`, and two reads running at once with different contexts could evaluate (and report usage) for each other's context. All managers share one set of fetched rules, so this adds no extra requests. `ZenmanageFlagBuilder` no longer has this problem either. `initialize(contexts: ...)` now uses its contexts for the startup fetch only; it no longer sets them on later reads.

## 1.0.0

Released on 2026-11-11. First public release.

### Added
- Flag client for Dart and Flutter apps. `Zenmanage.initialize()` fetches the rules once, and flags are then evaluated locally with `flags().single()`, `singleOrDefault()` and `all()`.
- Flutter bindings for app-wide initialization and widget-level use: `ZenmanageProvider`, `ZenmanageInitializer` and `ZenmanageFlagBuilder`.
- Typed value accessors: `asBool()`, `asString()`, `asNumber()`, `asInt()`, `asDouble()`, `asJson()` and `asList()`. Calling the "wrong" accessor never throws; each one falls back to a safe zero value, the same as the other Zenmanage SDKs.
- `boolean`, `string`, `number` and `json` flags. A `Map` or `List` default passed to `single()` produces a `json` flag. A flag with a type this release doesn't recognize falls back to your default instead of failing the whole rules payload.
- Local rule evaluation with user, organization and account contexts and custom attributes, percentage rollouts, and A/B variants. Rules are evaluated from the lowest `position` to the highest and the first match wins.
- Three rule caches: `InMemoryCache` (default), `SharedPreferencesCache` (persists rules on the device) and `NullCache`.
- `single()` falls back to the default you provide, instead of throwing, when the rules can't be loaded (for example an invalid key or no network).
- Failed rules fetches are retried: up to 3 attempts with 100ms then 200ms of backoff, the same as the other Zenmanage SDKs. A rejected token (HTTP 401/403) is not retried.
- `ConfigBuilder.withRequestTimeout(Duration)` sets how long a rules request may wait. It defaults to 10 seconds; usage reports are capped at 5 seconds.
- `ConfigBuilder.withLogger(ZenmanageLogger)` routes SDK diagnostics (fetch attempts, retries, failures) to your own logging. Nothing is logged by default.
- `zenmanageSdkVersion`, the version reported to the API in the `X-ZEN-CLIENT-AGENT` header (`zenmanage-flutter/<version>`).
- Typed exceptions: `ConfigurationException`, `ApiException`, `FlagNotFoundException`, `TypeConversionException`, `RuleEvaluationException` and `CacheException`.
- Examples for common use cases, including a runnable Flutter example app in `example/`.

### Security
- Environment tokens must be a mobile key (`mob_...`) or a client key (`cli_...`; use this one for Flutter web, which has no mobile key). Server keys (`srv_...`) are rejected when the configuration is created: a server key bundled into an app can be extracted by anyone.
- All API communication uses HTTPS.
