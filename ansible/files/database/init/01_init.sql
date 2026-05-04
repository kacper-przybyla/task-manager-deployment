-- Create database if not exists (this runs automatically in postgres image)
CREATE TABLE IF NOT EXISTS tasks (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    completed BOOLEAN DEFAULT FALSE,
    priority VARCHAR(20) DEFAULT 'medium',
    category VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create index on completed status for faster filtering
CREATE INDEX IF NOT EXISTS idx_tasks_completed ON tasks(completed);

-- Create index on created_at for sorting
CREATE INDEX IF NOT EXISTS idx_tasks_created_at ON tasks(created_at DESC);

-- Create index on priority for filtering
CREATE INDEX IF NOT EXISTS idx_tasks_priority ON tasks(priority);

-- Create index on category for filtering
CREATE INDEX IF NOT EXISTS idx_tasks_category ON tasks(category);

-- Insert some sample data for development
INSERT INTO tasks (title, description, completed, priority, category, created_at)
VALUES
    ('Welcome to Task Manager', 'This is your first task!', false, 'low', 'other', NOW()),
    ('Complete Docker exercise', 'Finish Exercise 10 with multi-tier architecture', false, 'high', 'work', NOW()),
    ('Learn docker-compose', 'Master multi-container orchestration', true, 'medium', 'work', NOW()),
    ('Buy groceries', 'Milk, eggs, bread', false, 'medium', 'shopping', NOW()),
    ('Morning run', '5km before work', false, 'low', 'health', NOW())
ON CONFLICT DO NOTHING;
