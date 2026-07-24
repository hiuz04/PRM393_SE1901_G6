# Testing Guide

## Backend

```powershell
cd backend
$env:JAVA_HOME="C:\Program Files\Java\jdk-21"
mvn test
mvn package
```

Covered tests include:

- Password validation.
- JWT required claims.
- Dashboard/analytics progress with zero scenes and done scenes.
- Scene cross-project validation.
- Location delete restriction.
- Last owner protection.

## Frontend

```powershell
cd frontend
flutter analyze
flutter test
```

Covered tests include:

- Model JSON parsing.
- Provider loading/success state.
- Login validation widget.
- Project launcher empty state.
- Responsive workspace navigation.
