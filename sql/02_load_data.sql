-- =====================================================================
-- Housing.com Property Search Data Loading Script
-- Checkpoint 1 (CP1) Deliverable: sql/02_load_data.sql
-- =====================================================================
-- Run from the repository root (DE_Starter):
--   psql -d housing_search -f sql/02_load_data.sql
--
-- Tables are loaded strictly in foreign-key dependency order (parents first).
-- The NULL '' option ensures empty CSV fields become SQL NULL.
-- =====================================================================

SET search_path TO housing;

-- Step 1: Primary lookup tables (zero foreign key dependencies)
\copy cities FROM 'seed_data/cities.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy builders FROM 'seed_data/builders.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy amenities FROM 'seed_data/amenities.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy users FROM 'seed_data/users.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- Step 2: Entities referencing Step 1 tables
\copy localities FROM 'seed_data/localities.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy projects FROM 'seed_data/projects.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy project_amenities FROM 'seed_data/project_amenities.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- Step 3: Core property inventory (depends on users, localities, projects)
\copy properties FROM 'seed_data/properties.csv' WITH (FORMAT csv, HEADER true, NULL '')

-- Step 4: Transactional and interaction tables (depend on properties and users)
\copy price_changes FROM 'seed_data/price_changes.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy enquiries FROM 'seed_data/enquiries.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy site_visits FROM 'seed_data/site_visits.csv' WITH (FORMAT csv, HEADER true, NULL '')
\copy shortlists FROM 'seed_data/shortlists.csv' WITH (FORMAT csv, HEADER true, NULL '')
