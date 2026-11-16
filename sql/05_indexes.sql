-- =====================================================================
-- Housing.com Property Search Database Optimization
-- Checkpoint 3 (CP3) Deliverable: sql/05_indexes.sql
-- =====================================================================

SET search_path TO housing, public;

-- Enable trigram extension for fuzzy substring search on project names
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

-- ---------------------------------------------------------------------
-- 1. enquiries: Composite lookup, conversion, and aggregation index
-- Supports: R19 (may enable an Index-Only Scan for GROUP BY property_id, MAX(created_at),
--                depending on planner choice and visibility-map status),
--           R25 (exact 2-column seek prefix on property_id, user_id),
--           R06, R17 (FK joins on property_id)
-- ---------------------------------------------------------------------
CREATE INDEX idx_enquiries_prop_user_created
ON enquiries (property_id, user_id, created_at);

-- ---------------------------------------------------------------------
-- 2. enquiries: Lead follow-up date filtering
-- Supports: R12 (date range filter on created_at)
-- ---------------------------------------------------------------------
CREATE INDEX idx_enquiries_created_at
ON enquiries (created_at);

-- ---------------------------------------------------------------------
-- 3. site_visits: Appointment tracking & lead conversion anti-join
-- Supports: R12 (anti-join lookup on property_id, user_id),
--           R06 (FK join on property_id)
-- ---------------------------------------------------------------------
CREATE INDEX idx_site_visits_prop_user
ON site_visits (property_id, user_id);

-- ---------------------------------------------------------------------
-- 4. site_visits: Agent schedule calendar
-- Supports: R07 (appointment date/time filtering)
-- ---------------------------------------------------------------------
CREATE INDEX idx_site_visits_scheduled_at
ON site_visits (scheduled_at);

-- ---------------------------------------------------------------------
-- 5. properties: Consumer rent search
-- Supports: R01 (active Koramangala 2 BHK rentals sorted by price)
-- ---------------------------------------------------------------------
CREATE INDEX idx_properties_rent_search
ON properties (locality_id, bhk, price)
WHERE status = 'ACTIVE' AND listing_type = 'RENT';

-- ---------------------------------------------------------------------
-- 6. properties: Consumer sale search
-- Supports: R02 (active Pune 3 BHK apartment sales)
-- ---------------------------------------------------------------------
CREATE INDEX idx_properties_sale_search
ON properties (locality_id, bhk, price)
WHERE status = 'ACTIVE' AND listing_type = 'SALE' AND property_type = 'APARTMENT';

-- ---------------------------------------------------------------------
-- 7. properties: Owner dashboard & transactional updates
-- Supports: R06 (filter by listed_by),
--           W02 (subquery for latest rental by listed_by),
--           W05 (subquery for oldest rental by listed_by)
-- ---------------------------------------------------------------------
CREATE INDEX idx_properties_listed_by
ON properties (listed_by, status, listing_type, property_id);

-- ---------------------------------------------------------------------
-- 8. properties: Project inventory & unlisted project anti-join
-- Supports: R13 (unconditioned NOT EXISTS anti-join),
--           R09 (active properties in candidate projects),
--           R11 (active listings in project 217)
-- ---------------------------------------------------------------------
CREATE INDEX idx_properties_project_id
ON properties (project_id)
WHERE project_id IS NOT NULL;

-- ---------------------------------------------------------------------
-- 9. properties: Reverse-chronological pagination & bulk deactivation
-- Supports: R22 (avoids Sort node for ORDER BY posted_at DESC OFFSET 50000),
--           W04 (sweep for active listings older than 120 days),
--           R17 (range seek and ordering by posted_at)
-- ---------------------------------------------------------------------
CREATE INDEX idx_properties_posted_at_desc
ON properties (posted_at DESC);

-- ---------------------------------------------------------------------
-- 10. properties: Map bounding box search
-- Supports: R05 (active rentals in coordinate bounding box)
-- ---------------------------------------------------------------------
CREATE INDEX idx_properties_map_search
ON properties (latitude, longitude)
WHERE status = 'ACTIVE' AND listing_type = 'RENT';

-- ---------------------------------------------------------------------
-- 11. projects: Fuzzy substring search
-- Supports: R16 (ILIKE '%greens%' substring match)
-- ---------------------------------------------------------------------
CREATE INDEX idx_projects_name_trgm
ON projects USING gin (project_name gin_trgm_ops);
