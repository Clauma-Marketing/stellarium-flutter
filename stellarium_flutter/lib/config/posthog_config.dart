// PostHog compile-time configuration.
// Override at build time with --dart-define=POSTHOG_API_KEY=... --dart-define=POSTHOG_HOST=...
const String posthogApiKey = String.fromEnvironment(
  'POSTHOG_API_KEY',
  defaultValue: 'phc_wFffqJgLFUZgjkjG7KpkG7yiVvQ33Stt6zMJnEh8mPzt',
);
const String posthogHost = String.fromEnvironment(
  'POSTHOG_HOST',
  defaultValue: 'https://eu.i.posthog.com',
);
