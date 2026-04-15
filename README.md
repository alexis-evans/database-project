# Grade Book Project

Alexis Evans and Erica Okeh

This project implements a MySQL grade book for multiple courses. It includes the full schema, sample data, SQL commands for tasks 3 through 12, a Python demo runner, an ER diagram, and written test cases with expected results.

The submission is designed to satisfy the assignment requirements and to enforce the key business rules from the problem statement:

- each course defines grading categories whose percentages total exactly `100`
- the overall perfect grade is `100`, because weighted category percentages are validated before grading
- a score can only exist if the student is enrolled in the course for that assignment
- a score cannot exceed the `max_points` for its assignment

## Files

- `schema.sql`: creates the `gradebook_project` database, tables, constraints, triggers, and validation procedure
- `seed.sql`: inserts sample students, courses, enrollments, categories, assignments, and scores
- `queries.sql`: SQL commands for tasks 3 through 12
- `run_demo.py`: Python script that rebuilds the database and runs the required tasks in sequence
- `ERD.md`: ER diagram plus design notes explaining the relationships
- `ERD.png`: exported ER diagram image
- `test_cases.md`: positive and negative test cases with expected results
- `requirements.txt`: Python dependency for the MySQL driver

## Design Notes

### Category percentages total 100

MySQL does not support a simple row-level `CHECK` constraint for a cross-row rule like "all category weights in one course must add to exactly 100." This project enforces that rule in two layers:

- triggers on `categories` prevent the total weight for a course from ever exceeding `100`
- the stored procedure `assert_course_weights_total_100(course_id)` validates that a course totals exactly `100` before assignments are added for demonstration and before grades are computed

This keeps the schema safe while still allowing categories to be inserted one row at a time during setup.

### Why `scores.course_id` is stored

The `scores` table includes `course_id` intentionally. That extra column lets the schema enforce two important integrity rules with foreign keys:

- `(student_id, course_id)` must exist in `enrollments`, so scores can only be recorded for enrolled students
- `(assignment_id, course_id)` must exist in `assignments`, so the score must belong to the same course as the assignment

Without `course_id` in `scores`, the database could allow invalid grade records unless application code or triggers performed all validation.

### Why `assignments` stores both `course_id` and `category_id`

Each category belongs to one course, but storing `course_id` directly in `assignments` is still useful:

- it lets the schema enforce that an assignment's category belongs to the same course through the composite foreign key `(course_id, category_id)`
- it supports course-scoped uniqueness for assignment names
- it makes common course queries simpler and more efficient

## Requirements

- MySQL `8.0` or newer
- Python `3.10` or newer
- a MySQL user account with permission to create databases

## Setup

1. Install the Python dependency:

```bash
python3 -m pip install -r requirements.txt
```

2. Make sure a MySQL server is running.

3. Set connection variables if your MySQL server is not using the defaults:

```bash
export MYSQL_HOST=127.0.0.1
export MYSQL_PORT=3306
export MYSQL_USER=root
export MYSQL_PASSWORD=your_password
```

## Run With The Python Driver

Execute the full demo:

```bash
python3 run_demo.py
```

The script will:

- recreate the database from `schema.sql`
- insert the sample records from `seed.sql`
- print the populated tables for task 3
- run tasks 4 through 12 in sequence
- show the updated category percentages and grade calculations after tasks 7 through 10

## Run With MySQL Manually

If you want to execute the SQL files directly:

```bash
mysql -u root -p < schema.sql
mysql -u root -p < seed.sql
mysql -u root -p gradebook_project < queries.sql
```

## Task Notes

- Task 8 is implemented with a temporary table of `(category_id, new_weight_percentage)` values. That makes the update pattern general for any course, instead of hard-coding category names in the `UPDATE`.
- Tasks 9 and 10 cap updates at each assignment's `max_points`, not at a hard-coded `100`.
- Task 11 computes the weighted grade from category averages.
- Task 12 computes the weighted grade after dropping the student's lowest normalized score in each category.

## Compile / Execute Summary

This project does not require compilation. To execute it:

1. Install MySQL and start the server.
2. Install the Python dependency with `python3 -m pip install -r requirements.txt`.
3. Set the MySQL environment variables if needed.
4. Run `python3 run_demo.py`.
