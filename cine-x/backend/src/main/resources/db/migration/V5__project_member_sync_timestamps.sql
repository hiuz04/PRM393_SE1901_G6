ALTER TABLE project_members
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP NULL,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP NULL;

UPDATE project_members
SET created_at = joined_at
WHERE created_at IS NULL;

UPDATE project_members
SET updated_at = joined_at
WHERE updated_at IS NULL;
