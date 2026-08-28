from flask import Flask, request, jsonify
import mysql.connector
import os
import time

app = Flask(__name__)


def get_db_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME"),
        port=int(os.getenv("DB_PORT", 3306))
    )


def initialize_database():
    for _ in range(10):
        try:
            connection = get_db_connection()
            cursor = connection.cursor()

            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(100) NOT NULL,
                    email VARCHAR(100) NOT NULL UNIQUE
                )
            """)

            connection.commit()

            cursor.close()
            connection.close()

            print("Database initialized successfully")
            return

        except Exception as e:
            print(f"Database connection failed: {e}")
            time.sleep(5)

    print("Could not connect to database")


@app.route("/")
def home():
    return jsonify({
        "message": "Hello from Flask running on Kubernetes!"
    })


@app.route("/health")
def health():
    return jsonify({
        "status": "healthy"
    }), 200


@app.route("/users", methods=["GET"])
def get_users():
    try:
        connection = get_db_connection()
        cursor = connection.cursor(dictionary=True)

        cursor.execute("SELECT * FROM users")
        users = cursor.fetchall()

        cursor.close()
        connection.close()

        return jsonify(users), 200

    except Exception as e:
        return jsonify({
            "error": str(e)
        }), 500


@app.route("/users", methods=["POST"])
def create_user():
    data = request.get_json()

    name = data.get("name")
    email = data.get("email")

    if not name or not email:
        return jsonify({
            "error": "Name and email are required"
        }), 400

    try:
        connection = get_db_connection()
        cursor = connection.cursor()

        cursor.execute(
            "INSERT INTO users (name, email) VALUES (%s, %s)",
            (name, email)
        )

        connection.commit()

        cursor.close()
        connection.close()

        return jsonify({
            "message": "User created successfully"
        }), 201

    except Exception as e:
        return jsonify({
            "error": str(e)
        }), 500


if __name__ == "__main__":
    initialize_database()

    app.run(
        host="0.0.0.0",
        port=5000
    )
