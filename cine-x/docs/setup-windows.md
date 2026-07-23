# Setup On Windows

1. Install Java 21 and ensure `JAVA_HOME` points to it.
2. Install Docker Desktop and start it.
3. Install Flutter stable and add `flutter\bin` to PATH.
4. Start PostgreSQL:

```powershell
docker compose up -d postgres
```

5. Run backend:

```powershell
cd backend
$env:JAVA_HOME="C:\Program Files\Java\jdk-21"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
mvn spring-boot:run
```

6. Run Flutter web:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=CINEX_API_BASE_URL=http://localhost:8080/api/v1
```

7. Run Android emulator:

```powershell
flutter run --dart-define=CINEX_API_BASE_URL=http://10.0.2.2:8080/api/v1
```
