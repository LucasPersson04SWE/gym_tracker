-- =========================
-- Gym Progress Tracker
-- =========================

CREATE DATABASE IF NOT EXISTS gym_tracker;
USE gym_tracker;

-- =========================
-- RESET DATABASE TABLES
-- =========================
DROP TABLE IF EXISTS WorkoutEntry;
DROP TABLE IF EXISTS WorkoutSession;
DROP TABLE IF EXISTS BodyMeasurement;
DROP TABLE IF EXISTS Goal;
DROP TABLE IF EXISTS Exercise;
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Users;

-- =========================
-- RESET TRIGGERS, PROCEDURE AND FUNCTION
-- =========================

DROP PROCEDURE IF EXISTS AddWorkoutEntry;
DROP TRIGGER IF EXISTS check_workout_entry;
DROP TRIGGER IF EXISTS ValidateBodyMeasurement;
DROP FUNCTION IF EXISTS get_session_volume;

-- =========================
-- TABLES
-- =========================

CREATE TABLE Users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    age INT
);

CREATE TABLE Exercise (
    exercise_id INT AUTO_INCREMENT PRIMARY KEY,
    exercise_name VARCHAR(100) NOT NULL,
    muscle_group VARCHAR(50),
    equipment_type VARCHAR(50)
);

CREATE TABLE WorkoutSession (
    session_id INT AUTO_INCREMENT PRIMARY KEY,
    session_date DATE NOT NULL,
    duration_minutes INT,
    notes TEXT,
    user_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE WorkoutEntry (
    entry_id INT AUTO_INCREMENT PRIMARY KEY,
    set_number INT NOT NULL,
    reps INT NOT NULL,
    weight DECIMAL(6,2) NOT NULL,
    rest_seconds INT,
    session_id INT NOT NULL,
    exercise_id INT NOT NULL,
    FOREIGN KEY (session_id) REFERENCES WorkoutSession(session_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    FOREIGN KEY (exercise_id) REFERENCES Exercise(exercise_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE BodyMeasurement (
    measurement_id INT AUTO_INCREMENT PRIMARY KEY,
    measurement_date DATE NOT NULL,
    body_weight DECIMAL(5,2),
    body_fat_percentage DECIMAL(4,2),
    user_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE Goal (
    goal_id INT AUTO_INCREMENT PRIMARY KEY,
    goal_type VARCHAR(50) NOT NULL,
    target_value DECIMAL(8,2) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    status VARCHAR(50) DEFAULT 'active',
    user_id INT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- =========================
-- SAMPLE DATA
-- =========================

INSERT INTO Users (name, email, age) VALUES
('Alex Smith', 'alex@test.com', 22),
('John Miller', 'john@test.com', 25);

INSERT INTO Exercise (exercise_name, muscle_group, equipment_type) VALUES
('Bench Press', 'Chest', 'Barbell'),
('Squat', 'Legs', 'Barbell'),
('Deadlift', 'Back', 'Barbell'),
('Lat Pulldown', 'Back', 'Machine'),
('Shoulder Press', 'Shoulders', 'Dumbbell');

INSERT INTO WorkoutSession (session_date, duration_minutes, notes, user_id) VALUES
('2026-04-20', 60, 'Push day', 1),
('2026-04-21', 70, 'Leg day', 1),
('2026-04-23', 75, 'Pull day', 1),
('2026-04-22', 55, 'Full body session', 2);

INSERT INTO WorkoutEntry (set_number, reps, weight, rest_seconds, session_id, exercise_id) VALUES
(1, 8, 80.00, 90, 1, 1),
(2, 8, 85.00, 90, 1, 1),
(3, 6, 90.00, 120, 1, 1),

(1, 5, 120.00, 120, 2, 2),
(2, 5, 125.00, 120, 2, 2),
(3, 4, 130.00, 150, 2, 2),

(1, 6, 140.00, 150, 3, 3),
(2, 5, 145.00, 150, 3, 3),
(1, 10, 65.00, 90, 3, 4),

(1, 10, 60.00, 90, 4, 1),
(1, 8, 100.00, 120, 4, 2);

INSERT INTO BodyMeasurement (measurement_date, body_weight, body_fat_percentage, user_id) VALUES
('2026-04-01', 92.00, 15.00, 1),
('2026-04-15', 91.00, 14.50, 1),
('2026-04-29', 90.50, 14.00, 1),
('2026-04-01', 84.00, 18.00, 2),
('2026-04-15', 83.50, 17.70, 2);

INSERT INTO Goal (goal_type, target_value, start_date, end_date, status, user_id) VALUES
('BodyWeight', 88.00, '2026-04-01', '2026-07-01', 'active', 1),
('BenchPress', 100.00, '2026-04-01', '2026-08-01', 'active', 1),
('Squat', 140.00, '2026-04-01', '2026-08-01', 'active', 2);

-- =========================
-- TRIGGER
-- Prevents invalid workout entries
-- =========================

DELIMITER //

CREATE TRIGGER check_workout_entry
BEFORE INSERT ON WorkoutEntry
FOR EACH ROW
BEGIN
    IF NEW.reps <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Reps must be greater than 0';
    END IF;

    IF NEW.weight < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Weight cannot be negative';
    END IF;
END //

DELIMITER ;

-- =========================
-- FUNCTION
-- Calculates total volume for one workout session
-- =========================

DELIMITER //

CREATE FUNCTION get_session_volume(p_session_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE total_volume DECIMAL(10,2);

    SELECT COALESCE(SUM(reps * weight), 0)
    INTO total_volume
    FROM WorkoutEntry
    WHERE session_id = p_session_id;

    RETURN total_volume;
END //

DELIMITER ;

-- =========================
-- REQUIRED 5 QUERIES
-- =========================

-- Query 1: User workout history
SELECT u.name, ws.session_date, ws.duration_minutes, ws.notes
FROM Users u
JOIN WorkoutSession ws ON u.user_id = ws.user_id
WHERE u.user_id = 1;

-- Query 2: Exercises in a workout session
SELECT e.exercise_name, we.set_number, we.reps, we.weight, we.rest_seconds
FROM WorkoutEntry we
JOIN Exercise e ON we.exercise_id = e.exercise_id
WHERE we.session_id = 1
ORDER BY e.exercise_name, we.set_number;

-- Query 3: Total training volume per exercise
SELECT e.exercise_name,
       SUM(we.reps * we.weight) AS total_volume
FROM WorkoutEntry we
JOIN Exercise e ON we.exercise_id = e.exercise_id
GROUP BY e.exercise_name
ORDER BY total_volume DESC;

-- Query 4: Personal record per exercise for one user
SELECT e.exercise_name,
       MAX(we.weight) AS max_weight
FROM WorkoutEntry we
JOIN Exercise e ON we.exercise_id = e.exercise_id
JOIN WorkoutSession ws ON we.session_id = ws.session_id
WHERE ws.user_id = 1
GROUP BY e.exercise_name
ORDER BY max_weight DESC;

-- Query 5: Average body weight per month
SELECT DATE_FORMAT(measurement_date, '%Y-%m') AS month,
       AVG(body_weight) AS avg_weight
FROM BodyMeasurement
WHERE user_id = 1
GROUP BY DATE_FORMAT(measurement_date, '%Y-%m')
ORDER BY month;

-- ========================================
-- STORED PROCEDURE: AddWorkoutEntry
-- ========================================
-- This procedure adds a workout entry with validation
-- It ensures that the exercise exists and weight/reps are valid
 
DELIMITER //
 
CREATE PROCEDURE AddWorkoutEntry(
    IN p_session_id INT,
    IN p_exercise_id INT,
    IN p_set_number INT,
    IN p_reps INT,
    IN p_weight DECIMAL(5,2),
    IN p_rest_seconds INT,
    OUT p_success BOOLEAN,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE exercise_exists INT;
    DECLARE session_exists INT;
    
    -- Check if exercise exists
    SELECT COUNT(*) INTO exercise_exists 
    FROM Exercise 
    WHERE exercise_id = p_exercise_id;
    
    -- Check if session exists
    SELECT COUNT(*) INTO session_exists 
    FROM WorkoutSession 
    WHERE session_id = p_session_id;
    
    -- Validate inputs
    IF exercise_exists = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'Exercise does not exist';
    ELSEIF session_exists = 0 THEN
        SET p_success = FALSE;
        SET p_message = 'Workout session does not exist';
    ELSEIF p_reps <= 0 THEN
        SET p_success = FALSE;
        SET p_message = 'Reps must be greater than 0';
    ELSEIF p_weight < 0 THEN
        SET p_success = FALSE;
        SET p_message = 'Weight cannot be negative';
    ELSE
        -- Insert the workout entry
        INSERT INTO WorkoutEntry 
        (set_number, reps, weight, rest_seconds, session_id, exercise_id)
        VALUES (p_set_number, p_reps, p_weight, p_rest_seconds, p_session_id, p_exercise_id);
        
        SET p_success = TRUE;
        SET p_message = 'Workout entry added successfully';
    END IF;
END//
 
DELIMITER ;
 
 
-- ========================================
-- TRIGGER: ValidateBodyMeasurement
-- ========================================
-- This trigger validates that body weight and body fat percentage 
-- are within reasonable ranges before insertion
 
DELIMITER //
 
CREATE TRIGGER ValidateBodyMeasurement
BEFORE INSERT ON BodyMeasurement
FOR EACH ROW
BEGIN
    -- Check if body weight is realistic (between 20 kg and 300 kg)
    IF NEW.body_weight < 20 OR NEW.body_weight > 300 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Body weight must be between 20 and 300 kg';
    END IF;
    
    -- Check if body fat percentage is between 0 and 100
    IF NEW.body_fat_percentage < 0 OR NEW.body_fat_percentage > 100 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Body fat percentage must be between 0 and 100';
    END IF;
    
    -- Auto-set measurement_date to current date if not provided
    IF NEW.measurement_date IS NULL THEN
        SET NEW.measurement_date = CURDATE();
    END IF;
END//
 
DELIMITER ;