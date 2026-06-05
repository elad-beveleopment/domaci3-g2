CREATE TABLE IF NOT EXISTS student_projects (
  id INT AUTO_INCREMENT PRIMARY KEY,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  index_number VARCHAR(50) NOT NULL,
  project_title VARCHAR(255) NOT NULL,
  project_area VARCHAR(120) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO student_projects (first_name, last_name, index_number, project_title, project_area)
VALUES ('Demo', 'Student', 'demo20240001', 'Demo cloud projekat', 'Docker Compose');
