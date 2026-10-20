-- ============================================================================
-- FlashDrop: Master Installation Script
-- Run this file to initialize the complete database from scratch
-- ============================================================================

SELECT '>>> Initializing FlashDrop Database Schema...' AS step;
SOURCE 01_schema.sql;

SELECT '>>> Loading Initial Seed Data...' AS step;
SOURCE 02_seed_data.sql;

SELECT '>>> Installing ACID Stored Procedures...' AS step;
SOURCE 03_procedures.sql;

SELECT '>>> Configuring Database Triggers...' AS step;
SOURCE 04_triggers.sql;

SELECT '>>> Enabling Scheduled Background Events...' AS step;
SOURCE 05_events.sql;

SELECT '>>> Creating Views and Performance Indexes...' AS step;
SOURCE 06_views_indexes.sql;

SELECT '>>> FlashDrop Database Engine Initialization Complete!' AS status;
