USE gradebook_project;

SET @course_id = 1;
SET @student_id = 3;
SET @assignment_id = 9;
SET @new_assignment_course_id = 1;
SET @new_assignment_category_id = 2;

-- Task 3: show the tables with inserted values
SELECT * FROM students ORDER BY student_id;
SELECT * FROM courses ORDER BY course_id;
SELECT * FROM enrollments ORDER BY enrollment_id;
SELECT * FROM categories ORDER BY category_id;
SELECT * FROM assignments ORDER BY assignment_id;
SELECT * FROM scores ORDER BY score_id;

-- Task 4: compute the average/highest/lowest score of an assignment
SELECT
    a.assignment_id,
    a.assignment_name,
    ROUND(AVG(s.score), 2) AS average_score,
    MAX(s.score) AS highest_score,
    MIN(s.score) AS lowest_score
FROM assignments AS a
JOIN scores AS s
    ON s.assignment_id = a.assignment_id
WHERE a.assignment_id = @assignment_id
GROUP BY a.assignment_id, a.assignment_name;

-- Task 5: list all students in a given course
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
WHERE c.course_id = @course_id
ORDER BY s.last_name, s.first_name;

-- Task 6: list all students in a course and all of their scores on every assignment
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
WHERE c.course_id = @course_id
ORDER BY s.last_name, s.first_name, a.assignment_id;

-- Task 7: add an assignment to a course
CALL assert_course_weights_total_100(@new_assignment_course_id);

INSERT INTO assignments (course_id, category_id, assignment_name, max_points, due_date)
VALUES (@new_assignment_course_id, @new_assignment_category_id, 'Homework 4', 100.00, '2025-10-06');

SELECT *
FROM assignments
WHERE course_id = @new_assignment_course_id
ORDER BY assignment_id;

-- Task 8: change the percentages of the categories for a course
-- This update pattern is course-agnostic: provide the target category_id rows and new weights.
DROP TEMPORARY TABLE IF EXISTS task8_category_weight_changes;

CREATE TEMPORARY TABLE task8_category_weight_changes (
    category_id INT PRIMARY KEY,
    new_weight_percentage DECIMAL(5,2) NOT NULL,
    CONSTRAINT chk_task8_weight
        CHECK (new_weight_percentage >= 0 AND new_weight_percentage <= 100)
);

INSERT INTO task8_category_weight_changes (category_id, new_weight_percentage) VALUES
    (1, 15.00),
    (2, 25.00),
    (3, 40.00),
    (4, 20.00);

SELECT
    COUNT(*) AS rows_supplied,
    ROUND(SUM(new_weight_percentage), 2) AS supplied_total_weight
FROM task8_category_weight_changes;

UPDATE categories
SET weight_percentage = 0
WHERE course_id = @course_id;

UPDATE categories AS c
JOIN task8_category_weight_changes AS t
    ON t.category_id = c.category_id
SET c.weight_percentage = t.new_weight_percentage
WHERE c.course_id = @course_id;

CALL assert_course_weights_total_100(@course_id);

SELECT
    course_id,
    category_name,
    weight_percentage
FROM categories
WHERE course_id = @course_id
ORDER BY category_id;

-- Task 9: add 2 points to the score of each student on an assignment, capped at the assignment max_points
UPDATE scores AS sc
JOIN assignments AS a
    ON a.assignment_id = sc.assignment_id
SET sc.score = LEAST(sc.score + 2, a.max_points)
WHERE sc.assignment_id = @assignment_id;

SELECT
    assignment_id,
    student_id,
    score
FROM scores
WHERE assignment_id = @assignment_id
ORDER BY student_id;

-- Task 10: add 2 points just to those students whose last name contains a 'Q', capped at the assignment max_points
UPDATE scores AS sc
JOIN students AS s
    ON s.student_id = sc.student_id
JOIN assignments AS a
    ON a.assignment_id = sc.assignment_id
SET sc.score = LEAST(sc.score + 2, a.max_points)
WHERE sc.assignment_id = @assignment_id
  AND s.last_name LIKE '%Q%';

SELECT
    sc.assignment_id,
    sc.student_id,
    s.last_name,
    sc.score
FROM scores AS sc
JOIN students AS s
    ON s.student_id = sc.student_id
WHERE sc.assignment_id = @assignment_id
ORDER BY sc.student_id;

-- Task 11: compute the grade for a student
CALL assert_course_weights_total_100(@course_id);

WITH category_student_scores AS (
    SELECT
        a.category_id,
        AVG((sc.score / a.max_points) * 100) AS category_average
    FROM assignments AS a
    JOIN scores AS sc
        ON sc.assignment_id = a.assignment_id
    WHERE a.course_id = @course_id
      AND sc.student_id = @student_id
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
    ON st.student_id = @student_id
GROUP BY st.student_id, st.first_name, st.last_name;

-- Task 12: compute the grade for a student where the lowest score in each category is dropped
CALL assert_course_weights_total_100(@course_id);

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
    WHERE a.course_id = @course_id
      AND sc.student_id = @student_id
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
    ON st.student_id = @student_id
GROUP BY st.student_id, st.first_name, st.last_name;
