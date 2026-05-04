-- Migration 002: Add category column to tasks
-- Version: 1.2.0
-- Run: docker exec -i task-db psql -U postgres main-db < database/migrations/002_add_category.sql

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS category VARCHAR(50);
CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks(category);
