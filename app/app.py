from flask import Flask, request, jsonify
import mysql.connector
import os
import time

app = Flask(**name**)

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

```
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
```

@app.route("/")
def home():
return jsonify({
"message": "Hello from Kubernetes!",
"application": "Flask + MySQL + EKS"
})

@app.route("/health")
def health():
return jsonify({
"status": "healthy"
}), 200

@app.route("/users", methods=["POST"])
def create_user():
data = request.get_json()

```
if not data or "name" not in data or "email" not in data:
    return jsonify({
        "error": "name and email are required"
    }), 400

try:
    connection = get_db_connection()
    cursor = connection.cursor()

    query = "INSERT INTO users (name, email) VALUES (%s, %s)"

    cursor.execute(
        query,
        (data["name"], data["email"])
    )

    connection.commit()

    user_id = cursor.lastrowid

    cursor.close()
    connection.close()

    return jsonify({
        "message": "User created successfully",
        "id": user_id
    }), 201

except Exception as e:
    return jsonify({
        "error": str(e)
    }), 500
```

@app.route("/users", methods=["GET"])
def get_users():
try:
connection = get_db_connection()
cursor = connection.cursor(dictionary=True)

```
    cursor.execute("SELECT * FROM users")

    users = cursor.fetchall()

    cursor.close()
    connection.close()

    return jsonify(users), 200

except Exception as e:
    return jsonify({
        "error": str(e)
    }), 500
```

if **name** == "**main**":
initialize_database()

```
app.run(
    host="0.0.0.0",
    port=5000
)
```
