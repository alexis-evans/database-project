DROP DATABASE IF EXISTS gradebook_project;
CREATE DATABASE gradebook_project;
USE gradebook_project;

DROP TABLE IF EXISTS scores;
DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS courses;

CREATE TABLE students (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE courses (
    course_id INT PRIMARY KEY AUTO_INCREMENT,
    department VARCHAR(10) NOT NULL,
    course_number VARCHAR(10) NOT NULL,
    course_name VARCHAR(100) NOT NULL,
    semester VARCHAR(20) NOT NULL,
    year INT NOT NULL,
    UNIQUE KEY uq_course_offering (department, course_number, semester, year)
);

CREATE TABLE enrollments (
    enrollment_id INT PRIMARY KEY AUTO_INCREMENT,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    CONSTRAINT fk_enrollment_student
        FOREIGN KEY (student_id) REFERENCES students(student_id),
    CONSTRAINT fk_enrollment_course
        FOREIGN KEY (course_id) REFERENCES courses(course_id),
    CONSTRAINT uq_enrollment UNIQUE KEY (student_id, course_id)
);

CREATE TABLE categories (
    category_id INT PRIMARY KEY AUTO_INCREMENT,
    course_id INT NOT NULL,
    category_name VARCHAR(50) NOT NULL,
    weight_percentage DECIMAL(5,2) NOT NULL,
    CONSTRAINT fk_category_course
        FOREIGN KEY (course_id) REFERENCES courses(course_id),
    CONSTRAINT uq_course_category_name UNIQUE KEY (course_id, category_name),
    CONSTRAINT uq_course_category_id UNIQUE KEY (course_id, category_id),
    CONSTRAINT chk_category_weight
        CHECK (weight_percentage >= 0 AND weight_percentage <= 100)
);

CREATE TABLE assignments (
    assignment_id INT PRIMARY KEY AUTO_INCREMENT,
    course_id INT NOT NULL,
    category_id INT NOT NULL,
    assignment_name VARCHAR(100) NOT NULL,
    max_points DECIMAL(5,2) NOT NULL DEFAULT 100,
    due_date DATE NULL,
    CONSTRAINT fk_assignment_course
        FOREIGN KEY (course_id) REFERENCES courses(course_id),
    CONSTRAINT fk_assignment_course_category
        FOREIGN KEY (course_id, category_id)
        REFERENCES categories(course_id, category_id),
    CONSTRAINT uq_assignment_name_in_course UNIQUE KEY (course_id, assignment_name),
    CONSTRAINT chk_assignment_max_points
        CHECK (max_points > 0 AND max_points <= 100)
);

CREATE TABLE scores (
    score_id INT PRIMARY KEY AUTO_INCREMENT,
    assignment_id INT NOT NULL,
    student_id INT NOT NULL,
    score DECIMAL(5,2) NOT NULL,
    CONSTRAINT fk_score_assignment
        FOREIGN KEY (assignment_id) REFERENCES assignments(assignment_id),
    CONSTRAINT fk_score_student
        FOREIGN KEY (student_id) REFERENCES students(student_id),
    CONSTRAINT uq_student_assignment UNIQUE KEY (student_id, assignment_id),
    CONSTRAINT chk_score_range
        CHECK (score >= 0 AND score <= 100)
);

USE gradebook_project;

INSERT INTO students (student_id, first_name, last_name, email) VALUES
(1, 'Alice', 'Anderson', 'alice.anderson@example.edu'),
(2, 'Brian', 'Brown', 'brian.brown@example.edu'),
(3, 'Carla', 'Quinn', 'carla.quinn@example.edu'),
(4, 'David', 'Diaz', 'david.diaz@example.edu'),
(5, 'Evelyn', 'Edwards', 'evelyn.edwards@example.edu'),
(6, 'Farah', 'Qureshi', 'farah.qureshi@example.edu'),
(7, 'Grace', 'Green', 'grace.green@example.edu'),
(8, 'Henry', 'Hall', 'henry.hall@example.edu'),
(9, 'Iris', 'Iverson', 'iris.iverson@example.edu'),
(10, 'Jason', 'Jones', 'jason.jones@example.edu');

INSERT INTO courses (course_id, department, course_number, course_name, semester, year) VALUES
(1, 'CS', '101', 'Introduction to Databases', 'Fall', 2025),
(2, 'CS', '240', 'Data Structures', 'Spring', 2026),
(3, 'MATH', '201', 'Discrete Mathematics', 'Fall', 2025);

INSERT INTO enrollments (enrollment_id, student_id, course_id) VALUES
(1, 1, 1),
(2, 2, 1),
(3, 3, 1),
(4, 4, 1),
(5, 5, 1),
(6, 6, 1),
(7, 7, 1),
(8, 8, 2),
(9, 9, 2),
(10, 10, 2),
(11, 1, 3),
(12, 3, 3),
(13, 5, 3),
(14, 7, 3);

INSERT INTO categories (category_id, course_id, category_name, weight_percentage) VALUES
(1, 1, 'Participation', 10.00),
(2, 1, 'Homework', 20.00),
(3, 1, 'Tests', 50.00),
(4, 1, 'Projects', 20.00),
(5, 2, 'Homework', 30.00),
(6, 2, 'Tests', 40.00),
(7, 2, 'Projects', 30.00),
(8, 3, 'Homework', 35.00),
(9, 3, 'Quizzes', 25.00),
(10, 3, 'Exams', 40.00);

INSERT INTO assignments (assignment_id, course_id, category_id, assignment_name, max_points, due_date) VALUES
(1, 1, 1, 'Participation Week 1', 100.00, '2025-09-05'),
(2, 1, 1, 'Participation Week 2', 100.00, '2025-09-12'),
(3, 1, 2, 'Homework 1', 100.00, '2025-09-15'),
(4, 1, 2, 'Homework 2', 100.00, '2025-09-22'),
(5, 1, 2, 'Homework 3', 100.00, '2025-09-29'),
(6, 1, 3, 'Test 1', 100.00, '2025-10-10'),
(7, 1, 3, 'Test 2', 100.00, '2025-11-07'),
(8, 1, 4, 'Project 1', 100.00, '2025-10-25'),
(9, 1, 4, 'Project 2', 100.00, '2025-11-20'),
(10, 2, 5, 'DS Homework 1', 100.00, '2026-02-10'),
(11, 2, 6, 'DS Test 1', 100.00, '2026-03-01'),
(12, 2, 7, 'DS Project', 100.00, '2026-04-10'),
(13, 3, 8, 'DM Homework 1', 100.00, '2025-09-18'),
(14, 3, 9, 'DM Quiz 1', 100.00, '2025-09-25'),
(15, 3, 10, 'DM Midterm', 100.00, '2025-10-30');

INSERT INTO scores (score_id, assignment_id, student_id, score) VALUES
(1, 1, 1, 95.00),
(2, 1, 2, 88.00),
(3, 1, 3, 100.00),
(4, 1, 4, 84.00),
(5, 1, 5, 92.00),
(6, 1, 6, 97.00),
(7, 1, 7, 89.00),
(8, 2, 1, 96.00),
(9, 2, 2, 90.00),
(10, 2, 3, 98.00),
(11, 2, 4, 86.00),
(12, 2, 5, 94.00),
(13, 2, 6, 99.00),
(14, 2, 7, 91.00),
(15, 3, 1, 87.00),
(16, 3, 2, 76.00),
(17, 3, 3, 94.00),
(18, 3, 4, 83.00),
(19, 3, 5, 90.00),
(20, 3, 6, 88.00),
(21, 3, 7, 79.00),
(22, 4, 1, 93.00),
(23, 4, 2, 81.00),
(24, 4, 3, 97.00),
(25, 4, 4, 78.00),
(26, 4, 5, 88.00),
(27, 4, 6, 92.00),
(28, 4, 7, 85.00),
(29, 5, 1, 84.00),
(30, 5, 2, 74.00),
(31, 5, 3, 96.00),
(32, 5, 4, 82.00),
(33, 5, 5, 87.00),
(34, 5, 6, 91.00),
(35, 5, 7, 80.00),
(36, 6, 1, 91.00),
(37, 6, 2, 68.00),
(38, 6, 3, 98.00),
(39, 6, 4, 85.00),
(40, 6, 5, 93.00),
(41, 6, 6, 89.00),
(42, 6, 7, 77.00),
(43, 7, 1, 89.00),
(44, 7, 2, 72.00),
(45, 7, 3, 95.00),
(46, 7, 4, 80.00),
(47, 7, 5, 90.00),
(48, 7, 6, 86.00),
(49, 7, 7, 75.00),
(50, 8, 1, 94.00),
(51, 8, 2, 82.00),
(52, 8, 3, 99.00),
(53, 8, 4, 88.00),
(54, 8, 5, 91.00),
(55, 8, 6, 93.00),
(56, 8, 7, 84.00),
(57, 9, 1, 97.00),
(58, 9, 2, 85.00),
(59, 9, 3, 100.00),
(60, 9, 4, 87.00),
(61, 9, 5, 94.00),
(62, 9, 6, 98.00),
(63, 9, 7, 86.00),
(64, 10, 8, 88.00),
(65, 10, 9, 91.00),
(66, 10, 10, 84.00),
(67, 11, 8, 79.00),
(68, 11, 9, 93.00),
(69, 11, 10, 81.00),
(70, 12, 8, 90.00),
(71, 12, 9, 95.00),
(72, 12, 10, 87.00),
(73, 13, 1, 92.00),
(74, 13, 3, 96.00),
(75, 13, 5, 89.00),
(76, 13, 7, 85.00),
(77, 14, 1, 88.00),
(78, 14, 3, 94.00),
(79, 14, 5, 91.00),
(80, 14, 7, 83.00),
(81, 15, 1, 90.00),
(82, 15, 3, 97.00),
(83, 15, 5, 93.00),
(84, 15, 7, 86.00);

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
INSERT INTO assignments (course_id, category_id, assignment_name, max_points, due_date)
VALUES (@new_assignment_course_id, @new_assignment_category_id, 'Homework 4', 100.00, '2025-10-06');

SELECT *
FROM assignments
WHERE course_id = @new_assignment_course_id
ORDER BY assignment_id;

-- Task 8: change the percentages of the categories for a course
UPDATE categories
SET weight_percentage = CASE category_name
    WHEN 'Participation' THEN 15.00
    WHEN 'Homework' THEN 25.00
    WHEN 'Tests' THEN 40.00
    WHEN 'Projects' THEN 20.00
    ELSE weight_percentage
END
WHERE course_id = @course_id;

SELECT
    course_id,
    category_name,
    weight_percentage
FROM categories
WHERE course_id = @course_id
ORDER BY category_id;

-- Task 9: add 2 points to the score of each student on an assignment, capped at 100
UPDATE scores
SET score = LEAST(score + 2, 100)
WHERE assignment_id = @assignment_id;

SELECT
    assignment_id,
    student_id,
    score
FROM scores
WHERE assignment_id = @assignment_id
ORDER BY student_id;

-- Task 10: add 2 points just to those students whose last name contains a 'Q', capped at 100
UPDATE scores AS sc
JOIN students AS s
    ON s.student_id = sc.student_id
SET sc.score = LEAST(sc.score + 2, 100)
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
