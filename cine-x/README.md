# CINE-X

CINE-X is a full-stack screenplay idea, scene and production planning MVP. The backend is the source of truth; Flutter stores only the access token and UI preferences.

## Structure

```text
cine-x/
  backend/          Spring Boot 3.3 API
  frontend/         Flutter Material 3 client
  database/         PostgreSQL create/schema/seed scripts
  docs/             Architecture, setup, testing and API notes
  docker-compose.yml
```

## Technology

- Java 21.0.9, Spring Boot 3.3.0, Maven 3.9.16
- Spring Web, Data JPA, Validation, Security, JWT, Flyway, Springdoc Swagger, OpenPDF
- PostgreSQL 16 Docker image, official PostgreSQL JDBC driver
- Flutter local SDK at `C:\Users\ADMIN\flutter`, Dart null safety, Provider/ChangeNotifier, `http`, `flutter_secure_storage`, `image_picker`, `fl_chart`, `pdf`, `printing`

## Run PostgreSQL

```powershell
cd "D:\1_PRM393_Hoc lieu\PRM393_SE1901_G6\cine-x"
docker compose up -d postgres
```

The default local database is `cinexdb` with user `cinex` and password `cinex_local_2026`. Change these in `.env` for your machine.

## Run Backend

```powershell
cd backend
$env:JAVA_HOME="C:\Program Files\Java\jdk-21"
$env:Path="$env:JAVA_HOME\bin;$env:Path"
mvn spring-boot:run
```

If Maven is not in PATH on this machine, this cached executable worked during verification:

```powershell
& "C:\Users\ADMIN\.m2\wrapper\dists\apache-maven-3.9.16-bin\5grr65jo27hi51sujmtcldfovl\apache-maven-3.9.16\bin\mvn.cmd" spring-boot:run
```

Or use the included helper:

```powershell
.\run-dev.ps1
```

Backend URL: `http://localhost:8080`  
API prefix: `http://localhost:8080/api/v1`  
Swagger: `http://localhost:8080/swagger-ui.html`

## Run Flutter

```powershell
cd frontend
flutter pub get
flutter run -d chrome --dart-define=CINEX_API_BASE_URL=http://localhost:8080/api/v1
```

For Android emulator:

```powershell
flutter run --dart-define=CINEX_API_BASE_URL=http://10.0.2.2:8080/api/v1
```

## Demo Accounts

- `owner@cinex.local` / `CineX@123`
- `writer@cinex.local` / `CineX@123`

## Test And Build

Backend:

```powershell
cd backend
mvn test
mvn package
```

Frontend:

```powershell
cd frontend
flutter analyze
flutter test
```

## Reset Database

```powershell
docker compose down -v
docker compose up -d postgres
cd backend
mvn spring-boot:run
```

Flyway recreates the schema and seed data on the next backend startup.

## Current Limits

- Backend tests use focused unit tests plus H2 PostgreSQL-mode test profile. Production runtime remains PostgreSQL with Flyway migrations.
- Docker PostgreSQL container was not started in this environment unless Docker daemon is running, but `docker compose config` can validate the compose file.

Important review files: `backend/pom.xml`, `backend/src/main/java/com/cinex`, `backend/src/main/resources/db/migration`, `frontend/lib`, `database/schema.sql`, `docs/cinex-api.http`.
