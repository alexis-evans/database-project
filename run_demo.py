"""Run the grade book project setup and required queries against MySQL."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import mysql.connector
from mysql.connector.cursor import MySQLCursorDict


BASE_DIR = Path(__file__).resolve().parent
SCHEMA_FILE = BASE_DIR / "schema.sql"
SEED_FILE = BASE_DIR / "seed.sql"

MYSQL_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "127.0.0.1"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "NewStrongPassword123!"),
    "autocommit": True,
}

TASK_LABELS = {
    "task3_students": "Task 3: Students table contents",
    "task3_courses": "Task 3: Courses table contents",
    "task3_enrollments": "Task 3: Enrollments table contents",
    "task3_categories": "Task 3: Categories table contents",
    "task3_assignments": "Task 3: Assignments table contents",
    "task3_scores": "Task 3: Scores table contents",
    "task4": "Task 4: Average, highest, and lowest score of an assignment",
    "task5": "Task 5: Students in a given course",
    "task6": "Task 6: Students in a course with all assignment scores",
    "task7_validate": "Task 7: Validate course category weights before adding an assignment",
    "task7_insert": "Task 7: Add a new assignment",
    "task7_show": "Task 7: Assignments after insertion",
    "task8_reset_temp": "Task 8: Reset temporary category weight update table",
    "task8_create_temp": "Task 8: Create temporary category weight update table",
    "task8_seed_temp": "Task 8: Supply new category percentages",
    "task8_preview": "Task 8: Preview supplied category percentages",
    "task8_zero_out": "Task 8: Temporarily zero out existing course percentages",
    "task8_update": "Task 8: Change category percentages",
    "task8_validate": "Task 8: Validate category percentages total 100",
    "task8_show": "Task 8: Categories after percentage update",
    "task9_update": "Task 9: Add 2 points to all students on one assignment",
    "task9_show": "Task 9: Scores after universal +2 update",
    "task10_update": "Task 10: Add 2 points to students whose last name contains Q",
    "task10_show": "Task 10: Scores after selective +2 update",
    "task11_validate": "Task 11: Validate category percentages before grade computation",
    "task11": "Task 11: Final grade for one student",
    "task12_validate": "Task 12: Validate category percentages before dropped-score grade computation",
    "task12": "Task 12: Final grade with lowest category score dropped",
}

TASK_DEFINITIONS = [
    {
        "id": "task3_students",
        "sql": "SELECT * FROM students ORDER BY student_id",
    },
    {
        "id": "task3_courses",
        "sql": "SELECT * FROM courses ORDER BY course_id",
    },
    {
        "id": "task3_enrollments",
        "sql": "SELECT * FROM enrollments ORDER BY enrollment_id",
    },
    {
        "id": "task3_categories",
        "sql": "SELECT * FROM categories ORDER BY category_id",
    },
    {
        "id": "task3_assignments",
        "sql": "SELECT * FROM assignments ORDER BY assignment_id",
    },
    {
        "id": "task3_scores",
        "sql": "SELECT * FROM scores ORDER BY score_id",
    },
    {
        "id": "task4",
        "sql": """
            SELECT
                a.assignment_id,
                a.assignment_name,
                ROUND(AVG(s.score), 2) AS average_score,
                MAX(s.score) AS highest_score,
                MIN(s.score) AS lowest_score
            FROM assignments AS a
            JOIN scores AS s
                ON s.assignment_id = a.assignment_id
            WHERE a.assignment_id = %(assignment_id)s
            GROUP BY a.assignment_id, a.assignment_name
        """,
    },
    {
        "id": "task5",
        "sql": """
            SELECT
                c.course_id,
                c.course_name,
                s.student_id,
                s.first_name,
                s.last_name,
                s.email
            FROM courses AS c
            JOIN enrollments AS e
                ON e.course_id = c.course_id
            JOIN students AS s
                ON s.student_id = e.student_id
            WHERE c.course_id = %(course_id)s
            ORDER BY s.last_name, s.first_name
        """,
    },
    {
        "id": "task6",
        "sql": """
            SELECT
                c.course_id,
                c.course_name,
                s.student_id,
                s.first_name,
                s.last_name,
                a.assignment_id,
                a.assignment_name,
                cat.category_name,
                sc.score
            FROM courses AS c
            JOIN enrollments AS e
                ON e.course_id = c.course_id
            JOIN students AS s
                ON s.student_id = e.student_id
            JOIN assignments AS a
                ON a.course_id = c.course_id
            JOIN categories AS cat
                ON cat.category_id = a.category_id
            LEFT JOIN scores AS sc
                ON sc.assignment_id = a.assignment_id
               AND sc.student_id = s.student_id
            WHERE c.course_id = %(course_id)s
            ORDER BY s.last_name, s.first_name, a.assignment_id
        """,
    },
    {
        "id": "task7_validate",
        "sql": "CALL assert_course_weights_total_100(%(new_assignment_course_id)s)",
    },
    {
        "id": "task7_insert",
        "sql": """
            INSERT INTO assignments (course_id, category_id, assignment_name, max_points, due_date)
            VALUES (%(new_assignment_course_id)s, %(new_assignment_category_id)s, 'Homework 4', 100.00, '2025-10-06')
        """,
    },
    {
        "id": "task7_show",
        "sql": """
            SELECT *
            FROM assignments
            WHERE course_id = %(new_assignment_course_id)s
            ORDER BY assignment_id
        """,
    },
    {
        "id": "task8_reset_temp",
        "sql": "DROP TEMPORARY TABLE IF EXISTS task8_category_weight_changes",
    },
    {
        "id": "task8_create_temp",
        "sql": """
            CREATE TEMPORARY TABLE task8_category_weight_changes (
                category_id INT PRIMARY KEY,
                new_weight_percentage DECIMAL(5,2) NOT NULL,
                CONSTRAINT chk_task8_weight
                    CHECK (new_weight_percentage >= 0 AND new_weight_percentage <= 100)
            )
        """,
    },
    {
        "id": "task8_seed_temp",
        "sql": """
            INSERT INTO task8_category_weight_changes (category_id, new_weight_percentage) VALUES
                (1, 15.00),
                (2, 25.00),
                (3, 40.00),
                (4, 20.00)
        """,
    },
    {
        "id": "task8_preview",
        "sql": """
            SELECT
                COUNT(*) AS rows_supplied,
                ROUND(SUM(new_weight_percentage), 2) AS supplied_total_weight
            FROM task8_category_weight_changes
        """,
    },
    {
        "id": "task8_zero_out",
        "sql": """
            UPDATE categories
            SET weight_percentage = 0
            WHERE course_id = %(course_id)s
        """,
    },
    {
        "id": "task8_update",
        "sql": """
            UPDATE categories AS c
            JOIN task8_category_weight_changes AS t
                ON t.category_id = c.category_id
            SET c.weight_percentage = t.new_weight_percentage
            WHERE c.course_id = %(course_id)s
        """,
    },
    {
        "id": "task8_validate",
        "sql": "CALL assert_course_weights_total_100(%(course_id)s)",
    },
    {
        "id": "task8_show",
        "sql": """
            SELECT course_id, category_name, weight_percentage
            FROM categories
            WHERE course_id = %(course_id)s
            ORDER BY category_id
        """,
    },
    {
        "id": "task9_update",
        "sql": """
            UPDATE scores AS sc
            JOIN assignments AS a
                ON a.assignment_id = sc.assignment_id
            SET sc.score = LEAST(sc.score + 2, a.max_points)
            WHERE sc.assignment_id = %(assignment_id)s
        """,
    },
    {
        "id": "task9_show",
        "sql": """
            SELECT assignment_id, student_id, score
            FROM scores
            WHERE assignment_id = %(assignment_id)s
            ORDER BY student_id
        """,
    },
    {
        "id": "task10_update",
        "sql": """
            UPDATE scores AS sc
            JOIN students AS s
                ON s.student_id = sc.student_id
            JOIN assignments AS a
                ON a.assignment_id = sc.assignment_id
            SET sc.score = LEAST(sc.score + 2, a.max_points)
            WHERE sc.assignment_id = %(assignment_id)s
              AND s.last_name LIKE '%%Q%%'
        """,
    },
    {
        "id": "task10_show",
        "sql": """
            SELECT sc.assignment_id, sc.student_id, s.last_name, sc.score
            FROM scores AS sc
            JOIN students AS s
                ON s.student_id = sc.student_id
            WHERE sc.assignment_id = %(assignment_id)s
            ORDER BY sc.student_id
        """,
    },
    {
        "id": "task11_validate",
        "sql": "CALL assert_course_weights_total_100(%(course_id)s)",
    },
    {
        "id": "task11",
        "sql": """
            WITH category_student_scores AS (
                SELECT
                    a.category_id,
                    AVG((sc.score / a.max_points) * 100) AS category_average
                FROM assignments AS a
                JOIN scores AS sc
                    ON sc.assignment_id = a.assignment_id
                WHERE a.course_id = %(course_id)s
                  AND sc.student_id = %(student_id)s
                GROUP BY a.category_id
            )
            SELECT
                st.student_id,
                st.first_name,
                st.last_name,
                ROUND(SUM((css.category_average * cat.weight_percentage) / 100), 2) AS final_grade
            FROM category_student_scores AS css
            JOIN categories AS cat
                ON cat.category_id = css.category_id
            JOIN students AS st
                ON st.student_id = %(student_id)s
            GROUP BY st.student_id, st.first_name, st.last_name
        """,
    },
    {
        "id": "task12_validate",
        "sql": "CALL assert_course_weights_total_100(%(course_id)s)",
    },
    {
        "id": "task12",
        "sql": """
            WITH ranked_scores AS (
                SELECT
                    a.category_id,
                    sc.score,
                    a.max_points,
                    ROW_NUMBER() OVER (
                        PARTITION BY a.category_id
                        ORDER BY (sc.score / a.max_points), a.assignment_id
                    ) AS score_rank,
                    COUNT(*) OVER (PARTITION BY a.category_id) AS assignment_count
                FROM assignments AS a
                JOIN scores AS sc
                    ON sc.assignment_id = a.assignment_id
                WHERE a.course_id = %(course_id)s
                  AND sc.student_id = %(student_id)s
            ),
            category_student_scores AS (
                SELECT
                    rs.category_id,
                    CASE
                        WHEN MAX(rs.assignment_count) = 1 THEN AVG((rs.score / rs.max_points) * 100)
                        ELSE AVG(
                            CASE
                                WHEN rs.score_rank = 1 THEN NULL
                                ELSE (rs.score / rs.max_points) * 100
                            END
                        )
                    END AS category_average_after_drop
                FROM ranked_scores AS rs
                GROUP BY rs.category_id
            )
            SELECT
                st.student_id,
                st.first_name,
                st.last_name,
                ROUND(SUM((css.category_average_after_drop * cat.weight_percentage) / 100), 2) AS final_grade_with_drop
            FROM category_student_scores AS css
            JOIN categories AS cat
                ON cat.category_id = css.category_id
            JOIN students AS st
                ON st.student_id = %(student_id)s
            GROUP BY st.student_id, st.first_name, st.last_name
        """,
    },
]

DEFAULT_PARAMS = {
    "course_id": 1,
    "student_id": 3,
    "assignment_id": 9,
    "new_assignment_course_id": 1,
    "new_assignment_category_id": 2,
}

TASK_GROUPS = {
    1: [],
    2: [],
    3: [
        "task3_students",
        "task3_courses",
        "task3_enrollments",
        "task3_categories",
        "task3_assignments",
        "task3_scores",
    ],
    4: ["task4"],
    5: ["task5"],
    6: ["task6"],
    7: ["task7_validate", "task7_insert", "task7_show"],
    8: [
        "task8_reset_temp",
        "task8_create_temp",
        "task8_seed_temp",
        "task8_preview",
        "task8_zero_out",
        "task8_update",
        "task8_validate",
        "task8_show",
    ],
    9: ["task9_update", "task9_show"],
    10: ["task10_update", "task10_show"],
    11: ["task11_validate", "task11"],
    12: ["task12_validate", "task12"],
}


def print_table(rows: list[dict]) -> None:
    if not rows:
        print("No rows returned.\n")
        return

    headers = list(rows[0].keys())
    widths = {
        header: max(len(str(header)), *(len(str(row[header])) for row in rows))
        for header in headers
    }

    header_line = " | ".join(f"{header:{widths[header]}}" for header in headers)
    divider = "-+-".join("-" * widths[header] for header in headers)
    print(header_line)
    print(divider)
    for row in rows:
        print(" | ".join(f"{str(row[header]):{widths[header]}}" for header in headers))
    print()


def split_sql_script(sql_text: str) -> list[str]:
    statements: list[str] = []
    delimiter = ";"
    buffer: list[str] = []

    for line in sql_text.splitlines(keepends=True):
        stripped = line.strip()

        if stripped.upper().startswith("DELIMITER "):
            delimiter = stripped.split(maxsplit=1)[1]
            continue

        buffer.append(line)
        current_text = "".join(buffer).rstrip()

        if current_text.endswith(delimiter):
            statement = current_text[: -len(delimiter)].strip()
            if statement:
                statements.append(statement)
            buffer = []

    trailing = "".join(buffer).strip()
    if trailing:
        statements.append(trailing)

    return statements


def run_sql_script(connection: mysql.connector.MySQLConnection, path: Path) -> None:
    sql_text = path.read_text(encoding="utf-8")
    cursor = connection.cursor()
    try:
        for statement in split_sql_script(sql_text):
            cursor.execute(statement)
            if cursor.with_rows:
                cursor.fetchall()
    finally:
        cursor.close()


def execute_task(cursor: MySQLCursorDict, task: dict, params: dict) -> None:
    label = TASK_LABELS[task["id"]]
    print(f"\n=== {label} ===")
    cursor.execute(task["sql"], params)

    if cursor.with_rows:
        rows = cursor.fetchall()
        print_table(rows)
    else:
        print(f"Rows affected: {cursor.rowcount}\n")

    while cursor.nextset():
        if cursor.with_rows:
            cursor.fetchall()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the grade book project demo queries."
    )
    parser.add_argument(
        "task",
        nargs="?",
        type=int,
        choices=sorted(TASK_GROUPS),
        help="Task number to run (1-12). Omit to run all tasks.",
    )
    return parser.parse_args()


def get_tasks_to_run(selected_task: int | None) -> list[dict]:
    if selected_task is None:
        return TASK_DEFINITIONS

    task_ids = set(TASK_GROUPS[selected_task])
    return [task for task in TASK_DEFINITIONS if task["id"] in task_ids]


def main() -> int:
    args = parse_args()

    try:
        connection = mysql.connector.connect(**MYSQL_CONFIG)
    except mysql.connector.Error as exc:
        print("Could not connect to MySQL with the current environment settings.")
        print(f"Error: {exc}")
        return 1

    try:
        cursor = connection.cursor(dictionary=True)
        if args.task is None:
            print("Rebuilding database from schema.sql and seed.sql ...")
            run_sql_script(connection, SCHEMA_FILE)
            run_sql_script(connection, SEED_FILE)
        elif args.task == 1:
            print("Running task 1: rebuilding database from schema.sql ...")
            run_sql_script(connection, SCHEMA_FILE)
            return 0
        elif args.task == 2:
            print("Running task 2: loading seed.sql ...")
            run_sql_script(connection, SEED_FILE)
            return 0
        else:
            print("Rebuilding database from schema.sql and seed.sql ...")
            run_sql_script(connection, SCHEMA_FILE)
            run_sql_script(connection, SEED_FILE)

        print("\nUsing parameters:")
        for key, value in DEFAULT_PARAMS.items():
            print(f"  {key} = {value}")

        if args.task is None:
            print("\nRunning all tasks.")
        else:
            print(f"\nRunning task {args.task}.")

        for task in get_tasks_to_run(args.task):
            execute_task(cursor, task, DEFAULT_PARAMS)
    finally:
        connection.close()

    return 0


if __name__ == "__main__":
    sys.exit(main())
