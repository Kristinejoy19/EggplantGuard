-- ============================================================================
-- EggplantGuard Database Schema for MySQL / MariaDB
-- System: AI-Assisted Eggplant Crop Screening & Fruit Quality Management
-- Compatible with: MySQL 5.7+, MySQL 8.0+, MariaDB 10.3+ (XAMPP / Laragon / Cloud)
-- ============================================================================

SET FOREIGN_KEY_CHECKS = 0;
DROP DATABASE IF EXISTS `eggplantguard`;
CREATE DATABASE `eggplantguard`
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE `eggplantguard`;

-- ----------------------------------------------------------------------------
-- Table 1: users
-- Farmers, agronomists/technicians, researchers, and administrators.
-- ----------------------------------------------------------------------------
CREATE TABLE `users` (
  `user_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `username` VARCHAR(50) NOT NULL UNIQUE,
  `email` VARCHAR(100) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `full_name` VARCHAR(100) NOT NULL,
  `role` ENUM('admin', 'technician', 'farmer', 'researcher') NOT NULL DEFAULT 'farmer',
  `phone_number` VARCHAR(20) NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_users_role` (`role`),
  INDEX `idx_users_active` (`is_active`)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 2: farms
-- Farms or eggplant field plots monitored by users.
-- ----------------------------------------------------------------------------
CREATE TABLE `farms` (
  `farm_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NOT NULL,
  `farm_name` VARCHAR(120) NOT NULL,
  `location` VARCHAR(255) NULL,
  `eggplant_variety` VARCHAR(100) NULL COMMENT 'e.g. Long Purple, Black Beauty, Round Green',
  `area_sqm` DECIMAL(10,2) NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_farms_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX `idx_farms_user` (`user_id`)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 3: ai_models
-- Tracks trained AI models (e.g. Google Teachable Machine / TensorFlow.js).
-- ----------------------------------------------------------------------------
CREATE TABLE `ai_models` (
  `model_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `model_name` VARCHAR(100) NOT NULL,
  `model_url` VARCHAR(255) NOT NULL,
  `framework` VARCHAR(50) NOT NULL DEFAULT 'TensorFlow.js / Teachable Machine',
  `input_size` SMALLINT UNSIGNED NOT NULL DEFAULT 224,
  `confidence_threshold` DECIMAL(3,2) NOT NULL DEFAULT 0.70 COMMENT 'Minimum confidence to accept sample',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `notes` TEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_models_active` (`is_active`)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 4: diagnostic_categories
-- The official recognized eggplant conditions, fruit quality states & invalid state.
-- ----------------------------------------------------------------------------
CREATE TABLE `diagnostic_categories` (
  `category_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `category_name` VARCHAR(100) NOT NULL UNIQUE,
  `category_type` ENUM('leaf', 'fruit', 'invalid') NOT NULL,
  `icon` VARCHAR(10) NOT NULL DEFAULT '🍆',
  `severity_level` ENUM('none', 'low', 'moderate', 'high', 'invalid') NOT NULL DEFAULT 'none',
  `description` TEXT NOT NULL,
  `symptoms` TEXT NULL,
  `recommended_action` TEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 5: scans
-- Record of each leaf or fruit scan performed through upload or camera.
-- ----------------------------------------------------------------------------
CREATE TABLE `scans` (
  `scan_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT UNSIGNED NULL COMMENT 'NULL for guest/anonymous scans',
  `farm_id` INT UNSIGNED NULL,
  `model_id` INT UNSIGNED NOT NULL,
  `predicted_category_id` INT UNSIGNED NULL,
  `input_method` ENUM('upload', 'camera') NOT NULL DEFAULT 'upload',
  `image_filename` VARCHAR(255) NULL,
  `image_url` VARCHAR(500) NULL,
  `top_prediction_label` VARCHAR(100) NOT NULL,
  `confidence_score` DECIMAL(5,4) NOT NULL COMMENT 'Confidence score between 0.0000 and 1.0000',
  `is_valid_eggplant` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '0 = Invalid/Not Eggplant, 1 = Valid Eggplant',
  `invalidation_reason` VARCHAR(255) NULL COMMENT 'Reason if rejected: low confidence, non-eggplant features',
  `status` ENUM('screened', 'flagged_for_review', 'verified_by_expert') NOT NULL DEFAULT 'screened',
  `scanned_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_scans_user`
    FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_scans_farm`
    FOREIGN KEY (`farm_id`) REFERENCES `farms` (`farm_id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_scans_model`
    FOREIGN KEY (`model_id`) REFERENCES `ai_models` (`model_id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_scans_category`
    FOREIGN KEY (`predicted_category_id`) REFERENCES `diagnostic_categories` (`category_id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  INDEX `idx_scans_user` (`user_id`),
  INDEX `idx_scans_valid` (`is_valid_eggplant`),
  INDEX `idx_scans_date` (`scanned_at`),
  INDEX `idx_scans_status` (`status`)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 6: scan_predictions
-- Multi-class probability breakdown for every scan.
-- ----------------------------------------------------------------------------
CREATE TABLE `scan_predictions` (
  `prediction_id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `scan_id` INT UNSIGNED NOT NULL,
  `class_name` VARCHAR(100) NOT NULL,
  `probability` DECIMAL(5,4) NOT NULL,
  `rank_order` TINYINT UNSIGNED NOT NULL COMMENT '1 = top prediction, 2 = runner up, etc.',
  CONSTRAINT `fk_predictions_scan`
    FOREIGN KEY (`scan_id`) REFERENCES `scans` (`scan_id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX `idx_predictions_scan` (`scan_id`),
  INDEX `idx_predictions_rank` (`scan_id`, `rank_order`)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 7: expert_reviews
-- Human-in-the-loop expert validation by agricultural technicians / agronomists.
-- ----------------------------------------------------------------------------
CREATE TABLE `expert_reviews` (
  `review_id` INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `scan_id` INT UNSIGNED NOT NULL UNIQUE,
  `reviewer_id` INT UNSIGNED NOT NULL,
  `confirmed_category_id` INT UNSIGNED NOT NULL,
  `agreed_with_ai` TINYINT(1) NOT NULL,
  `expert_notes` TEXT NULL,
  `recommended_treatment` TEXT NULL,
  `reviewed_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `fk_reviews_scan`
    FOREIGN KEY (`scan_id`) REFERENCES `scans` (`scan_id`)
    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_reviews_reviewer`
    FOREIGN KEY (`reviewer_id`) REFERENCES `users` (`user_id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_reviews_category`
    FOREIGN KEY (`confirmed_category_id`) REFERENCES `diagnostic_categories` (`category_id`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX `idx_reviews_agreement` (`agreed_with_ai`)
) ENGINE=InnoDB;

-- ----------------------------------------------------------------------------
-- Table 8: system_settings
-- System-level configuration, thresholds, and operational flags.
-- ----------------------------------------------------------------------------
CREATE TABLE `system_settings` (
  `setting_key` VARCHAR(50) PRIMARY KEY,
  `setting_value` TEXT NOT NULL,
  `value_type` ENUM('string', 'number', 'boolean', 'json') NOT NULL DEFAULT 'string',
  `description` VARCHAR(255) NULL,
  `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- 1. Insert Diagnostic Categories (Matching EggplantGuard App)
INSERT INTO `diagnostic_categories`
  (`category_id`, `category_name`, `category_type`, `icon`, `severity_level`, `description`, `symptoms`, `recommended_action`)
VALUES
  (1, 'Healthy Leaf', 'leaf', '🌿', 'none',
   'The image most closely matches healthy leaf examples with uniform green pigmentation.',
   'Smooth foliage, uniform green color, no pest puncture tunnels or discolored spots.',
   'Continue routine crop monitoring. Maintain consistent watering schedule, proper soil drainage, and field sanitation. This prediction is an educational screening result.'),

  (2, 'Leaf Miner Damage', 'leaf', '🍃', 'moderate',
   'The image closely matches leaf-miner damage characterized by serpentine tunnels caused by larvae.',
   'White to grayish winding, serpentine trails on the leaf surface, premature leaf yellowing or drying.',
   'Inspect nearby foliage for winding trails. Prune heavily infested leaves and dispose of them away from the field. Introduce natural predators or consult a local agricultural technician.'),

  (3, 'Fresh/Market-Ready Fruit', 'fruit', '🍆', 'none',
   'The image most closely matches fresh, well-developed market-ready eggplant fruit.',
   'Glossy, taut skin, firm flesh, uniform color typical of the eggplant variety, free of borer holes or soft rot.',
   'Harvest during cool morning hours. Handle gently using clean shears to prevent skin abrasions. Store at 10-12°C with high humidity to maintain freshness.'),

  (4, 'Damaged/Borer-Infested Fruit', 'fruit', '⚠️', 'high',
   'The image matches fruit exhibiting insect boreholes, frass, internal feeding damage, or rotting spots.',
   'Entry/exit holes, brownish granular insect excrement (frass) near the calyx or fruit body, deformed or rotting fruit.',
   'Isolate and remove infested fruits immediately to break pest life cycle. Inspect shoot tips for wilting. Consult agricultural extension officers regarding integrated pest management.'),

  (5, 'Invalid: Not an Eggplant', 'invalid', '🚫', 'invalid',
   'The sample could not be verified as an eggplant leaf or fruit sample.',
   'Sample lacks typical eggplant leaf or fruit characteristics, has low classification confidence (< 70%), or shows unrelated objects.',
   'Provide a clear, well-lit close-up photograph focusing directly on an eggplant leaf or fruit without busy background clutter.');

-- 2. Insert Active Teachable Machine Model
INSERT INTO `ai_models`
  (`model_id`, `model_name`, `model_url`, `framework`, `input_size`, `confidence_threshold`, `is_active`, `notes`)
VALUES
  (1, 'EggplantGuard Teachable Machine Classifier',
   'https://teachablemachine.withgoogle.com/models/jq8kSVI_-/',
   'TensorFlow.js / Teachable Machine', 224, 0.70, 1,
   '4-class eggplant model trained on healthy leaf, leaf miner, fresh fruit, and borer-damaged fruit.');

-- 3. Insert Default Users (Admin, Technician, Farmer)
INSERT INTO `users`
  (`user_id`, `username`, `email`, `password_hash`, `full_name`, `role`, `phone_number`)
VALUES
  (1, 'admin', 'admin@eggplantguard.local', '$2y$12$e8w.b0n4cR/9ZlQ5sQ4eGeGqZ2xK6X6k8P4cW7Y1M5q9x0L1v9G1e', 'System Administrator', 'admin', '+639170000001'),
  (2, 'agritech_maria', 'maria.santos@da.gov.ph', '$2y$12$e8w.b0n4cR/9ZlQ5sQ4eGeGqZ2xK6X6k8P4cW7Y1M5q9x0L1v9G1e', 'Engr. Maria Santos', 'technician', '+639170000002'),
  (3, 'farmer_juan', 'juan.delacruz@farmer.ph', '$2y$12$e8w.b0n4cR/9ZlQ5sQ4eGeGqZ2xK6X6k8P4cW7Y1M5q9x0L1v9G1e', 'Juan Dela Cruz', 'farmer', '+639170000003');

-- 4. Insert Sample Farm
INSERT INTO `farms`
  (`farm_id`, `user_id`, `farm_name`, `location`, `eggplant_variety`, `area_sqm`)
VALUES
  (1, 3, 'Barangay San Jose Eggplant Field', 'San Jose, Batangas, Philippines', 'Long Purple (Dumaguete Express)', 2500.00);

-- 5. Insert System Settings
INSERT INTO `system_settings` (`setting_key`, `setting_value`, `value_type`, `description`)
VALUES
  ('CONFIDENCE_THRESHOLD', '0.70', 'number', 'Minimum model confidence score required to accept sample as valid eggplant'),
  ('APP_NAME', 'EggplantGuard', 'string', 'Application brand name'),
  ('ENABLE_CAMERA_INPUT', 'true', 'boolean', 'Allow webcam/mobile camera capture in screening UI'),
  ('ACTIVE_MODEL_ID', '1', 'number', 'Currently active AI model ID');

-- 6. Insert Sample Scans Demonstrating Valid and Invalid Outcomes
INSERT INTO `scans`
  (`scan_id`, `user_id`, `farm_id`, `model_id`, `predicted_category_id`, `input_method`, `image_filename`, `top_prediction_label`, `confidence_score`, `is_valid_eggplant`, `invalidation_reason`, `status`)
VALUES
  (1, 3, 1, 1, 1, 'upload', 'sample_leaf_01.jpg', 'Healthy Leaf', 0.9450, 1, NULL, 'screened'),
  (2, 3, 1, 1, 2, 'camera', 'sample_miner_02.jpg', 'Leaf Miner Damage', 0.8875, 1, NULL, 'screened'),
  (3, 3, 1, 1, 3, 'upload', 'sample_fresh_fruit.jpg', 'Fresh/Market-Ready Fruit', 0.9620, 1, NULL, 'verified_by_expert'),
  (4, 3, 1, 1, 4, 'upload', 'sample_borer_fruit.jpg', 'Damaged/Borer-Infested Fruit', 0.8410, 1, NULL, 'flagged_for_review'),
  (5, NULL, NULL, 1, 5, 'upload', 'random_desk_item.jpg', 'Healthy Leaf', 0.4210, 0, 'Confidence is too low (42.1% < 70%) to confirm this is an eggplant.', 'screened');

-- 7. Insert Prediction Probabilities for Sample Scans
INSERT INTO `scan_predictions` (`scan_id`, `class_name`, `probability`, `rank_order`) VALUES
  (1, 'Healthy Leaf', 0.9450, 1),
  (1, 'Leaf Miner Damage', 0.0380, 2),
  (1, 'Fresh/Market-Ready Fruit', 0.0110, 3),
  (1, 'Damaged/Borer-Infested Fruit', 0.0060, 4),

  (5, 'Healthy Leaf', 0.4210, 1),
  (5, 'Fresh/Market-Ready Fruit', 0.2840, 2),
  (5, 'Leaf Miner Damage', 0.1730, 3),
  (5, 'Damaged/Borer-Infested Fruit', 0.1220, 4);

-- 8. Insert Sample Expert Review
INSERT INTO `expert_reviews`
  (`scan_id`, `reviewer_id`, `confirmed_category_id`, `agreed_with_ai`, `expert_notes`, `recommended_treatment`)
VALUES
  (3, 2, 3, 1, 'Confirmed prime harvest grade fruit. Flesh is firm with healthy calyx attachment.', 'Proceed with scheduled harvest and packing.');

-- ============================================================================
-- USEFUL REPORTING VIEWS
-- ============================================================================

-- View 1: Complete Scan Overview
CREATE OR REPLACE VIEW `v_scan_overview` AS
SELECT
  s.scan_id,
  s.scanned_at,
  s.input_method,
  s.top_prediction_label,
  ROUND(s.confidence_score * 100, 2) AS confidence_pct,
  CASE WHEN s.is_valid_eggplant = 1 THEN 'Valid Eggplant' ELSE 'Invalid Sample' END AS sample_status,
  s.invalidation_reason,
  c.category_name,
  c.icon,
  c.severity_level,
  u.full_name AS scanned_by,
  u.role AS user_role,
  f.farm_name,
  f.eggplant_variety,
  er.agreed_with_ai AS expert_verified
FROM scans s
LEFT JOIN diagnostic_categories c ON s.predicted_category_id = c.category_id
LEFT JOIN users u ON s.user_id = u.user_id
LEFT JOIN farms f ON s.farm_id = f.farm_id
LEFT JOIN expert_reviews er ON s.scan_id = er.scan_id;

-- View 2: Classification Accuracy & Agreement Summary
CREATE OR REPLACE VIEW `v_expert_agreement_stats` AS
SELECT
  c.category_name,
  COUNT(er.review_id) AS total_reviewed,
  SUM(CASE WHEN er.agreed_with_ai = 1 THEN 1 ELSE 0 END) AS agreed_count,
  ROUND(SUM(CASE WHEN er.agreed_with_ai = 1 THEN 1 ELSE 0 END) / COUNT(er.review_id) * 100, 2) AS agreement_rate_pct
FROM expert_reviews er
JOIN diagnostic_categories c ON er.confirmed_category_id = c.category_id
GROUP BY c.category_name;

