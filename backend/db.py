import os
from typing import Dict, List, Optional, Tuple
import pymysql
from pymysql.cursors import DictCursor

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_USER = os.getenv("DB_USER", "student")
DB_PASSWORD = os.getenv("DB_PASSWORD", "student")
DB_NAME = os.getenv("DB_NAME", "projects_db")
TABLE_NAME = "student_projects"

def get_connection(database: Optional[str] = DB_NAME):
    return pymysql.connect(host=DB_HOST, port=DB_PORT, user=DB_USER, password=DB_PASSWORD, database=database, cursorclass=DictCursor, connect_timeout=5, autocommit=True)

def check_database_connection() -> Tuple[bool, Optional[str]]:
    try:
        connection = get_connection()
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1 AS ok;")
            cursor.fetchone()
        connection.close()
        return True, None
    except Exception as error:
        return False, str(error)

def init_database() -> bool:
    try:
        connection = get_connection()
        with connection.cursor() as cursor:
            cursor.execute(f'''
                CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    first_name VARCHAR(100) NOT NULL,
                    last_name VARCHAR(100) NOT NULL,
                    index_number VARCHAR(50) NOT NULL,
                    project_title VARCHAR(255) NOT NULL,
                    project_area VARCHAR(120) NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            ''')
        connection.close()
        return True
    except Exception:
        return False

def create_project(first_name: str, last_name: str, index_number: str, project_title: str, project_area: str) -> Dict:
    connection = get_connection()
    with connection.cursor() as cursor:
        cursor.execute(f'''INSERT INTO {TABLE_NAME} (first_name, last_name, index_number, project_title, project_area) VALUES (%s, %s, %s, %s, %s);''', (first_name, last_name, index_number, project_title, project_area))
        project_id = cursor.lastrowid
    connection.close()
    return {"id": project_id, "firstName": first_name, "lastName": last_name, "indexNumber": index_number, "projectTitle": project_title, "projectArea": project_area}

def get_projects() -> List[Dict]:
    connection = get_connection()
    with connection.cursor() as cursor:
        cursor.execute(f'''SELECT id, first_name AS firstName, last_name AS lastName, index_number AS indexNumber, project_title AS projectTitle, project_area AS projectArea, created_at AS createdAt FROM {TABLE_NAME} ORDER BY created_at DESC;''')
        rows = cursor.fetchall()
    connection.close()
    for row in rows:
        if row.get("createdAt") is not None:
            row["createdAt"] = row["createdAt"].isoformat()
    return rows
