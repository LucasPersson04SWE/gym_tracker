from flask import Flask, render_template, request, redirect, url_for
import mysql.connector

app = Flask(__name__)

def get_connection():
    return mysql.connector.connect(
        host="localhost",
        user="root",
        password="siggekatt123",
        database="gym_tracker"
    )

@app.route("/")
def index():
    return render_template("index.html")


# =========================
# USERS
# =========================
@app.route("/users", methods=["GET", "POST"])
def users():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    if request.method == "POST":
        name = request.form["name"]
        email = request.form["email"]
        age = request.form["age"]

        cursor.execute(
            "INSERT INTO Users (name, email, age) VALUES (%s, %s, %s)",
            (name, email, age)
        )
        conn.commit()
        return redirect(url_for("users"))

    cursor.execute("SELECT * FROM Users")
    users = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("users.html", users=users)


# =========================
# EXERCISES
# =========================
@app.route("/exercises", methods=["GET", "POST"])
def exercises():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    if request.method == "POST":
        exercise_name = request.form["exercise_name"]
        muscle_group = request.form["muscle_group"]
        equipment_type = request.form["equipment_type"]

        cursor.execute(
            """
            INSERT INTO Exercise (exercise_name, muscle_group, equipment_type)
            VALUES (%s, %s, %s)
            """,
            (exercise_name, muscle_group, equipment_type)
        )
        conn.commit()
        return redirect(url_for("exercises"))

    cursor.execute("SELECT * FROM Exercise")
    exercises = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("exercises.html", exercises=exercises)


# =========================
# SESSIONS
# =========================
@app.route("/sessions", methods=["GET", "POST"])
def sessions():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    if request.method == "POST":
        user_id = request.form["user_id"]
        session_date = request.form["session_date"]
        duration_minutes = request.form["duration_minutes"]
        notes = request.form["notes"]

        cursor.execute(
            """
            INSERT INTO WorkoutSession (session_date, duration_minutes, notes, user_id)
            VALUES (%s, %s, %s, %s)
            """,
            (session_date, duration_minutes, notes, user_id)
        )
        conn.commit()
        return redirect(url_for("sessions"))

    cursor.execute("SELECT * FROM Users")
    users = cursor.fetchall()

    cursor.execute(
        """
        SELECT ws.session_id, ws.session_date, ws.duration_minutes, ws.notes, u.name
        FROM WorkoutSession ws
        JOIN Users u ON ws.user_id = u.user_id
        ORDER BY ws.session_date DESC
        """
    )
    sessions = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("sessions.html", users=users, sessions=sessions)


# =========================
# ADD WORKOUT ENTRY
# =========================
@app.route("/session/<int:session_id>/add_entry", methods=["GET", "POST"])
def add_entry(session_id):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    if request.method == "POST":
        exercise_id = request.form["exercise_id"]
        set_number = request.form["set_number"]
        reps = request.form["reps"]
        weight = request.form["weight"]
        rest_seconds = request.form["rest_seconds"]

        cursor.execute(
            """
            INSERT INTO WorkoutEntry 
            (set_number, reps, weight, rest_seconds, session_id, exercise_id)
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (set_number, reps, weight, rest_seconds, session_id, exercise_id)
        )
        conn.commit()
        return redirect(url_for("sessions"))

    cursor.execute("SELECT * FROM Exercise")
    exercises = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("add_entry.html", exercises=exercises, session_id=session_id)


# =========================
# BODY MEASUREMENTS
# =========================
@app.route("/measurements", methods=["GET", "POST"])
def measurements():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    if request.method == "POST":
        user_id = request.form["user_id"]
        measurement_date = request.form["measurement_date"]
        body_weight = request.form["body_weight"]
        body_fat_percentage = request.form["body_fat_percentage"]

        cursor.execute(
            """
            INSERT INTO BodyMeasurement 
            (measurement_date, body_weight, body_fat_percentage, user_id)
            VALUES (%s, %s, %s, %s)
            """,
            (measurement_date, body_weight, body_fat_percentage, user_id)
        )
        conn.commit()
        return redirect(url_for("measurements"))

    cursor.execute("SELECT * FROM Users")
    users = cursor.fetchall()

    cursor.execute(
        """
        SELECT bm.measurement_id, bm.measurement_date, bm.body_weight,
               bm.body_fat_percentage, u.name
        FROM BodyMeasurement bm
        JOIN Users u ON bm.user_id = u.user_id
        ORDER BY bm.measurement_date DESC
        """
    )
    measurements = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template("measurements.html", users=users, measurements=measurements)


# =========================
# STATISTICS (DYNAMIC USER)
# =========================
@app.route("/stats")
def stats():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    selected_user_id = request.args.get("user_id", default=1, type=int)

    cursor.execute("SELECT * FROM Users")
    users = cursor.fetchall()

    # Query 1
    cursor.execute(
        """
        SELECT u.name, ws.session_date, ws.duration_minutes, ws.notes
        FROM Users u
        JOIN WorkoutSession ws ON u.user_id = ws.user_id
        WHERE u.user_id = %s
        """,
        (selected_user_id,)
    )
    workout_history = cursor.fetchall()

    # Query 2
    cursor.execute(
        """
        SELECT ws.session_date, e.exercise_name, we.set_number,
               we.reps, we.weight, we.rest_seconds
        FROM WorkoutEntry we
        JOIN Exercise e ON we.exercise_id = e.exercise_id
        JOIN WorkoutSession ws ON we.session_id = ws.session_id
        WHERE ws.user_id = %s
        ORDER BY ws.session_date, e.exercise_name, we.set_number
        """,
        (selected_user_id,)
    )
    session_exercises = cursor.fetchall()

    # Query 3
    cursor.execute(
        """
        SELECT e.exercise_name,
               SUM(we.reps * we.weight) AS total_volume
        FROM WorkoutEntry we
        JOIN Exercise e ON we.exercise_id = e.exercise_id
        JOIN WorkoutSession ws ON we.session_id = ws.session_id
        WHERE ws.user_id = %s
        GROUP BY e.exercise_name
        ORDER BY total_volume DESC
        """,
        (selected_user_id,)
    )
    total_volume = cursor.fetchall()

    # Query 4
    cursor.execute(
        """
        SELECT e.exercise_name,
               MAX(we.weight) AS max_weight
        FROM WorkoutEntry we
        JOIN Exercise e ON we.exercise_id = e.exercise_id
        JOIN WorkoutSession ws ON we.session_id = ws.session_id
        WHERE ws.user_id = %s
        GROUP BY e.exercise_name
        ORDER BY max_weight DESC
        """,
        (selected_user_id,)
    )
    personal_records = cursor.fetchall()

    # Query 5
    cursor.execute(
        """
        SELECT DATE_FORMAT(measurement_date, '%Y-%m') AS month,
               AVG(body_weight) AS avg_weight
        FROM BodyMeasurement
        WHERE user_id = %s
        GROUP BY DATE_FORMAT(measurement_date, '%Y-%m')
        ORDER BY month
        """,
        (selected_user_id,)
    )
    average_weight = cursor.fetchall()

    cursor.close()
    conn.close()

    return render_template(
        "stats.html",
        users=users,
        selected_user_id=selected_user_id,
        workout_history=workout_history,
        session_exercises=session_exercises,
        total_volume=total_volume,
        personal_records=personal_records,
        average_weight=average_weight
    )


if __name__ == "__main__":
    app.run(debug=True)