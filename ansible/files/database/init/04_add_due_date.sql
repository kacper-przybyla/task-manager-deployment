-- Migration 003: Add due_date column to tasks table
ALTER TABLE tasks ADD COLUMN due_date TIMESTAMP;
CREATE INDEX idx_tasks_due_date ON tasks(due_date);

-- Sample tasks with due dates for testing
UPDATE tasks SET due_date = NOW() + INTERVAL '2 days' WHERE id = 1;
UPDATE tasks SET due_date = NOW() - INTERVAL '1 day' WHERE id = 2;  -- This will be overdue
