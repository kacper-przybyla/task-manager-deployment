-- Migration 001: Add priority column to tasks
-- Version: 1.1.0
-- Run: docker exec -i task-db psql -U postgres main-db < database/migrations/001_add_priority.sql

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS priority VARCHAR(20) DEFAULT 'medium';
UPDATE tasks SET priority = 'medium' WHERE priority IS NULL;
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);
