# Mobile test runbook (physical phone)

This runbook validates that the app network layer is healthy on a real device.

## 1) Prerequisites

- Phone connected with USB debugging enabled
- Device visible in Flutter:

```bash
flutter devices
```

- Dependencies installed:

```bash
flutter pub get
```

- Optional API keys configured in `.env` (FMP, AI providers, etc.)

## 2) Run smoke integration tests on phone

Use your real device id from `flutter devices`.

```bash
flutter test integration_test/mobile_smoke_test.dart -d <DEVICE_ID>
```

Expected result:
- Yahoo endpoint test passes
- Fear & Greed test passes
- FMP test passes if `FMP_API_KEY` is configured (auto-skipped if missing)

## 3) Run the app on phone (manual flow)

```bash
flutter run -d <DEVICE_ID>
```

Then validate in app:
- Market overview loads prices and charts
- Analysis for `AAPL` and `MSFT` returns data
- News list loads
- Sentiment widget loads
- No frozen loaders longer than 15s

## 4) Live logs while testing

```bash
flutter logs
```

If needed, for Android only:

```bash
adb logcat | findstr /i "SigmaService OpenInsider FMP Error Exception"
```

## 5) Success criteria

- App starts without startup crash
- Data appears on core screens within a few seconds
- Integration smoke tests pass on physical device
- No repeated network exceptions in logs

## 6) If a test fails

- Check internet connection and DNS on phone
- Verify `.env` keys
- Retry after 1-2 minutes (third-party APIs can throttle)
- Capture logs and failing endpoint to debug quickly
