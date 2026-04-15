# Test Cases and Expected Results

The following tests use the seeded data in `seed.sql` and the default parameters in `run_demo.py` and `queries.sql`:

- `course_id = 1` for `CS 101 - Introduction to Databases`
- `student_id = 3` for `Carla Quinn`
- `assignment_id = 9` for `Project 2`

## Functional Tests

### Task 3

Verify that all six tables display inserted records.

Expected result:

- `students` contains `10` rows
- `courses` contains `3` rows
- `enrollments` contains `14` rows
- `categories` contains `10` rows
- `assignments` contains `15` rows before task 7
- `scores` contains `84` rows

### Task 4

Compute average, highest, and lowest score for assignment `9` (`Project 2`).

Expected result:

- scores are `97, 85, 100, 87, 94, 98, 86`
- average is `92.43`
- highest is `100`
- lowest is `85`

### Task 5

List all students in course `1`.

Expected result:

- `7` students are returned
- names include `Alice Anderson`, `Brian Brown`, `Carla Quinn`, `David Diaz`, `Evelyn Edwards`, `Farah Qureshi`, and `Grace Green`

### Task 6

List all students in course `1` and all of their scores on every assignment.

Expected result:

- before task 7, course `1` has `9` assignments
- result set contains `7 x 9 = 63` rows
- each student appears once per assignment in that course

### Task 7

Add `Homework 4` to course `1` under the `Homework` category.

Expected result:

- the validation procedure confirms that course `1` category weights total `100`
- one row is inserted into `assignments`
- course `1` then has `10` assignments
- the new assignment appears with name `Homework 4`

### Task 8

Change category weights for course `1`.

Expected result:

- the temporary update table contains `4` rows
- the supplied total weight is `100.00`
- `Participation = 15`
- `Homework = 25`
- `Tests = 40`
- `Projects = 20`
- validation succeeds because the course still totals `100`

### Task 9

Add `2` points to all scores on assignment `9`, capped at the assignment's `max_points`.

Expected result:

- assignment `9` scores become `99, 87, 100, 89, 96, 100, 88`
- students who were at `98` or `100` do not exceed the assignment maximum

### Task 10

Add `2` points only to students on assignment `9` whose last name contains `Q`, capped at the assignment's `max_points`.

Expected result:

- `Carla Quinn` remains `100`
- `Farah Qureshi` remains `100`
- all other students keep their task 9 values

### Task 11

Compute the grade for `Carla Quinn` in course `1` after tasks 7 through 10.

Expected result:

- the inserted `Homework 4` does not affect the grade until a score exists for the student
- category averages after task 8 are:
- participation: `(100 + 98) / 2 = 99.00`
- homework: `(94 + 97 + 96) / 3 = 95.67`
- tests: `(98 + 95) / 2 = 96.50`
- projects: `(99 + 100) / 2 = 99.50`
- final weighted grade is:
- `(99.00 x 0.15) + (95.67 x 0.25) + (96.50 x 0.40) + (99.50 x 0.20) = 97.27`

### Task 12

Compute the grade for `Carla Quinn` in course `1` with the lowest score in each category dropped.

Expected result:

- participation drops `98`, leaving `100.00`
- homework drops `94`, leaving average `(97 + 96) / 2 = 96.50`
- tests drops `95`, leaving `98.00`
- projects drops `99`, leaving `100.00`
- final weighted grade is:
- `(100.00 x 0.15) + (96.50 x 0.25) + (98.00 x 0.40) + (100.00 x 0.20) = 98.33`

## Integrity Tests

These tests specifically address the weak points called out in grading feedback.

### Weight totals cannot exceed 100

Test query:

```sql
INSERT INTO categories (course_id, category_name, weight_percentage)
VALUES (1, 'Extra Credit Bucket', 5.00);
```

Expected result:

- the insert is rejected with an error because course `1` already totals `100`

### Grades are only computed for a valid 100-point course setup

Test query:

```sql
UPDATE categories
SET weight_percentage = 10.00
WHERE category_id = 4;

CALL assert_course_weights_total_100(1);
```

Expected result:

- the update succeeds only if the course total does not exceed `100`
- the procedure call fails because the course no longer totals exactly `100`

### Scores require enrollment in the course

Test query:

```sql
INSERT INTO scores (assignment_id, student_id, course_id, score)
VALUES (1, 8, 1, 90.00);
```

Expected result:

- the insert is rejected because student `8` is not enrolled in course `1`

### Scores must match the assignment's course

Test query:

```sql
INSERT INTO scores (assignment_id, student_id, course_id, score)
VALUES (1, 1, 2, 90.00);
```

Expected result:

- the insert is rejected because assignment `1` belongs to course `1`, not course `2`

### Scores cannot exceed `max_points`

Test query:

```sql
INSERT INTO scores (assignment_id, student_id, course_id, score)
VALUES (1, 1, 1, 105.00);
```

Expected result:

- the insert is rejected because assignment `1` has `max_points = 100`

### Score updates are capped at the assignment maximum

Test query:

```sql
UPDATE scores AS sc
JOIN assignments AS a
    ON a.assignment_id = sc.assignment_id
SET sc.score = LEAST(sc.score + 2, a.max_points)
WHERE sc.assignment_id = 9;
```

Expected result:

- no score becomes greater than the assignment's `max_points`
- `Carla Quinn` stays at `100`
- `Farah Qureshi` moves from `98` to `100`, not `100+`
