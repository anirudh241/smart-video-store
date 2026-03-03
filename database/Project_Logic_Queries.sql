-- ==========================================================
--  PROJECT: Smart Video Rental System
--  MODULE: Database Schema Extensions & Recommendation Logic
-- ==========================================================

USE sakila;

-- ----------------------------------------------------------
-- 1. NOVELTY: Predictive Disc Health Schema Extensions
-- ----------------------------------------------------------
-- We modified the standard 'inventory' table to track physical asset health.
-- 'rental_count': Tracks usage frequency for predictive maintenance.
-- 'disc_condition': Enum status for asset lifecycle management.

/* NOTE: These columns were added via the following command:
   ALTER TABLE inventory
   ADD COLUMN rental_count INT DEFAULT 0,
   ADD COLUMN disc_condition ENUM('Good', 'Scratched', 'Needs Inspection') DEFAULT 'Good';
*/

-- ----------------------------------------------------------
-- 2. RATING SYSTEM: User Reviews Table
-- ----------------------------------------------------------
-- Stores customer sentiment to power the Collaborative Filtering Engine.

/*
   CREATE TABLE film_reviews (
       review_id INT AUTO_INCREMENT PRIMARY KEY,
       customer_id SMALLINT UNSIGNED NOT NULL,
       film_id SMALLINT UNSIGNED NOT NULL,
       rating_score TINYINT CHECK (rating_score BETWEEN 1 AND 5),
       review_text TEXT,
       review_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT fk_review_customer FOREIGN KEY (customer_id) REFERENCES customer (customer_id),
       CONSTRAINT fk_review_film FOREIGN KEY (film_id) REFERENCES film (film_id)
   );
*/

-- ----------------------------------------------------------
-- 3. THE RECOMMENDATION ENGINE ("Super Query")
-- ----------------------------------------------------------
-- This query implements a Hybrid Recommendation System.
-- Logic: User-Based Collaborative Filtering + Real-Time Inventory Availability Check.

-- PARAMETER: Target Customer ID (Change this to test different users)
SET @target_customer_id = 1;

WITH 
Target_User_Likes AS (
    -- Step A: Find what the target user likes
    SELECT film_id 
    FROM film_reviews 
    WHERE customer_id = @target_customer_id AND rating_score >= 4
),
Similar_Users AS (
    -- Step B: Find users with similar taste (User-Based CF)
    SELECT DISTINCT fr.customer_id
    FROM film_reviews fr
    JOIN Target_User_Likes tul ON fr.film_id = tul.film_id
    WHERE fr.customer_id != @target_customer_id AND fr.rating_score >= 4
),
Candidate_Movies AS (
    -- Step C: Find movies those similar users liked
    SELECT 
        fr.film_id,
        COUNT(fr.customer_id) AS recommendation_strength
    FROM film_reviews fr
    JOIN Similar_Users su ON fr.customer_id = su.customer_id
    WHERE fr.rating_score >= 4
    AND fr.film_id NOT IN (SELECT film_id FROM Target_User_Likes) -- Filter out already seen
    GROUP BY fr.film_id
)
-- Step D: The "Novel" Inventory & Health Check
SELECT 
    f.title AS "Recommended Movie",
    cm.recommendation_strength AS "Social Proof (Votes)",
    COUNT(i.inventory_id) AS "Available Discs",
    GROUP_CONCAT(DISTINCT i.disc_condition) AS "Disc Conditions"
FROM Candidate_Movies cm
JOIN film f ON cm.film_id = f.film_id
JOIN inventory i ON f.film_id = i.film_id
WHERE 
    -- FILTER 1: Exclude Damaged Assets (Predictive Maintenance)
    i.disc_condition != 'Needs Inspection'
    
    -- FILTER 2: Real-Time Availability (Inventory Check)
    AND i.inventory_id NOT IN (SELECT inventory_id FROM rental WHERE return_date IS NULL)
GROUP BY f.title, cm.recommendation_strength
ORDER BY cm.recommendation_strength DESC, "Available Discs" DESC
LIMIT 10;