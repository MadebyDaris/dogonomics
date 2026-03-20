# dogonomics_frontend

## API Security Configuration

Provide backend URL and API key at build/run time:

```bash
flutter run --dart-define=API_URL=https://your-api-domain --dart-define=API_KEY=replace_with_long_random_key
```

For release builds, use the same `--dart-define` values in your CI/CD pipeline.
