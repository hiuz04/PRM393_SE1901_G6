# CINE-X Flutter

Flutter Material 3 client for CINE-X.

```powershell
flutter pub get
flutter run -d chrome --dart-define=CINEX_API_BASE_URL=http://localhost:8080/api/v1
flutter analyze
flutter test
```

Android emulator:

```powershell
flutter run --dart-define=CINEX_API_BASE_URL=http://10.0.2.2:8080/api/v1
```
