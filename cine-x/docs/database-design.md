# Database Design

Database: `cinexdb`, PostgreSQL compatible.

## Tables

- `users`: account, BCrypt password hash, system role, enabled flag, timestamps.
- `projects`: owner FK, title, genre, dates, poster, status, soft delete flag, optimistic version.
- `project_members`: composite PK `(project_id, user_id)`, per-project role.
- `acts`: project FK, sequence order unique in project.
- `characters`: table name remains `characters`; Java entity is `StoryCharacter`.
- `locations`: setting type `INT/EXT`, time `DAY/NIGHT`.
- `scenes`: belongs to one project, one act and one location, unique `scene_number` in project.
- `scene_characters`: many-to-many join table.

## Integrity Rules

- `scene_number >= 1`, `sequence_order >= 1`.
- Scene create/update verifies act, location and characters belong to the same project.
- Deleting a location used by a scene is rejected in service.
- Deleting a character removes `scene_characters` links but keeps scenes.
- Projects use soft delete with `deleted = 1`; default list excludes deleted projects.
- Last `OWNER` cannot be removed or downgraded.

## Indexes

Indexes exist on project owner, member user, project-scoped child tables, scene act/location/status and scene character reverse lookup. See `database/schema.sql` and `backend/src/main/resources/db/migration/V1__init_schema.sql`.

## Cascade And Restrict

- `scene_characters.scene_id` cascades when a scene is deleted.
- `scene_characters.character_id` cascades when a character is deleted.
- Act and location deletion are service-restricted if scenes exist.
