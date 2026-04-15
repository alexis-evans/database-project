-- Rebuild the database from scratch.
DROP DATABASE IF EXISTS gradebook_project;
CREATE DATABASE gradebook_project;
USE gradebook_project;

-- Drop in reverse dependency order so foreign keys don't block the drops.
DROP TABLE IF EXISTS scores;
DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS enrollments;
DROP TABLE IF EXISTS students;
DROP TABLE IF EXISTS courses;

-- One row per person; email is the natural unique identifier across the system.
CREATE TABLE students (
    student_id INT PRIMARY KEY AUTO_INCREMENT,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
);

-- uq_course_offering prevents the same course from being listed twice in the
-- same semester/year (e.g. two "CS 101 Fall 2025" rows).
CREATE TABLE courses (
    course_id INT PRIMARY KEY AUTO_INCREMENT,
    department VARCHAR(10) NOT NULL,
    course_number VARCHAR(10) NOT NULL,
    course_name VARCHAR(100) NOT NULL,
    semester VARCHAR(20) NOT NULL,
    year INT NOT NULL,
    UNIQUE KEY uq_course_offering (department, course_number, semester, year)
);

-- Junction table linking students to courses.
-- uq_enrollment prevents a student from being enrolled in the same course twice.
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

-- Each category (Homework, Tests, etc.) belongs to exactly one course.
-- uq_course_category_name prevents duplicate category names within a course.
-- uq_course_category_id exposes (course_id, category_id) as a unique key so
-- assignments can reference it with a composite foreign key, enforcing that an
-- assignment's category belongs to the same course.
-- The trigger trg_categories_before_insert enforces the cross-row rule that
-- weights cannot exceed 100; assert_course_weights_total_100 checks exactly 100.
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

-- course_id is stored here (not just derived from category) for two reasons:
--   1. The composite FK (course_id, category_id) -> categories guarantees the
--      assignment's category actually belongs to this course.
--   2. uq_assignment_course exposes (assignment_id, course_id) as a unique key
--      so scores can reference it with a composite FK.
CREATE TABLE assignments (
    assignment_id INT PRIMARY KEY AUTO_INCREMENT,
    course_id INT NOT NULL,
    category_id INT NOT NULL,
    assignment_name VARCHAR(100) NOT NULL,
    max_points DECIMAL(7,2) NOT NULL DEFAULT 100,
    due_date DATE NULL,
    CONSTRAINT fk_assignment_course
        FOREIGN KEY (course_id) REFERENCES courses(course_id),
    -- Composite FK ensures the category belongs to the same course as the assignment.
    CONSTRAINT fk_assignment_course_category
        FOREIGN KEY (course_id, category_id)
        REFERENCES categories(course_id, category_id),
    CONSTRAINT uq_assignment_name_in_course UNIQUE KEY (course_id, assignment_name),
    -- Needed so scores can reference (assignment_id, course_id) as a composite FK.
    CONSTRAINT uq_assignment_course UNIQUE KEY (assignment_id, course_id),
    CONSTRAINT chk_assignment_max_points
        CHECK (max_points > 0)
);

-- course_id is stored here so two composite FKs can enforce both rules at the
-- database level without triggers or application code:
--   fk_score_enrollment:       (student_id, course_id) must exist in enrollments
--                               -> a score can only be recorded for an enrolled student
--   fk_score_assignment_course: (assignment_id, course_id) must exist in assignments
--                               -> score must belong to the same course as the assignment
-- The trigger trg_scores_before_insert/update also validates score <= max_points.
CREATE TABLE scores (
    score_id INT PRIMARY KEY AUTO_INCREMENT,
    assignment_id INT NOT NULL,
    student_id INT NOT NULL,
    course_id INT NOT NULL,
    score DECIMAL(7,2) NOT NULL,
    CONSTRAINT fk_score_assignment_course
        FOREIGN KEY (assignment_id, course_id)
        REFERENCES assignments(assignment_id, course_id),
    CONSTRAINT fk_score_enrollment
        FOREIGN KEY (student_id, course_id)
        REFERENCES enrollments(student_id, course_id),
    CONSTRAINT uq_student_assignment UNIQUE KEY (student_id, assignment_id),
    CONSTRAINT chk_score_nonnegative
        CHECK (score >= 0)
);

DELIMITER $$

-- Validates that a course's category weights sum to exactly 100.
-- Called explicitly before grade computation and after category weight changes.
-- MySQL cannot enforce a cross-row sum with a simple CHECK constraint, so this
-- procedure acts as the exact-100 gate; the triggers below prevent exceeding 100.
CREATE PROCEDURE assert_course_weights_total_100(IN p_course_id INT)
BEGIN
    DECLARE total_weight DECIMAL(7,2);
    DECLARE category_count INT;

    SELECT COUNT(*), COALESCE(SUM(weight_percentage), 0)
    INTO category_count, total_weight
    FROM categories
    WHERE course_id = p_course_id;

    IF category_count = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Each course must define at least one grading category.';
    END IF;

    IF total_weight <> 100.00 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Category percentages for a course must total exactly 100.';
    END IF;
END$$

-- Prevents a new category from pushing the course total above 100.
-- This allows categories to be inserted one at a time during setup while still
-- keeping the running total safe.
CREATE TRIGGER trg_categories_before_insert
BEFORE INSERT ON categories
FOR EACH ROW
BEGIN
    DECLARE projected_total DECIMAL(7,2);

    SELECT COALESCE(SUM(weight_percentage), 0) + NEW.weight_percentage
    INTO projected_total
    FROM categories
    WHERE course_id = NEW.course_id;

    IF projected_total > 100.00 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Category percentages for a course cannot exceed 100.';
    END IF;
END$$

-- Prevents an update from pushing the course total above 100 and blocks
-- moving a category to a different course after creation.
-- Task 8 zeroes all weights before applying new ones so this trigger does not
-- block valid redistributions mid-update.
CREATE TRIGGER trg_categories_before_update
BEFORE UPDATE ON categories
FOR EACH ROW
BEGIN
    DECLARE projected_total DECIMAL(7,2);

    -- Subtract the old weight and add the new one to get the projected total.
    SELECT COALESCE(SUM(weight_percentage), 0) - OLD.weight_percentage + NEW.weight_percentage
    INTO projected_total
    FROM categories
    WHERE course_id = OLD.course_id;

    IF NEW.course_id <> OLD.course_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Categories cannot be moved to another course after creation.';
    END IF;

    IF projected_total > 100.00 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Category percentages for a course cannot exceed 100.';
    END IF;
END$$

-- Prevents inserting a score that exceeds the assignment's max_points.
-- A NULL result from the lookup means course_id does not match the assignment.
CREATE TRIGGER trg_scores_before_insert
BEFORE INSERT ON scores
FOR EACH ROW
BEGIN
    DECLARE assignment_max_points DECIMAL(7,2);

    SELECT max_points
    INTO assignment_max_points
    FROM assignments
    WHERE assignment_id = NEW.assignment_id
      AND course_id = NEW.course_id;

    IF assignment_max_points IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Score course_id must match the assignment course.';
    END IF;

    IF NEW.score > assignment_max_points THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Score cannot be greater than the assignment max_points.';
    END IF;
END$$

-- Same cap check on updates (e.g. bulk +2 point adjustments in Tasks 9/10).
CREATE TRIGGER trg_scores_before_update
BEFORE UPDATE ON scores
FOR EACH ROW
BEGIN
    DECLARE assignment_max_points DECIMAL(7,2);

    SELECT max_points
    INTO assignment_max_points
    FROM assignments
    WHERE assignment_id = NEW.assignment_id
      AND course_id = NEW.course_id;

    IF assignment_max_points IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Score course_id must match the assignment course.';
    END IF;

    IF NEW.score > assignment_max_points THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Score cannot be greater than the assignment max_points.';
    END IF;
END$$

DELIMITER ;
