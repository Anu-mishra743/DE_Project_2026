-- =====================================================================
-- Housing.com Property Search Database Schema
-- Checkpoint 1 (CP1) Deliverable: sql/01_schema.sql
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS housing;
SET search_path TO housing;

-- Drop tables in reverse dependency order for idempotent execution
DROP TABLE IF EXISTS shortlists CASCADE;
DROP TABLE IF EXISTS site_visits CASCADE;
DROP TABLE IF EXISTS enquiries CASCADE;
DROP TABLE IF EXISTS price_changes CASCADE;
DROP TABLE IF EXISTS properties CASCADE;
DROP TABLE IF EXISTS project_amenities CASCADE;
DROP TABLE IF EXISTS amenities CASCADE;
DROP TABLE IF EXISTS projects CASCADE;
DROP TABLE IF EXISTS builders CASCADE;
DROP TABLE IF EXISTS localities CASCADE;
DROP TABLE IF EXISTS cities CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ---------------------------------------------------------------------
-- 1. cities
-- Reference table of major metropolitan cities covered by Housing.com
-- ---------------------------------------------------------------------
CREATE TABLE cities (
    city_id         INT PRIMARY KEY,
    city_name       VARCHAR(100) NOT NULL UNIQUE,
    state           VARCHAR(100) NOT NULL
);

-- ---------------------------------------------------------------------
-- 2. localities
-- Neighborhoods/sub-localities within each city with spatial center
-- ---------------------------------------------------------------------
CREATE TABLE localities (
    locality_id     INT PRIMARY KEY,
    city_id         INT NOT NULL REFERENCES cities(city_id) ON DELETE RESTRICT,
    locality_name   VARCHAR(100) NOT NULL,
    pincode         VARCHAR(6) NOT NULL CHECK (pincode ~ '^[0-9]{6}$'),
    center_lat      NUMERIC(9,6) NOT NULL CHECK (center_lat BETWEEN -90 AND 90),
    center_lng      NUMERIC(9,6) NOT NULL CHECK (center_lng BETWEEN -180 AND 180),
    CONSTRAINT uq_localities_city_name UNIQUE (city_id, locality_name)
);

-- ---------------------------------------------------------------------
-- 3. builders
-- Real estate developers/construction firms
-- ---------------------------------------------------------------------
CREATE TABLE builders (
    builder_id      INT PRIMARY KEY,
    builder_name    VARCHAR(150) NOT NULL UNIQUE,
    founded_year    INT NOT NULL CHECK (founded_year >= 1800 AND founded_year <= 2100)
);

-- ---------------------------------------------------------------------
-- 4. projects
-- Residential real estate developments/societies
-- ---------------------------------------------------------------------
CREATE TABLE projects (
    project_id          INT PRIMARY KEY,
    builder_id          INT NOT NULL REFERENCES builders(builder_id) ON DELETE RESTRICT,
    locality_id         INT NOT NULL REFERENCES localities(locality_id) ON DELETE RESTRICT,
    project_name        VARCHAR(150) NOT NULL,
    rera_id             VARCHAR(50),
    possession_status   VARCHAR(20) NOT NULL CHECK (possession_status IN ('READY_TO_MOVE', 'UNDER_CONSTRUCTION')),
    possession_date     DATE NOT NULL,
    total_units         INT NOT NULL CHECK (total_units > 0)
);

-- ---------------------------------------------------------------------
-- 5. amenities
-- Standard master list of housing/society amenities
-- ---------------------------------------------------------------------
CREATE TABLE amenities (
    amenity_id      INT PRIMARY KEY,
    amenity_name    VARCHAR(100) NOT NULL UNIQUE
);

-- ---------------------------------------------------------------------
-- 6. project_amenities
-- Junction table: amenities provided by residential projects (M:N)
-- ---------------------------------------------------------------------
CREATE TABLE project_amenities (
    project_id      INT NOT NULL REFERENCES projects(project_id) ON DELETE CASCADE,
    amenity_id      INT NOT NULL REFERENCES amenities(amenity_id) ON DELETE RESTRICT,
    PRIMARY KEY (project_id, amenity_id)
);

-- ---------------------------------------------------------------------
-- 7. users
-- Registered platform actors: Seekers, Owners, and Real Estate Agents
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id         INT PRIMARY KEY,
    full_name       VARCHAR(150) NOT NULL,
    phone           VARCHAR(15) NOT NULL UNIQUE CHECK (phone ~ '^[0-9]{10}$'),
    email           VARCHAR(150) UNIQUE,
    user_type       VARCHAR(10) NOT NULL CHECK (user_type IN ('SEEKER', 'OWNER', 'AGENT')),
    agent_rera_id   VARCHAR(50),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 8. properties
-- Core real estate inventory: sale and rent listings
-- ---------------------------------------------------------------------
CREATE TABLE properties (
    property_id         INT PRIMARY KEY,
    listed_by           INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    project_id          INT REFERENCES projects(project_id) ON DELETE SET NULL,
    locality_id         INT NOT NULL REFERENCES localities(locality_id) ON DELETE RESTRICT,
    listing_type        VARCHAR(10) NOT NULL CHECK (listing_type IN ('RENT', 'SALE')),
    property_type       VARCHAR(20) NOT NULL CHECK (property_type IN ('APARTMENT', 'INDEPENDENT_HOUSE', 'PLOT', 'VILLA')),
    bhk                 SMALLINT CHECK (bhk IS NULL OR bhk > 0),
    carpet_area_sqft    NUMERIC(10,2) NOT NULL CHECK (carpet_area_sqft > 0),
    floor_no            SMALLINT,
    total_floors        SMALLINT CHECK (total_floors IS NULL OR total_floors >= 0),
    furnishing          VARCHAR(20) CHECK (furnishing IS NULL OR furnishing IN ('UNFURNISHED', 'SEMI_FURNISHED', 'FULLY_FURNISHED')),
    facing              VARCHAR(20) NOT NULL CHECK (facing IN ('EAST', 'NORTH', 'NORTH_EAST', 'NORTH_WEST', 'SOUTH', 'SOUTH_EAST', 'SOUTH_WEST', 'WEST')),
    price               NUMERIC(12,2) NOT NULL CHECK (price > 0),
    maintenance_monthly NUMERIC(10,2) CHECK (maintenance_monthly IS NULL OR maintenance_monthly >= 0),
    security_deposit    NUMERIC(12,2) CHECK (security_deposit IS NULL OR security_deposit >= 0),
    available_from      DATE NOT NULL,
    latitude            NUMERIC(9,6) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
    longitude           NUMERIC(9,6) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
    is_verified         BOOLEAN NOT NULL DEFAULT FALSE,
    status              VARCHAR(10) NOT NULL CHECK (status IN ('ACTIVE', 'INACTIVE', 'RENTED', 'SOLD')),
    posted_at           TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_properties_floors CHECK (floor_no IS NULL OR total_floors IS NULL OR floor_no <= total_floors)
);

-- ---------------------------------------------------------------------
-- 9. price_changes
-- Audit log of property listing price adjustments over time
-- ---------------------------------------------------------------------
CREATE TABLE price_changes (
    change_id       INT PRIMARY KEY,
    property_id     INT NOT NULL REFERENCES properties(property_id) ON DELETE CASCADE,
    old_price       NUMERIC(12,2) NOT NULL CHECK (old_price > 0),
    new_price       NUMERIC(12,2) NOT NULL CHECK (new_price > 0),
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_price_change_diff CHECK (old_price <> new_price)
);

-- ---------------------------------------------------------------------
-- 10. enquiries
-- User inquiries/leads sent to property listers
-- ---------------------------------------------------------------------
CREATE TABLE enquiries (
    enquiry_id      INT PRIMARY KEY,
    property_id     INT NOT NULL REFERENCES properties(property_id) ON DELETE CASCADE,
    user_id         INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    channel         VARCHAR(10) NOT NULL CHECK (channel IN ('CALL', 'FORM', 'WHATSAPP')),
    message         TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 11. site_visits
-- Physical appointments scheduled by users to view properties
-- ---------------------------------------------------------------------
CREATE TABLE site_visits (
    visit_id        INT PRIMARY KEY,
    property_id     INT NOT NULL REFERENCES properties(property_id) ON DELETE CASCADE,
    user_id         INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    scheduled_at    TIMESTAMPTZ NOT NULL,
    status          VARCHAR(15) NOT NULL CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
    feedback_rating SMALLINT CHECK (feedback_rating IS NULL OR feedback_rating BETWEEN 1 AND 5)
);

-- ---------------------------------------------------------------------
-- 12. shortlists
-- Saved/bookmarked properties per user
-- ---------------------------------------------------------------------
CREATE TABLE shortlists (
    user_id         INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    property_id     INT NOT NULL REFERENCES properties(property_id) ON DELETE CASCADE,
    added_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, property_id)
);
