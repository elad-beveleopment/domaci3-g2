import os
from flask import Flask, request, jsonify
from flask_cors import CORS
from db import init_database, get_projects, create_project, check_database_connection

app = Flask(__name__)
CORS(app)

PORT = int(os.getenv("PORT", "3000"))

@app.before_request
def before_request():
    init_database()

@app.route("/health", methods=["GET"])
def health():
    db_available, db_error = check_database_connection()
    return jsonify({
        "status": "ok",
        "service": "student-project-tracker-backend",
        "databaseAvailable": db_available,
        "databaseError": db_error
    })

@app.route("/projects", methods=["GET"])
def list_projects():
    db_available, db_error = check_database_connection()
    if not db_available:
        return jsonify({"databaseAvailable": False, "count": 0, "projects": [], "error": db_error}), 503
    projects = get_projects()
    return jsonify({"databaseAvailable": True, "count": len(projects), "projects": projects})

@app.route("/projects", methods=["POST"])
def add_project():
    data = request.get_json(silent=True) or {}
    required_fields = ["firstName", "lastName", "indexNumber", "projectTitle", "projectArea"]
    missing = [field for field in required_fields if not str(data.get(field, "")).strip()]
    if missing:
        return jsonify({"success": False, "message": "Nedostaju obavezna polja.", "missingFields": missing}), 400
    db_available, db_error = check_database_connection()
    if not db_available:
        return jsonify({"success": False, "message": "Baza nije dostupna.", "error": db_error}), 503
    project = create_project(
        first_name=data["firstName"].strip(),
        last_name=data["lastName"].strip(),
        index_number=data["indexNumber"].strip(),
        project_title=data["projectTitle"].strip(),
        project_area=data["projectArea"].strip()
    )
    return jsonify({"success": True, "message": "Projekat je uspešno dodat.", "project": project}), 201

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)
