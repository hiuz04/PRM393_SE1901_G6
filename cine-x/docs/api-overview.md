# API Overview

Base URL: `http://localhost:8080/api/v1`

## Health

- `GET /health`

## Auth

- `POST /auth/register`
- `POST /auth/login`
- `GET /auth/me`

## Projects

- `GET /projects?search=&status=&page=&size=&sort=`
- `POST /projects`
- `GET /projects/{projectId}`
- `PUT /projects/{projectId}`
- `DELETE /projects/{projectId}`
- `POST /projects/{projectId}/restore`
- `GET /projects/{projectId}/dashboard`

## Members

- `GET /projects/{projectId}/members`
- `POST /projects/{projectId}/members`
- `PUT /projects/{projectId}/members/{userId}`
- `DELETE /projects/{projectId}/members/{userId}`

## Story Resources

- Acts: `/projects/{projectId}/acts`
- Characters: `/projects/{projectId}/characters`
- Character image upload: `POST /projects/{projectId}/characters/{characterId}/image`
- Locations: `/projects/{projectId}/locations`
- Scenes: `/projects/{projectId}/scenes`
- Scene status: `PATCH /projects/{projectId}/scenes/{sceneId}/status`

Scene filters support `search`, `actId`, `locationId`, `characterId`, `settingType`, `timeOfDay`, `status`, `page`, `size`, `sort` and combine with AND logic.

## Reporting

- `GET /projects/{projectId}/planner/by-location`
- `GET /projects/{projectId}/analytics/summary`
- `GET /projects/{projectId}/analytics/character-frequency`
- `GET /projects/{projectId}/analytics/location-setting-ratio`
- `GET /projects/{projectId}/analytics/scene-status-ratio`
- `GET /projects/{projectId}/export/pdf`
