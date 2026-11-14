# Phase 3: Baseline Query Timings Report

**Project:** Housing.com Property Search  
**Schema:** `housing`  
**Database:** `housing_search`  
**Dataset Size:** 396,885 rows across 12 tables  
**Deliverable:** Checkpoint 2 (CP2)  

---

## 1. Benchmarking Environment & Methodology

### 1.1 Environment Specifications
- **Operating System:** macOS (Apple Silicon aarch64)
- **Database Server:** PostgreSQL 18.6 (Postgres.app)
- **Database Client:** psql 16.15 (libpq)
- **Database Name:** `housing_search`
- **Active Schema:** `housing`
- **Data State:** Seed data loaded (396,885 rows); zero secondary performance indexes (only automatic B-Tree indexes created by `PRIMARY KEY` and `UNIQUE` constraints).

### 1.2 Measurement Methodology
- **Execution Script:** Official benchmark runner (`benchmarks/run_benchmark.sh housing_search baseline`).
- **Timing Instrument:** `EXPLAIN (ANALYZE, BUFFERS)` executed via PostgreSQL.
- **Run Iterations:** Each query was executed **3 consecutive times** (`Run 1`, `Run 2`, `Run 3`).
- **Metric Recorded:** Exact PostgreSQL internal `Execution Time` in milliseconds (ms), excluding client network serialization.
- **Aggregation:** Arithmetic mean ($\text{Average} = \frac{\text{Run 1} + \text{Run 2} + \text{Run 3}}{3}$).
- **Data Protection for Writes (`W01`–`W05`):** Executed inside an atomic transaction block:
  ```sql
  SET search_path TO housing; BEGIN; EXPLAIN (ANALYZE, BUFFERS) <query> ROLLBACK;
  ```
  All modifications were immediately rolled back, guaranteeing zero data drift across runs.
- **Pre-Benchmark Optimizer Statistics:** `ANALYZE;` was executed beforehand to ensure PostgreSQL's cost-based query planner had accurate distribution statistics.

---

## 2. Baseline Timings Table (All 30 Queries)

Below are the exact execution times for all 30 faculty workload queries, measured under baseline un-tuned conditions:

| SQL Query | Type | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
| :--- | :---: | ---: | ---: | ---: | ---: |
| **R01**: Rent search: active 2 BHK homes in Koramangala up to ₹40,000/month, furnished or semi-furnished | READ | 30.910 | 16.531 | 20.810 | **22.750** |
| **R02**: Buy search: 3 BHK apartments for sale in Pune under ₹1.2 crore, best price per sq ft first | READ | 16.548 | 16.574 | 16.750 | **16.624** |
| **R03**: Property page: property 6897 with its project, builder and project amenities | READ | 0.602 | 0.175 | 0.191 | **0.323** |
| **R04**: Price trends: average sale price per sq ft of apartments in Whitefield, per month in 2026 | READ | 27.430 | 27.964 | 27.075 | **27.490** |
| **R05**: Map view: active rentals inside the visible map area of central Bengaluru | READ | 13.259 | 13.246 | 13.103 | **13.203** |
| **R06**: Owner dashboard: owner 1033's listings with enquiry and site-visit counts | READ | 24.016 | 54.674 | 25.566 | **34.752** |
| **R07**: Agent app: site visits scheduled on 1 July 2026 for properties listed by user 4723 | READ | 4.780 | 4.524 | 4.878 | **4.727** |
| **R08**: Price-drop alerts: active properties whose price fell by 10% or more in June 2026 | READ | 3.397 | 3.240 | 3.321 | **3.319** |
| **R09**: Amenity filter: active properties in projects that have a gym AND a swimming pool AND power backup | READ | 24.060 | 24.785 | 25.667 | **24.837** |
| **R10**: Buyer due diligence: look up a project by its RERA registration id | READ | 0.240 | 0.170 | 0.168 | **0.193** |
| **R11**: Project page: available listings in project 217 by BHK with the price range | READ | 18.535 | 19.566 | 21.485 | **19.862** |
| **R12**: Lead follow-up: June 2026 enquiries with no site visit booked for that property by that user | READ | 18.882 | 23.821 | 16.017 | **19.573** |
| **R13**: Builder partnerships: projects with no property listed on Housing.com | READ | 22.507 | 22.651 | 21.687 | **22.282** |
| **R14**: Agent leaderboard: agents with the most properties sold or rented in 2026 | READ | 30.158 | 28.909 | 29.359 | **29.475** |
| **R15**: Investor insights: rental yield by Bengaluru locality (yearly rent per sq ft ÷ sale price per sq ft) | READ | 23.264 | 23.539 | 23.873 | **23.559** |
| **R16**: Search box: projects with "greens" in the name | READ | 0.912 | 1.506 | 1.213 | **1.210** |
| **R17**: Owner nudges: active listings older than 90 days that have never received an enquiry | READ | 51.067 | 49.072 | 53.742 | **51.294** |
| **R18**: Fraud checks: the same flat (locality, area, floor, BHK) listed more than once by the same lister | READ | 39.114 | 40.143 | 38.809 | **39.355** |
| **R19**: City report: enquiries and latest enquiry for every active sale property in Bengaluru | READ | 17249.007 | 17015.535 | 17100.225 | **17121.589** |
| **R20**: Growth: new listings per day and running total, June 2026 | READ | 27.249 | 28.651 | 29.411 | **28.437** |
| **R21**: Experience: average site-visit rating per locality (at least 10 rated visits) | READ | 21.555 | 20.344 | 21.292 | **21.064** |
| **R22**: Listing moderation console: all listings, newest first, page 2,001 (25 per page) | READ | 62.600 | 61.985 | 61.467 | **62.017** |
| **R23**: Sign-in with mobile number | READ | 0.049 | 0.047 | 0.042 | **0.046** |
| **R24**: Buyer protection: under-construction projects whose promised possession date has already passed | READ | 0.277 | 0.294 | 0.298 | **0.290** |
| **R25**: Funnel: shortlists that turned into an enquiry, per city | READ | 663.232 | 656.294 | 664.357 | **661.294** |
| **W01**: Post property: owner 1033 lists a 2 BHK for rent in Koramangala | WRITE | 1.907 | 1.155 | 1.040 | **1.367** |
| **W02**: Price cut: owner 1033 reduces the rent of their most recent active rental by 5% | WRITE | 1.459 | 1.090 | 1.082 | **1.210** |
| **W03**: Book a site visit: seeker 1042 visits property 6897 on 4 July 2026 at 11:00 | WRITE | 1.227 | 1.146 | 0.977 | **1.117** |
| **W04**: Nightly job: deactivate active listings older than 120 days | WRITE | 117.368 | 121.231 | 127.211 | **121.937** |
| **W05**: Owner 1033 marks their oldest active rental as rented | WRITE | 19.483 | 16.656 | 16.841 | **17.660** |
| **Total (sum of all 30)** | | **18,515.094** | **18,295.518** | **18,367.957** | **18,392.856** |

---

## 3. Query Execution Plan & Bottleneck Analysis (Per Query)

Below is the detailed breakdown of the execution scan types and beginner-friendly explanations for why each query is fast or slow.

### R01: Rent Search (Koramangala 2 BHK)
- **Scan Types:** `Seq Scan on properties` | `Seq Scan on localities`
- **Average Time:** 22.750 ms
- **Why it is fast/slow:** The database must sequentially scan all 120,060 rows in `properties` to filter on `status`, `listing_type`, `bhk`, and `price` because no composite search index exists yet.

### R02: Buy Search (Pune 3 BHK)
- **Scan Types:** `Seq Scan on properties` | `Seq Scan on localities`
- **Average Time:** 16.624 ms
- **Why it is fast/slow:** Requires a full sequential scan of `properties` to filter on property type, price, and BHK, followed by an in-memory Sort node for `price_per_sqft`.

### R03: Property Page (Property 6897 Details)
- **Scan Types:** `Index Scan on properties_pkey` | `Index Scan on projects_pkey` | `Index Scan on builders_pkey` | `Index Only Scan on project_amenities_pkey` | `Index Scan on amenities_pkey`
- **Average Time:** 0.323 ms
- **Why it is fast/slow:** **Fast.** The query searches directly by `property_id = 6897`. Every joined relation is accessed via its Primary Key B-Tree index with point lookups.

### R04: Price Trends (Whitefield Apartments)
- **Scan Types:** `Seq Scan on localities` | `Seq Scan on properties`
- **Average Time:** 27.490 ms
- **Why it is fast/slow:** Must scan all 120,060 properties to evaluate `EXTRACT(YEAR FROM posted_at) = 2026` and aggregate by month without date indexing.

### R05: Map View (Central Bengaluru Rentals)
- **Scan Types:** `Seq Scan on properties`
- **Average Time:** 13.203 ms
- **Why it is fast/slow:** Performs a full sequential table scan checking bounding box coordinates (`latitude BETWEEN ... AND longitude BETWEEN ...`) across all listings.

### R06: Owner Dashboard (Owner 1033 Listings)
- **Scan Types:** `Seq Scan on site_visits` | `Seq Scan on enquiries` | `Seq Scan on properties`
- **Average Time:** 34.752 ms
- **Why it is fast/slow:** Performs full sequential scans on `properties`, `enquiries` (100k rows), and `site_visits` (35k rows) because foreign keys `listed_by` and `property_id` do not have secondary indexes.

### R07: Agent App (Scheduled Visits for Agent 4723)
- **Scan Types:** `Seq Scan on site_visits` | `Index Scan on properties_pkey` | `Index Scan on users_pkey`
- **Average Time:** 4.727 ms
- **Why it is fast/slow:** Scans `site_visits` to match `DATE(scheduled_at)`, then uses Primary Key indexes on `properties` and `users`.

### R08: Price-Drop Alerts (June 2026)
- **Scan Types:** `Seq Scan on price_changes` | `Index Scan on properties_pkey`
- **Average Time:** 3.319 ms
- **Why it is fast/slow:** Scans 23,425 rows in `price_changes` for the June date range, then uses the PK index on `properties` to verify active status.

### R09: Amenity Filter (Gym + Pool + Power Backup)
- **Scan Types:** `Seq Scan on properties` | `Seq Scan on project_amenities` | `Seq Scan on amenities`
- **Average Time:** 24.837 ms
- **Why it is fast/slow:** Scans the entire `properties` table to match candidate `project_id` values produced by the amenity subquery.

### R10: Buyer Due Diligence (RERA ID Lookup)
- **Scan Types:** `Seq Scan on builders` | `Seq Scan on projects`
- **Average Time:** 0.193 ms
- **Why it is fast/slow:** **Fast.** Even though `projects.rera_id` has no index and requires a sequential scan, the `projects` table is very small (only 1,200 rows), so it completes in under 0.2 ms.

### R11: Project Page (Project 217 Inventory)
- **Scan Types:** `Seq Scan on properties`
- **Average Time:** 19.862 ms
- **Why it is fast/slow:** Full table scan on 120,060 properties because the foreign key `properties.project_id` has no secondary index.

### R12: Lead Follow-Up (Enquiries without Site Visit)
- **Scan Types:** `Seq Scan on enquiries` | `Seq Scan on site_visits`
- **Average Time:** 19.573 ms
- **Why it is fast/slow:** Evaluates a `NOT EXISTS` anti-join by scanning all 100,000 enquiries and 35,120 site visits using a Hash Anti Join in memory.

### R13: Builder Partnerships (Projects without Listings)
- **Scan Types:** `Seq Scan on projects` | `Seq Scan on properties`
- **Average Time:** 22.282 ms
- **Why it is fast/slow:** Evaluates `NOT IN (SELECT project_id FROM properties)` by doing a full sequential scan of `properties` to build a sub-plan hash table.

### R14: Agent Leaderboard (Most Deals in 2026)
- **Scan Types:** `Seq Scan on properties` | `Seq Scan on users`
- **Average Time:** 29.475 ms
- **Why it is fast/slow:** Full sequential scan of `properties` filtering on status and date, joined against a sequential scan of `users`.

### R15: Investor Insights (Locality Rental Yield)
- **Scan Types:** `Seq Scan on properties` | `Seq Scan on localities`
- **Average Time:** 23.559 ms
- **Why it is fast/slow:** Computes conditional aggregations (`FILTER (WHERE ...)`) across all properties in city 1 over a full table scan.

### R16: Search Box (Projects with "greens" in Name)
- **Scan Types:** `Seq Scan on projects`
- **Average Time:** 1.210 ms
- **Why it is fast/slow:** **Fast.** Sequential scan over 1,200 project rows evaluating `ILIKE '%greens%'`.

### R17: Owner Nudges (Stale Listings without Enquiries)
- **Scan Types:** `Seq Scan on enquiries` | `Seq Scan on properties`
- **Average Time:** 51.294 ms
- **Why it is fast/slow:** Filters `properties` older than 90 days and executes a `NOT EXISTS` anti-join across all 100,000 rows in `enquiries`.

### R18: Fraud Checks (Duplicate Listings by Same Lister)
- **Scan Types:** `Seq Scan on properties`
- **Average Time:** 39.355 ms
- **Why it is fast/slow:** Performs a full parallel sequential scan on `properties` followed by a large HashAggregate grouping by 5 columns (`listed_by`, `locality_id`, `carpet_area_sqft`, `floor_no`, `bhk`).

### R19: City Report (Enquiry Stats for Bengaluru Active Sales)
- **Scan Types:** `Seq Scan on properties` | `Seq Scan on localities` | `Seq Scan on enquiries`
- **Average Time:** **17,121.589 ms (~17.1 seconds) — Extreme Bottleneck!**
- **Why it is fast/slow:** **Severe Bottleneck.** The query contains **two correlated scalar subqueries** in the `SELECT` clause:
  ```sql
  (SELECT count(*) FROM enquiries e WHERE e.property_id = p.property_id)
  (SELECT max(e.created_at) FROM enquiries e WHERE e.property_id = p.property_id)
  ```
  Because `enquiries.property_id` has no index, PostgreSQL is forced to perform **two full sequential scans of the 100,000-row `enquiries` table for EVERY active sale property in Bengaluru** (thousands of times!).

### R20: Platform Growth (New Listings per Day in June 2026)
- **Scan Types:** `Seq Scan on properties`
- **Average Time:** 28.437 ms
- **Why it is fast/slow:** Scans all 120,060 property listings to filter by `posted_at::date`, groups by date, and evaluates a window running total.

### R21: Experience Report (Locality Visit Ratings)
- **Scan Types:** `Seq Scan on properties` | `Seq Scan on site_visits` | `Seq Scan on localities`
- **Average Time:** 21.064 ms
- **Why it is fast/slow:** Joins `site_visits` (35,120 rows) and `properties` (120,060 rows) with Hash Joins to compute average ratings per locality.

### R22: Listing Moderation Console (Deep Offset Pagination)
- **Scan Types:** `Seq Scan on properties`
- **Average Time:** 62.017 ms
- **Why it is fast/slow:** Deep pagination (`OFFSET 50000 LIMIT 25`) ordered by `posted_at DESC`. Without an index on `posted_at`, the engine sequentially scans and sorts 120,060 rows, discarding the first 50,000.

### R23: Sign-In with Mobile Number
- **Scan Types:** `Index Scan on users_phone_key`
- **Average Time:** **0.046 ms — Fastest Query in Workload!**
- **Why it is fast/slow:** **Fastest.** The `phone` column has a unique constraint, creating an automatic B-Tree index (`users_phone_key`). The query retrieves the single matching row in a sub-millisecond tree traversal.

### R24: Buyer Protection (Overdue Under-Construction Projects)
- **Scan Types:** `Seq Scan on projects` | `Seq Scan on builders`
- **Average Time:** 0.290 ms
- **Why it is fast/slow:** **Fast.** Scans the small `projects` table (1,200 rows) filtering on `possession_status` and date.

### R25: Conversion Funnel (Shortlists to Enquiries per City)
- **Scan Types:** `Index Scan on uq_localities_city_name` | `Seq Scan on shortlists` | `Seq Scan on properties` | `Seq Scan on enquiries`
- **Average Time:** **661.294 ms — Heavy Bottleneck!**
- **Why it is fast/slow:** Scans 69,999 rows in `shortlists` and, for each row, executes an unindexed correlated `EXISTS (SELECT 1 FROM enquiries ...)` check.

### W01: Post Property (Insert New Rental)
- **Scan Types:** `(no scan)`
- **Average Time:** 1.367 ms
- **Why it is fast/slow:** **Fast.** Standard single-row `INSERT` into `properties`. Only has to update PK and check constraints.

### W02: Price Cut (5% Reduction on Latest Rental)
- **Scan Types:** `Index Scan on properties_pkey`
- **Average Time:** 1.210 ms
- **Why it is fast/slow:** **Fast.** Identifies the target listing using a subquery and updates a single row in `properties` by primary key.

### W03: Book Site Visit (Insert Scheduled Appointment)
- **Scan Types:** `(no scan)`
- **Average Time:** 1.117 ms
- **Why it is fast/slow:** **Fast.** Single-row `INSERT` into `site_visits`.

### W04: Nightly Job (Bulk Deactivate Stale Listings)
- **Scan Types:** `Seq Scan on properties`
- **Average Time:** 121.937 ms
- **Why it is fast/slow:** Full sequential scan on `properties` to find active rows older than 120 days, followed by bulk updating 14,440 rows in the heap.

### W05: Mark Listing as Rented
- **Scan Types:** `Index Scan on properties_pkey`
- **Average Time:** 17.660 ms
- **Why it is fast/slow:** Locates the oldest active rental for owner 1033 via subquery and updates its status.

---

## 4. Key Bottlenecks & Optimization Roadmap for Phase 4 (CP3)

From the baseline measurements, **93.1% of the total workload time is consumed by a single query (`R19`)**, with `R25`, `W04`, `R22`, and `R17` accounting for the remainder:

```
Total Workload Time:  18,392.856 ms (100.0%)
├── R19 (City Report): 17,121.589 ms ( 93.1%)
├── R25 (Funnel):         661.294 ms (  3.6%)
├── W04 (Bulk Deact):     121.937 ms (  0.7%)
├── R22 (Moderation):      62.017 ms (  0.3%)
├── R17 (Stale Nudges):    51.294 ms (  0.3%)
└── Remaining 25 Queries: 374.725 ms (  2.0%)
```

### High-Priority Optimization Targets for CP3:
1. **Index Foreign Keys on Child Tables:**
   - Create B-Tree indexes on `enquiries(property_id)` and `site_visits(property_id)`. This will directly eliminate the quadratic nested-loop sequential scans in `R19`, `R06`, `R12`, `R17`, and `R25`.
2. **Rewrite Correlated Subqueries into Joins:**
   - In `R19`, rewrite the two correlated scalar subqueries into a single `LEFT JOIN` against a pre-aggregated group of enquiries.
3. **Composite & Partial Indexes for Search Workloads:**
   - Add composite indexes on `properties(status, listing_type, locality_id, bhk, price)` to accelerate real-time consumer searches (`R01`, `R02`).
4. **Ordering & Partial Index for Pagination and Nightly Jobs:**
   - Index `properties(posted_at DESC)` to eliminate full-table sorting in `R22` and accelerate deactivation sweeps in `W04`.
