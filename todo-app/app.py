from flask import Flask, render_template, request, redirect, url_for
from sqlalchemy import create_engine, text
import os

app = Flask(__name__)

# Database credentials from environment variables
# Private IP of Azure SQL Server or server name
DB_HOST = os.environ.get('DB_HOST')
DB_USER = os.environ.get('DB_USER')
DB_PASSWORD = os.environ.get('DB_PASSWORD')
DB_DATABASE = os.environ.get('DB_DATABASE')

# Specify the driver and update the connection string
connection_string = f'mssql+pyodbc://{DB_USER}:{DB_PASSWORD}@{DB_HOST}/{DB_DATABASE}?driver=ODBC+Driver+17+for+SQL+Server'

# Create the engine
db_connection = create_engine(connection_string, pool_recycle=1433)

# Pages Routes


@app.route('/')
def index():
    try:
        with db_connection.connect() as conn:
            result = conn.execute(text("SELECT * FROM tasks"))
            tasks = result.fetchall()
    except Exception as e:
        print(f"An error occurred: {e}")
        tasks = []
    return render_template('index.html', tasks=tasks)


@app.route('/add', methods=['POST'])
def add_task():
    title = request.form.get('title')
    description = request.form.get('description')
    add_task_to_database(title, description)
    return redirect(url_for('index'))


@app.route('/delete/<int:task_id>', methods=['POST'])
def delete_task(task_id):
    try:
        with db_connection.connect() as conn:
            conn.execute(text("DELETE FROM tasks WHERE id = :id"),
                         {"id": task_id})
    except Exception as e:
        print(f"An error occurred: {e}")
    return redirect(url_for('index'))


@app.route('/complete/<int:task_id>', methods=['POST'])
def complete_task(task_id):
    try:
        with db_connection.connect() as conn:
            conn.execute(text("UPDATE tasks SET is_complete = TRUE WHERE id = :id"), {
                         "id": task_id})
    except Exception as e:
        print(f"An error occurred: {e}")
    return redirect(url_for('index'))

# Send data to the database


def add_task_to_database(title, description):
    try:
        with db_connection.connect() as conn:
            conn.execute(text("INSERT INTO tasks (title, description) VALUES (:title, :description)"),
                         {"title": title, "description": description})
    except Exception as e:
        print(f"An error occurred: {e}")


if __name__ == '__main__':
    app.run(host='0.0.0.0', debug=True)
