# Phase 4: Database Optimization Report

**Project:** Housing.com Property Search
**Schema:** `housing`
**Database:** `housing_search`
**Dataset Scale:** 396,885 rows across 12 tables (120,060 properties)
**Deliverable:** Checkpoint 3 (CP3)
**Evaluation Target:** Code Optimization (16 Marks)

---

## 1. Executive Summary & Optimization Objectives

In Phase 3 (CP2), baseline benchmarks across the 30 faculty workload queries established an un-tuned execution time of **18,392.856 ms** (~18.4 seconds) across the workload. Profiling revealed that **93.1% of the total runtime was consumed by a single query (`R19`)**, with `R25`, `W04`, `R22`, and `R17` accounting for the remainder. The primary cause was the absence of secondary indexes on foreign keys and search predicates, forcing the engine into repeated sequential scans and quadratic nested-loop subplans.

### Core Optimization Objectives for CP3:
1. **Eliminate Dominant Bottlenecks:** Optimize `R19` and `R25` using index-backed joins and covering indexes.
2. **Accelerate Real-Time User Searches:** Bring consumer search queries (`R01`, `R02`, `R05`, `R06`, `R11`) to sub-millisecond response times using compact partial and composite B-tree indexes.
3. **Resolve Intentional Semantic Bug:** Correct the `R13` three-valued logic failure caused by nullable foreign keys, restoring valid query output.
4. **Control Index Storage & Write Overhead:** Minimize write degradation on transactional operations (`W01`–`W05`) by employing targeted partial indexes and eliminating redundant structures.

### Headline Results:
- **Total Workload Execution Time:** Reduced from **18,392.856 ms** to **328.718 ms**.
- **Overall Workload Execution Reduction:** **98.2% reduction** in total execution time (**56.0× measured workload execution-time ratio**).
- **R19 Execution Time:** Reduced from **17,121.589 ms** to **28.518 ms** (99.8% reduction / **600.4× speedup**).
- **R25 Execution Time:** Reduced from **661.294 ms** to **67.109 ms** (89.9% reduction / **9.9× speedup**).
- **Data Integrity:** All 12 tables and 396,885 rows preserved with zero data drift across benchmark runs.

---

## 2. Optimization Methodology & Benchmarking Protocol

To maintain complete empirical rigor and comparability with Phase 3 baseline timings:
1. **Environment:** Executed on macOS (Apple Silicon aarch64), PostgreSQL 18.6 (Postgres.app), targeting the dedicated `housing_search` database under schema `housing`.
2. **Measurement Tool:** Official benchmark runner script (`benchmarks/run_benchmark.sh housing_search optimized 3 sql/06_optimized_queries.sql`).
3. **Execution Count:** Each query was executed **3 consecutive times** (`Run 1`, `Run 2`, `Run 3`) using `EXPLAIN (ANALYZE, BUFFERS)`.
4. **Metric Recorded:** Exact internal PostgreSQL `Execution Time` in milliseconds (ms), excluding network and display latency.
5. **Aggregation:** Arithmetic mean of the three runs ($\text{Average} = \frac{\text{Run 1} + \text{Run 2} + \text{Run 3}}{3}$).
6. **Transactional Write Protection:** Write queries (`W01`–`W05`) were executed inside atomic transaction blocks:
   ```sql
   SET search_path TO housing; BEGIN; EXPLAIN (ANALYZE, BUFFERS) <query> ROLLBACK;
   ```
   All updates and inserts were rolled back immediately, guaranteeing identical dataset state across all runs.
7. **Optimizer Statistics:** Executed `SET search_path TO housing, public; ANALYZE;` prior to benchmarking to ensure PostgreSQL's Cost-Based Optimizer (CBO) had accurate distribution statistics.

---

## 3. Justified Secondary Indexes (`sql/05_indexes.sql`)

A lean, non-redundant set of **11 indexes** was designed, balancing query acceleration against storage consumption and write maintenance.

| # | Index Name | Table & Columns | Partial Predicate / Type | Size | Target Queries | Engineering Justification |
|---|---|---|---|---:|---|---|
| **1** | `idx_enquiries_prop_user_created` | `enquiries (property_id, user_id, created_at)` | B-Tree | 3,104 kB | `R19`, `R25`, `R06`, `R17` | Composite index covering foreign key joins. Leading `(property_id, user_id)` provides an exact 2-column seek prefix for `R25`, while `created_at` provides covering data for `R19` aggregation. |
| **2** | `idx_enquiries_created_at` | `enquiries (created_at)` | B-Tree | 2,096 kB | `R12` | B-tree index enabling index range scan on June 2026 leads in `R12`. |
| **3** | `idx_site_visits_prop_user` | `site_visits (property_id, user_id)` | B-Tree | 784 kB | `R12`, `R06` | Accelerates the `NOT EXISTS` anti-join in `R12` and foreign key joins in `R06`. |
| **4** | `idx_site_visits_scheduled_at` | `site_visits (scheduled_at)` | B-Tree | 512 kB | `R07` | Filters appointment schedule timestamps for agent appointment calendar. |
| **5** | `idx_properties_rent_search` | `properties (locality_id, bhk, price)` | Partial B-Tree (`WHERE status = 'ACTIVE' AND listing_type = 'RENT'`) | 640 kB | `R01` | Compact partial index servicing Koramangala rental searches. Excludes inactive and sale listings. |
| **6** | `idx_properties_sale_search` | `properties (locality_id, bhk, price)` | Partial B-Tree (`WHERE status = 'ACTIVE' AND listing_type = 'SALE' AND property_type = 'APARTMENT'`) | 416 kB | `R02` | Highly selective partial index for Pune apartment sales. Compact size (416 kB vs 18 MB table). |
| **7** | `idx_properties_listed_by` | `properties (listed_by, status, listing_type, property_id)` | B-Tree | 9,504 kB | `R06`, `W02`, `W05` | Supports owner dashboard lookups and transforms `W02`/`W05` min/max subqueries into index lookups. |
| **8** | `idx_properties_project_id` | `properties (project_id)` | Partial B-Tree (`WHERE project_id IS NOT NULL`) | 920 kB | `R13`, `R09`, `R11` | Foreign key index across all statuses. Enables anti-join for `R13` and project inventory queries. |
| **9** | `idx_properties_posted_at_desc` | `properties (posted_at DESC)` | B-Tree | 4,672 kB | `R22`, `W04`, `R17`, `R14` | Reverse-chronological B-tree. Eliminates full-table Sort node for deep pagination (`R22`) and speeds sweeps. |
| **10** | `idx_properties_map_search` | `properties (latitude, longitude)` | Partial B-Tree (`WHERE status = 'ACTIVE' AND listing_type = 'RENT'`) | 808 kB | `R05` | B-tree bounding active rentals to spatial coordinate slices. |
| **11** | `idx_projects_name_trgm` | `projects USING gin (project_name gin_trgm_ops)` | GIN Trigram | 136 kB | `R16` | GIN trigram index (via `pg_trgm`) supporting substring pattern matching (`ILIKE '%greens%'`). |

**Total Index Storage:** **23,592 kB (~23.0 MB)** across all 11 indexes, compared to ~27.7 MB combined base table size (`properties` 18 MB, `enquiries` 7.2 MB, `site_visits` 2.3 MB). Partial indexes on `properties` kept storage minimal while maximizing hit rates.

---

## 4. Query Rewrites & Correctness Analysis (`sql/06_optimized_queries.sql`)

Out of 30 workload queries, exactly **two queries** required SQL rewrites. All other 28 queries remained verbatim as in `queries/workload_30.sql`.

### 4.1 Query R13: NULL Semantic Bug Fix (Faculty Assessment Challenge)

#### Original Query (`queries/workload_30.sql` L141–143):
```sql
SELECT pj.project_id, pj.project_name, pj.possession_status
FROM projects pj
WHERE pj.project_id NOT IN (SELECT p.project_id FROM properties p);
```

#### Problem Analysis:
- In `sql/01_schema.sql`, `properties.project_id` is defined as nullable (`project_id INT REFERENCES projects(project_id) ON DELETE SET NULL`). Independent houses and plots do not belong to projects.
- Database inspection confirmed that **54,009 properties have `project_id IS NULL`**.
- Under standard SQL three-valued logic, `val NOT IN (subquery)` expands to:
  $$\text{pj.project\_id} \neq v_1 \text{ AND } \text{pj.project\_id} \neq v_2 \text{ AND } \dots \text{ AND } \text{pj.project\_id} \neq \text{NULL}$$
- Because any comparison `x <> NULL` evaluates to `UNKNOWN`, the entire conjunction evaluates to `UNKNOWN`. In a `WHERE` filter, `UNKNOWN` is treated as false.
- Consequently, **the original query returned 0 rows**, directly explaining faculty problem **P5**: *"The builder-partnerships list of projects with no listings is always empty."*

#### Rewritten Query (`sql/06_optimized_queries.sql` L141–145):
```sql
SELECT pj.project_id, pj.project_name, pj.possession_status
FROM projects pj
WHERE NOT EXISTS (
    SELECT 1 FROM properties p WHERE p.project_id = pj.project_id
);
```

#### Correctness & Verification:
- `NOT EXISTS` evaluates the correlated equality `p.project_id = pj.project_id`. When `p.project_id` is `NULL`, `NULL = pj.project_id` evaluates to `UNKNOWN`, which is safely ignored.
- **Empirical Result:** The rewritten query correctly returns **120 unlisted projects**.
- **Integrity Proof:** Executing a join between the 120 returned projects and `properties` returned **0 rows**, confirming that none of the 120 projects possess any listed property.
- **Performance:** Execution time dropped from **22.282 ms** to **0.914 ms** via an `Index Only Scan` using `idx_properties_project_id`.

---

### 4.2 Query R19: Correlated Subquery Elimination (Dominant Bottleneck)

#### Original Query (`queries/workload_30.sql` L196–202):
```sql
SELECT p.property_id, p.price,
       (SELECT count(*) FROM enquiries e WHERE e.property_id = p.property_id) AS enquiries,
       (SELECT max(e.created_at) FROM enquiries e WHERE e.property_id = p.property_id) AS last_enquiry_at
FROM properties p
JOIN localities l ON l.locality_id = p.locality_id
WHERE l.city_id = 1 AND p.listing_type = 'SALE' AND p.status = 'ACTIVE'
ORDER BY enquiries DESC;
```

#### Bottleneck Analysis:
In the baseline plan, PostgreSQL executed **two correlated scalar subqueries for every single matching property in Bengaluru** (1,780 properties). Because `enquiries.property_id` had no index, this triggered **3,560 sequential scans of the 100,000-row `enquiries` table**, consuming **17,121.589 ms** (93.1% of the entire benchmark runtime).

#### Rewritten Query (`sql/06_optimized_queries.sql` L197–211):
```sql
SELECT p.property_id, p.price,
       COALESCE(e.enquiries, 0) AS enquiries,
       e.last_enquiry_at
FROM properties p
JOIN localities l ON l.locality_id = p.locality_id
LEFT JOIN (
    SELECT property_id,
           count(*) AS enquiries,
           max(created_at) AS last_enquiry_at
    FROM enquiries
    GROUP BY property_id
) e ON e.property_id = p.property_id
WHERE l.city_id = 1 AND p.listing_type = 'SALE' AND p.status = 'ACTIVE'
ORDER BY enquiries DESC;
```

#### Semantic Equivalence & Result Proof:
1. **NULL & Zero Handling:** In original `R19`, `count(*)` returns `0` when no enquiries match. In the rewrite, `COALESCE(e.enquiries, 0)` returns `0`. Original `max(created_at)` returns `NULL` when unmatched; the `LEFT JOIN` naturally produces `NULL`.
2. **Cardinality:** The derived table aggregates by `property_id`, guaranteeing at most 1 join tuple per property. No duplicate properties are produced.
3. **Multiset Verification:** Executed bidirectional difference testing:
   ```sql
   (Original R19) EXCEPT ALL (Optimized R19)  --> 0 rows
   (Optimized R19) EXCEPT ALL (Original R19)  --> 0 rows
   ```
4. **Performance:** Time dropped from **17,121.589 ms** to **28.518 ms** (99.8% reduction / **600.4× speedup**).

---

## 5. Workload Performance Comparison (All 30 Queries)

Below is the complete performance comparison between Phase 3 baseline timings and Phase 4 optimized timings, measured via `benchmarks/run_benchmark.sh` (average of 3 runs per query):

| Query ID | Type | Baseline Avg (ms) | Optimized Avg (ms) | Min (ms) | Max (ms) | Absolute Diff (ms) | Speedup (%) | Optimized Execution Scan Type(s) | Result Equivalence |
|:---:|:---:|---:|---:|---:|---:|---:|---:|---|:---:|
| **R01** | READ | 22.750 | **0.178** | 0.140 | 0.250 | -22.572 | **99.2%** | Seq Scan on localities \| Bitmap Heap Scan on properties \| Bitmap Index Scan on `idx_properties_rent_search` | ✅ Identical |
| **R02** | READ | 16.624 | **0.304** | 0.244 | 0.341 | -16.320 | **98.2%** | Seq Scan on localities \| Bitmap Heap Scan on properties \| Bitmap Index Scan on `idx_properties_sale_search` | ✅ Identical |
| **R03** | READ | 0.323 | **0.133** | 0.113 | 0.152 | -0.190 | **58.8%** | Index Scan using PKs on `properties`, `projects`, `builders`, `amenities` | ✅ Identical |
| **R04** | READ | 27.490 | **9.775** | 8.759 | 10.887 | -17.715 | **64.4%** | Seq Scan on properties \| Seq Scan on localities | ✅ Identical |
| **R05** | READ | 13.203 | **0.318** | 0.307 | 0.329 | -12.885 | **97.6%** | Bitmap Heap Scan on properties \| Bitmap Index Scan on `idx_properties_map_search` | ✅ Identical |
| **R06** | READ | 34.752 | **0.287** | 0.277 | 0.301 | -34.465 | **99.2%** | Bitmap Index Scan on `idx_properties_listed_by` + `idx_enquiries_prop_user_created` + PK Scan | ✅ Identical |
| **R07** | READ | 4.727 | **0.099** | 0.095 | 0.102 | -4.628 | **97.9%** | Index Only Scan on `idx_properties_listed_by` \| Index Scan on `idx_site_visits_prop_user` \| PK Scan on users | ✅ Identical |
| **R08** | READ | 3.319 | **1.423** | 1.407 | 1.436 | -1.896 | **57.1%** | Seq Scan on price_changes \| Index Scan using properties_pkey on properties | ✅ Identical |
| **R09** | READ | 24.837 | **2.736** | 2.685 | 2.776 | -22.101 | **89.0%** | Seq Scan on project_amenities, amenities \| Bitmap Index Scan on `idx_properties_project_id` | ✅ Identical |
| **R10** | READ | 0.193 | **0.081** | 0.079 | 0.082 | -0.112 | **58.0%** | Seq Scan on builders \| Seq Scan on projects | ✅ Identical |
| **R11** | READ | 19.862 | **0.137** | 0.136 | 0.139 | -19.725 | **99.3%** | Bitmap Heap Scan on properties \| Bitmap Index Scan on `idx_properties_project_id` | ✅ Identical |
| **R12** | READ | 19.573 | **4.624** | 4.511 | 4.744 | -14.949 | **76.4%** | Seq Scan on site_visits \| Bitmap Index Scan on `idx_enquiries_created_at` | ✅ Identical |
| **R13** | READ | 22.282 | **0.914** | 0.826 | 0.999 | -21.368 | **95.9%** | Seq Scan on projects \| Index Only Scan using `idx_properties_project_id` on properties | ⚠️ Bug Fixed (0 $\rightarrow$ 120 rows) |
| **R14** | READ | 29.475 | **7.517** | 7.423 | 7.604 | -21.958 | **74.5%** | Index Scan using `idx_properties_posted_at_desc` on properties \| Seq Scan on users | ✅ Identical |
| **R15** | READ | 23.559 | **11.482** | 11.370 | 11.551 | -12.077 | **51.3%** | Seq Scan on properties \| Seq Scan on localities | ✅ Identical |
| **R16** | READ | 1.210 | **0.494** | 0.431 | 0.614 | -0.716 | **59.2%** | Seq Scan on projects | ✅ Identical |
| **R17** | READ | 51.294 | **20.908** | 20.664 | 21.258 | -30.386 | **59.2%** | Seq Scan on enquiries \| Seq Scan on properties | ✅ Identical |
| **R18** | READ | 39.355 | **16.610** | 16.585 | 16.638 | -22.745 | **57.8%** | Parallel Seq Scan on properties | ✅ Identical |
| **R19** | READ | 17,121.589 | **28.518** | 27.951 | 29.537 | -17,093.071 | **99.8%** | Hash Right Join against pre-aggregated enquiries \| Seq Scan on properties, localities | ✅ Identical |
| **R20** | READ | 28.437 | **8.846** | 8.799 | 8.933 | -19.591 | **68.9%** | Parallel Seq Scan on properties | ✅ Identical |
| **R21** | READ | 21.064 | **10.513** | 10.313 | 10.819 | -10.551 | **50.1%** | Seq Scan on properties \| Seq Scan on site_visits \| Seq Scan on localities | ✅ Identical |
| **R22** | READ | 62.017 | **6.981** | 6.964 | 7.011 | -55.036 | **88.7%** | Index Scan using `idx_properties_posted_at_desc` on properties (no Sort node) | ✅ Identical |
| **R23** | READ | 0.046 | **0.025** | 0.020 | 0.034 | -0.021 | **45.7%** | Index Scan using `users_phone_key` on users | ✅ Identical |
| **R24** | READ | 0.290 | **0.137** | 0.131 | 0.148 | -0.153 | **52.8%** | Seq Scan on projects \| Seq Scan on builders | ✅ Identical |
| **R25** | READ | 661.294 | **67.109** | 66.931 | 67.450 | -594.185 | **89.9%** | Seq Scan on shortlists, properties, localities \| Index Only Scan on `idx_enquiries_prop_user_created` | ✅ Identical |
| **W01** | WRITE | 1.367 | **0.634** | 0.613 | 0.649 | -0.733 | **53.6%** | Single-row INSERT into properties (rolled back) | ✅ Identical |
| **W02** | WRITE | 1.210 | **0.242** | 0.226 | 0.253 | -0.968 | **80.0%** | Index Only Scan using `idx_properties_listed_by` \| PK Update on properties (rolled back) | ✅ Identical |
| **W03** | WRITE | 1.117 | **0.727** | 0.667 | 0.801 | -0.390 | **34.9%** | Single-row INSERT into site_visits (rolled back) | ✅ Identical |
| **W04** | WRITE | 121.937 | **126.707** | 119.822 | 136.773 | +4.770 | **-3.9%** | Bulk UPDATE on properties (14,440 rows modified; expected index maintenance overhead) | ✅ Identical |
| **W05** | WRITE | 17.660 | **0.259** | 0.247 | 0.280 | -17.401 | **98.5%** | Index Only Scan using `idx_properties_listed_by` \| PK Update on properties (rolled back) | ✅ Identical |
| **Total** | | **18,392.856** | **328.718** | | | **-18,064.138** | **98.2%** | **56.0× Measured Workload Execution-Time Ratio** | |

$$\text{Speedup (\%)} = \frac{\text{Baseline Time} - \text{Optimized Time}}{\text{Baseline Time}} \times 100$$
$$\text{Measured Workload Execution-Time Ratio} = \frac{18,392.856\text{ ms}}{328.718\text{ ms}} \approx 56.0\times$$

---

## 6. Detailed Plan Transformations for Top Improvements

### 1. Query R19 (City Report: Bengaluru Active Sales)
- **Baseline (17,121.589 ms):**
  PostgreSQL evaluated two correlated scalar subplans for each Bengaluru property. With no index on `enquiries.property_id`, each subplan triggered a full table scan of 100,000 rows. The query executed 3,560 sequential scans across 1,780 properties.
- **Optimized (28.518 ms — 600.4× speedup):**
  Correlated subqueries were eliminated in favor of a single `Hash Right Join` against a derived aggregate table `(SELECT property_id, count(*), max(created_at) FROM enquiries GROUP BY property_id)`. The aggregate operates in a single pass over `enquiries` with a memory usage of 5.9 MB, resolving the entire city report in 28.5 ms.

### 2. Query R25 (Conversion Funnel: Shortlists to Enquiries)
- **Baseline (661.294 ms):**
  Evaluated `WHERE EXISTS (SELECT 1 FROM enquiries e WHERE e.property_id = s.property_id AND e.user_id = s.user_id)` for all 69,999 shortlisted properties. Because `(property_id, user_id)` was unindexed, the query required full-table hash checks for each shortlist entry.
- **Optimized (67.109 ms — 9.9× speedup):**
  The composite B-tree `idx_enquiries_prop_user_created (property_id, user_id, created_at)` allows PostgreSQL to evaluate `EXISTS` via an **Index Only Scan**. For each shortlist, the planner seeks directly to `(property_id, user_id)` within index leaf pages without accessing heap storage.

### 3. Query R01 & R02 (Consumer Rent and Buy Searches)
- **Baseline (R01: 22.750 ms, R02: 16.624 ms):**
  Full table scans of all 120,060 properties to filter on `listing_type`, `status`, `bhk`, and `price`, followed by an explicit in-memory Sort.
- **Optimized (R01: 0.178 ms — 127× speedup; R02: 0.304 ms — 54× speedup):**
  Targeted partial composite indexes (`idx_properties_rent_search` and `idx_properties_sale_search`) filter on active listings directly within the index B-tree. PostgreSQL executes a `Bitmap Index Scan` seeking directly to the matching locality and BHK, returning pre-filtered rows in sub-millisecond time.

### 4. Query R22 (Moderation Deep Pagination)
- **Baseline (62.017 ms):**
  PostgreSQL executed a `Parallel Seq Scan` over 120,060 rows followed by a top-N sort to discard 50,000 rows (`OFFSET 50000 LIMIT 25`).
- **Optimized (6.981 ms — 8.9× speedup):**
  The B-tree index `idx_properties_posted_at_desc` delivers tuples in pre-sorted reverse-chronological order. The planner eliminates the explicit Sort node entirely, stepping through 50,000 index tuples and retrieving the 25 target rows in 6.98 ms.

### 5. Query W05 (Mark Oldest Rental as Rented)
- **Baseline (17.660 ms):**
  The subquery `SELECT min(property_id) FROM properties WHERE listed_by = 1033 AND status = 'ACTIVE' AND listing_type = 'RENT'` performed a full sequential scan of 120,060 rows to find owner 1033's oldest listing.
- **Optimized (0.259 ms — 68× speedup):**
  The composite index `idx_properties_listed_by (listed_by, status, listing_type, property_id)` transforms the subquery into an **Index Only Scan**, seeking owner 1033's active rentals and reading the minimum `property_id` in 0.26 ms.

---

## 7. Trade-Off Analysis: Write Overhead & Index Maintenance

Adding secondary indexes inherently introduces write overhead during DML operations, as every inserted or modified tuple must update corresponding index B-trees.

### Measured Write Impact:
1. **Single-Row Operations (`W01`, `W02`, `W03`, `W05`):**
   - Single-row inserts (`W01`: 0.634 ms, `W03`: 0.727 ms) remained well within the real-time threshold (<5 ms).
   - Single-row updates (`W02`: 0.242 ms, `W05`: 0.259 ms) actually became **faster** because the index lookups to find target rows (`max/min property_id`) sped up by 80% to 98%, far outweighing the microsecond cost of updating index pointers.
2. **Bulk Maintenance Job (`W04` — Bulk Deactivation):**
   - Baseline: **121.937 ms**
   - Optimized: **126.707 ms**
   - **Performance Change:** **+4.770 ms (3.9% slower)**.
   - **Technical Explanation:** `W04` updates `status = 'INACTIVE'` for **14,440 rows** (`WHERE status = 'ACTIVE' AND posted_at < ...`). Although candidate identification uses `posted_at`, modifying 14,440 rows forces PostgreSQL to remove tuples from partial indexes where `status = 'ACTIVE'` and update non-partial indexes on `properties`. A 3.9% regression on a nightly batch job is fully acceptable given the massive gains across user-facing queries, and easily meets the faculty batch target of <1,000 ms.
3. **Zero Overhead on Interactions:**
   - As audited in Phase 4 review, queries `W01`–`W05` contain **zero write operations on `enquiries` or `projects`**. The comprehensive indexes on `enquiries` (`idx_enquiries_prop_user_created`) and `projects` (`idx_projects_name_trgm`) impose zero write maintenance penalty on the workload.

---

## 8. Queries Retaining Sequential Scans (Why Indexes Were Omitted)

Not every query benefits from an index. In relational database optimization, creating an index for a query that reads a large fraction of a table is counterproductive because random I/O via index pages is more expensive than sequential block reads.

The following queries intentionally retain sequential scans:
1. **`R04` (Whitefield Monthly Trends — 9.775 ms):**
   Requires grouping apartments across the entire year 2026. Reading the table sequentially with multi-block reads is faster than traversing an index for thousands of scattered rows.
2. **`R15` (Locality Rental Yields — 11.482 ms):**
   Computes conditional aggregates across all apartment listings in Bengaluru. The query processes a large percentage of total apartment inventory; a sequential scan avoids random I/O thrashing.
3. **`R18` (Fraud Detection — 16.610 ms):**
   Requires grouping all active properties across 5 columns to find duplicates. A `Parallel Seq Scan` with a large HashAggregate is the optimal execution strategy for full-table duplicate auditing.
4. **`R20` (Growth Listings per Day — 8.846 ms):**
   Aggregates all listings posted in June across all statuses. A full sequential scan processes the dataset efficiently in 8.8 ms (target: <5,000 ms).
5. **`R21` (Experience Locality Ratings — 10.513 ms):**
   Computes average feedback ratings across all rated visits. Reading `site_visits` and joining `properties` via Hash Join is optimal.
6. **`R10` (0.081 ms) & `R24` (0.137 ms) on `projects`:**
   The `projects` table contains only 1,200 rows (16 disk pages). The entire table resides in PostgreSQL's shared buffer cache. A sequential scan completes in under 0.1 ms, rendering secondary indexes superfluous.

---

## 9. Database Integrity & Snapshot Verification

Following the completion of the 90 benchmark iterations:
- **Integrity Audit:** Queried all 12 tables in `housing_search`.
- **Verified Row Counts:**
  `amenities`: 15, `builders`: 150, `cities`: 10, `enquiries`: 100,000, `localities`: 100, `price_changes`: 23,425, `project_amenities`: 6,806, `projects`: 1,200, `properties`: 120,060, `shortlists`: 69,999, `site_visits`: 35,120, `users`: 40,000.
- **Total Dataset Size:** **396,885 rows preserved** with zero data drift.
- **Baseline Results Preserved:** `benchmarks/results/baseline/summary.csv` and all 30 baseline raw plan files remain intact.

---

## 10. Limitations & Scalability Outlook (Preparation for Phase 5)

While Phase 4 achieved a 98.2% reduction on the seed dataset (120,060 properties), several architectural limitations will emerge when scaling to the **large dataset (20× data volume: ~2.4M properties, ~2M enquiries)** in Phase 5:
1. **Deep Offset Pagination (`R22`):** Although `idx_properties_posted_at_desc` eliminated the sort, `OFFSET 50000` still steps through 50,000 index tuples. At 20× scale, deep pagination should transition to keyset pagination (`WHERE (posted_at, property_id) < ($last_time, $last_id)`).
2. **`enquiries` Hash Table Sizing (`R19`):** In Phase 4, the derived table aggregate fit comfortably in `work_mem` (5.9 MB). At 20× volume (~2M enquiries), memory usage will grow to ~100 MB, potentially spilling to disk if `work_mem` is insufficient.
3. **Table Partitioning for `properties`:** As `properties` grows beyond 2.4 million rows, table partitioning (e.g. `RANGE (posted_at)` or `LIST (listing_type)`) will become necessary to maintain compact B-tree indexes and enable partition pruning for consumer searches and deactivation sweeps.

---

## 11. Conclusion

Through the strategic application of 11 targeted indexes and two precise query rewrites, the Housing.com property search database achieved:
- A reduction in total workload execution time from **18.4 seconds to 0.33 seconds** (**98.2% reduction**).
- Full resolution of the two major workload bottlenecks (`R19` and `R25`).
- Correction of the faculty-designed `R13` three-valued logic defect.
- Controlled write overhead (3.9% on bulk deactivation; sub-millisecond single-row writes).
- Total storage overhead limited to 23.0 MB.

All CP3 optimization deliverables have been generated, benchmarked, and verified in accordance with DBMS project requirements.
