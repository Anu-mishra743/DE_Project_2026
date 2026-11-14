# Phase 2: Database Schema Design & Normalization Report

**Project:** Housing.com Property Search  
**Schema:** `housing`  
**Database:** PostgreSQL 18.6 / 16+  
**Deliverable:** Checkpoint 1 (CP1)  

---

## 1. Executive Summary & Architecture Overview

The Housing.com property search platform requires a relational architecture that satisfies both high-throughput transactional activities (user registrations, enquiries, site-visit bookings, price modifications) and analytical search filtering (geospatial coordinates, price ranges, amenity intersections, locality yields, agent leaderboards).

The reconstructed schema consists of **12 normalized relations** created under the `housing` schema namespace. It models the core business domain:
1. **Master Reference Data**: `cities`, `localities`, `builders`, `amenities`
2. **Projects & Developments**: `projects`, `project_amenities` (M:N junction)
3. **Platform Actors**: `users` (Seekers, Owners, Agents)
4. **Core Inventory**: `properties` (Active/Inactive, Sale/Rent listings)
5. **Auditing & User Interactions**: `price_changes`, `enquiries`, `site_visits`, `shortlists` (M:N junction)

All column names and types align with the 30 faculty benchmark queries (`queries/workload_30.sql`). In accordance with the Phase 2 specification, no secondary performance indexes have been added yet; only primary key and unique constraint indexes exist to establish an un-tuned baseline for Phase 3.

---

## 2. Entity-Relationship (ER) Diagram

A high-resolution graphic is generated at `diagrams/er_diagram.png` (vector source: `diagrams/er_diagram.svg`). Below is the architectural Mermaid representation showing entities, attributes, primary keys, foreign keys, and cardinalities.

```mermaid
erDiagram
    cities ||--o{ localities : "contains (1:N)"
    builders ||--o{ projects : "develops (1:N)"
    localities ||--o{ projects : "locates (1:N)"
    projects ||--o{ project_amenities : "offers (1:N)"
    amenities ||--o{ project_amenities : "categorizes (1:N)"
    users ||--o{ properties : "lists (1:N)"
    localities ||--o{ properties : "situated in (1:N)"
    projects ||--o{ properties : "part of (0..1:N)"
    properties ||--o{ price_changes : "tracks price (1:N)"
    properties ||--o{ enquiries : "receives (1:N)"
    users ||--o{ enquiries : "sends (1:N)"
    properties ||--o{ site_visits : "scheduled for (1:N)"
    users ||--o{ site_visits : "books (1:N)"
    users ||--o{ shortlists : "saves (1:N)"
    properties ||--o{ shortlists : "bookmarked in (1:N)"

    cities {
        int city_id PK
        varchar city_name UQ
        varchar state
    }

    localities {
        int locality_id PK
        int city_id FK
        varchar locality_name
        char pincode
        numeric center_lat
        numeric center_lng
    }

    builders {
        int builder_id PK
        varchar builder_name UQ
        int founded_year
    }

    projects {
        int project_id PK
        int builder_id FK
        int locality_id FK
        varchar project_name
        varchar rera_id
        varchar possession_status
        date possession_date
        int total_units
    }

    amenities {
        int amenity_id PK
        varchar amenity_name UQ
    }

    project_amenities {
        int project_id PK,FK
        int amenity_id PK,FK
    }

    users {
        int user_id PK
        varchar full_name
        varchar phone UQ
        varchar email UQ
        varchar user_type
        varchar agent_rera_id
        timestamptz created_at
    }

    properties {
        int property_id PK
        int listed_by FK
        int project_id FK
        int locality_id FK
        varchar listing_type
        varchar property_type
        smallint bhk
        numeric carpet_area_sqft
        smallint floor_no
        smallint total_floors
        varchar furnishing
        varchar facing
        numeric price
        numeric maintenance_monthly
        numeric security_deposit
        date available_from
        numeric latitude
        numeric longitude
        boolean is_verified
        varchar status
        timestamptz posted_at
    }

    price_changes {
        int change_id PK
        int property_id FK
        numeric old_price
        numeric new_price
        timestamptz changed_at
    }

    enquiries {
        int enquiry_id PK
        int property_id FK
        int user_id FK
        varchar channel
        text message
        timestamptz created_at
    }

    site_visits {
        int visit_id PK
        int property_id FK
        int user_id FK
        timestamptz scheduled_at
        varchar status
        smallint feedback_rating
    }

    shortlists {
        int user_id PK,FK
        int property_id PK,FK
        timestamptz added_at
    }
```

---

## 3. Data Dictionary

### 3.1 Table: `cities`
Master lookup of metropolitan territories.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `city_id` | `INT` | NO | `PRIMARY KEY` | Unique surrogate identifier for each city. |
| `city_name` | `VARCHAR(100)` | NO | `UNIQUE` | Official city name (e.g., Bengaluru, Mumbai). Unique to avoid duplicate city records. |
| `state` | `VARCHAR(100)` | NO | None | Indian state or union territory administering the city. |

---

### 3.2 Table: `localities`
Neighborhoods and micro-markets within cities.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `locality_id` | `INT` | NO | `PRIMARY KEY` | Unique identifier for the locality. |
| `city_id` | `INT` | NO | `REFERENCES cities(city_id) ON DELETE RESTRICT` | Parent metropolitan city. Restricted from accidental deletion. |
| `locality_name` | `VARCHAR(100)` | NO | None | Locality / area name (e.g., Koramangala, Whitefield). |
| `pincode` | `VARCHAR(6)` | NO | `CHECK (pincode ~ '^[0-9]{6}$')` | 6-digit Indian Postal PIN code. Validated by regex. |
| `center_lat` | `NUMERIC(9,6)` | NO | `CHECK (center_lat BETWEEN -90 AND 90)` | Geographical latitude of locality centroid (up to ~0.1m precision). |
| `center_lng` | `NUMERIC(9,6)` | NO | `CHECK (center_lng BETWEEN -180 AND 180)` | Geographical longitude of locality centroid. |

*Table-level constraints:* `CONSTRAINT uq_localities_city_name UNIQUE (city_id, locality_name)` prevents duplicate locality names within the same city.

---

### 3.3 Table: `builders`
Real estate developers and construction firms.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `builder_id` | `INT` | NO | `PRIMARY KEY` | Unique identifier for builder organization. |
| `builder_name` | `VARCHAR(150)` | NO | `UNIQUE` | Company / brand name (e.g., Prestige, Sobha). Unique across system. |
| `founded_year` | `INT` | NO | `CHECK (founded_year >= 1800 AND founded_year <= 2100)` | Year company was established. Guarded against invalid calendar years. |

---

### 3.4 Table: `projects`
Residential societies and townships developed by builders.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `project_id` | `INT` | NO | `PRIMARY KEY` | Unique project identifier. |
| `builder_id` | `INT` | NO | `REFERENCES builders(builder_id) ON DELETE RESTRICT` | Developer responsible for project. Protected against orphaned projects. |
| `locality_id` | `INT` | NO | `REFERENCES localities(locality_id) ON DELETE RESTRICT` | Physical locality where project is located. |
| `project_name` | `VARCHAR(150)` | NO | None | Marketing/official name of project (e.g., Heights Phase I 1). |
| `rera_id` | `VARCHAR(50)` | YES | None | State Real Estate Regulatory Authority ID. Optional for older/exempt projects. |
| `possession_status`| `VARCHAR(20)` | NO | `CHECK (possession_status IN ('READY_TO_MOVE', 'UNDER_CONSTRUCTION'))` | Construction milestone status. |
| `possession_date` | `DATE` | NO | None | Scheduled or completed handover date. |
| `total_units` | `INT` | NO | `CHECK (total_units > 0)` | Planned inventory unit count. Must be positive. |

---

### 3.5 Table: `amenities`
Standardized catalog of housing society facilities.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `amenity_id` | `INT` | NO | `PRIMARY KEY` | Unique amenity identifier. |
| `amenity_name` | `VARCHAR(100)` | NO | `UNIQUE` | Name of amenity (e.g., Gym, Swimming Pool, Power Backup). |

---

### 3.6 Table: `project_amenities`
Many-to-Many junction linking projects to the amenities they offer.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `project_id` | `INT` | NO | `REFERENCES projects(project_id) ON DELETE CASCADE` | Associated project. Cascades deletion when project is purged. |
| `amenity_id` | `INT` | NO | `REFERENCES amenities(amenity_id) ON DELETE RESTRICT` | Associated amenity. Restricted from deleting in-use amenities. |

*Primary Key:* Composite `PRIMARY KEY (project_id, amenity_id)`.

---

### 3.7 Table: `users`
Registered actors interacting on the platform.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `user_id` | `INT` | NO | `PRIMARY KEY` | Unique user account ID. |
| `full_name` | `VARCHAR(150)` | NO | None | User's legal/display name. |
| `phone` | `VARCHAR(15)` | NO | `UNIQUE, CHECK (phone ~ '^[0-9]{10}$')` | 10-digit mobile number for login and SMS alerts. Guaranteed unique. |
| `email` | `VARCHAR(150)` | YES | `UNIQUE` | Email address. Nullable for phone-only signups, unique when provided. |
| `user_type` | `VARCHAR(10)` | NO | `CHECK (user_type IN ('SEEKER', 'OWNER', 'AGENT'))` | Actor classification role. |
| `agent_rera_id` | `VARCHAR(50)` | YES | None | Official RERA broker license ID. Only populated for AGENT users. |
| `created_at` | `TIMESTAMPTZ` | NO | `DEFAULT CURRENT_TIMESTAMP` | Account creation timestamp with timezone. |

---

### 3.8 Table: `properties`
Core real estate inventory (both rent and resale listings).

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `property_id` | `INT` | NO | `PRIMARY KEY` | Unique property listing identifier. |
| `listed_by` | `INT` | NO | `REFERENCES users(user_id) ON DELETE RESTRICT` | User who posted listing. Restricted from deletion while listings exist. |
| `project_id` | `INT` | YES | `REFERENCES projects(project_id) ON DELETE SET NULL` | Parent society/project. Null for standalone houses or plots. |
| `locality_id` | `INT` | NO | `REFERENCES localities(locality_id) ON DELETE RESTRICT` | Geographic locality for search queries. |
| `listing_type` | `VARCHAR(10)` | NO | `CHECK (listing_type IN ('RENT', 'SALE'))` | Transaction category. |
| `property_type` | `VARCHAR(20)` | NO | `CHECK (property_type IN ('APARTMENT', 'INDEPENDENT_HOUSE', 'PLOT', 'VILLA'))` | Architectural typology. |
| `bhk` | `SMALLINT` | YES | `CHECK (bhk IS NULL OR bhk > 0)` | Bedroom count. Null for PLOT listings; positive integer for homes. |
| `carpet_area_sqft`| `NUMERIC(10,2)`| NO | `CHECK (carpet_area_sqft > 0)` | Usable interior floor area. Must be strictly positive. |
| `floor_no` | `SMALLINT` | YES | None | Listing floor level (0 for ground floor). Null for land plots. |
| `total_floors` | `SMALLINT` | YES | `CHECK (total_floors IS NULL OR total_floors >= 0)` | Total building stories. Null for land plots. |
| `furnishing` | `VARCHAR(20)` | YES | `CHECK (furnishing IS NULL OR furnishing IN ('UNFURNISHED', 'SEMI_FURNISHED', 'FULLY_FURNISHED'))` | Furnishing level. Null for land plots. |
| `facing` | `VARCHAR(20)` | NO | `CHECK (facing IN ('EAST', 'NORTH', 'NORTH_EAST', 'NORTH_WEST', 'SOUTH', 'SOUTH_EAST', 'SOUTH_WEST', 'WEST'))` | Vastu / cardinal orientation direction. |
| `price` | `NUMERIC(12,2)`| NO | `CHECK (price > 0)` | Total listing price (monthly rent in ₹ or sale price in ₹). Must be positive. |
| `maintenance_monthly`| `NUMERIC(10,2)`| YES| `CHECK (maintenance_monthly IS NULL OR maintenance_monthly >= 0)`| Recurring society upkeep fees. |
| `security_deposit`| `NUMERIC(12,2)`| YES| `CHECK (security_deposit IS NULL OR security_deposit >= 0)`| Refundable lease deposit (populated for rentals). |
| `available_from` | `DATE` | NO | None | Date property can be occupied. |
| `latitude` | `NUMERIC(9,6)` | NO | `CHECK (latitude BETWEEN -90 AND 90)` | Map coordinate latitude. |
| `longitude` | `NUMERIC(9,6)` | NO | `CHECK (longitude BETWEEN -180 AND 180)` | Map coordinate longitude. |
| `is_verified` | `BOOLEAN` | NO | `DEFAULT FALSE` | Physical or document verification badge by Housing.com. |
| `status` | `VARCHAR(10)` | NO | `CHECK (status IN ('ACTIVE', 'INACTIVE', 'RENTED', 'SOLD'))` | Lifecycle listing availability status. |
| `posted_at` | `TIMESTAMPTZ` | NO | `DEFAULT CURRENT_TIMESTAMP` | Initial listing publication timestamp. |

*Table-level constraints:* `CONSTRAINT chk_properties_floors CHECK (floor_no IS NULL OR total_floors IS NULL OR floor_no <= total_floors)` ensures floor numbers never exceed building height.

---

### 3.9 Table: `price_changes`
Historical log of price revisions.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `change_id` | `INT` | NO | `PRIMARY KEY` | Unique log entry identifier. |
| `property_id` | `INT` | NO | `REFERENCES properties(property_id) ON DELETE CASCADE` | Affected listing. Cascades deletion if property is deleted. |
| `old_price` | `NUMERIC(12,2)`| NO | `CHECK (old_price > 0)` | Previous price prior to modification. |
| `new_price` | `NUMERIC(12,2)`| NO | `CHECK (new_price > 0)` | Updated listing price. |
| `changed_at` | `TIMESTAMPTZ` | NO | `DEFAULT CURRENT_TIMESTAMP` | Timestamp when price modification occurred. |

*Table-level constraints:* `CONSTRAINT chk_price_change_diff CHECK (old_price <> new_price)` guarantees meaningful revision history.

---

### 3.10 Table: `enquiries`
Direct consumer leads sent to property listers.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `enquiry_id` | `INT` | NO | `PRIMARY KEY` | Unique lead / inquiry ID. |
| `property_id` | `INT` | NO | `REFERENCES properties(property_id) ON DELETE CASCADE` | Inquired property. |
| `user_id` | `INT` | NO | `REFERENCES users(user_id) ON DELETE RESTRICT` | Prospective tenant/buyer. User deletion is restricted. |
| `channel` | `VARCHAR(10)` | NO | `CHECK (channel IN ('CALL', 'FORM', 'WHATSAPP'))` | Lead origination channel. |
| `message` | `TEXT` | YES | None | Optional custom inquiry message. |
| `created_at` | `TIMESTAMPTZ` | NO | `DEFAULT CURRENT_TIMESTAMP` | Lead submission timestamp. |

---

### 3.11 Table: `site_visits`
Physical property walkthrough appointments.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `visit_id` | `INT` | NO | `PRIMARY KEY` | Unique appointment identifier. |
| `property_id` | `INT` | NO | `REFERENCES properties(property_id) ON DELETE CASCADE` | Property to be visited. |
| `user_id` | `INT` | NO | `REFERENCES users(user_id) ON DELETE RESTRICT` | Scheduled visitor. |
| `scheduled_at` | `TIMESTAMPTZ` | NO | None | Agreed calendar time of appointment. |
| `status` | `VARCHAR(15)` | NO | `CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW'))` | Visit fulfillment status. |
| `feedback_rating`| `SMALLINT` | YES | `CHECK (feedback_rating IS NULL OR feedback_rating BETWEEN 1 AND 5)` | Post-visit experience rating (1 to 5 stars). |

---

### 3.12 Table: `shortlists`
User bookmarks for properties of interest.

| Column | Data Type | Nullable | Constraints & Defaults | Description & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `user_id` | `INT` | NO | `REFERENCES users(user_id) ON DELETE CASCADE` | User saving listing. Cascades if user profile deleted. |
| `property_id` | `INT` | NO | `REFERENCES properties(property_id) ON DELETE CASCADE` | Bookmarked property. Cascades if listing deleted. |
| `added_at` | `TIMESTAMPTZ` | NO | `DEFAULT CURRENT_TIMESTAMP` | Time listing was saved. |

*Primary Key:* Composite `PRIMARY KEY (user_id, property_id)`.

---

## 4. Normalization & Functional Dependency (FD) Analysis

Every table was analyzed against functional dependencies to determine its highest normal form.

### 4.1 `cities`
- **Candidate Key:** `{city_id}`, `{city_name}`
- **FDs:**
  - `city_id -> city_name, state`
  - `city_name -> city_id, state`
- **Normal Form:** **BCNF**. Every determinant is a candidate key. No partial or transitive dependencies exist.

### 4.2 `localities`
- **Candidate Key:** `{locality_id}`, `{city_id, locality_name}`
- **FDs:**
  - `locality_id -> city_id, locality_name, pincode, center_lat, center_lng`
  - `{city_id, locality_name} -> locality_id, pincode, center_lat, center_lng`
- **Normal Form:** **BCNF**. Determinants are candidate keys. No non-prime attribute determines another non-prime attribute.

### 4.3 `builders`
- **Candidate Key:** `{builder_id}`, `{builder_name}`
- **FDs:**
  - `builder_id -> builder_name, founded_year`
  - `builder_name -> builder_id, founded_year`
- **Normal Form:** **BCNF**. All determinants are superkeys.

### 4.4 `projects`
- **Candidate Key:** `{project_id}`
- **FDs:**
  - `project_id -> builder_id, locality_id, project_name, rera_id, possession_status, possession_date, total_units`
- **Normal Form:** **3NF / BCNF**. All non-prime attributes functionally depend directly on the primary key `project_id`. Builder details (e.g. name, founded year) and locality details reside in their own tables, eliminating transitive dependencies.

### 4.5 `amenities`
- **Candidate Key:** `{amenity_id}`, `{amenity_name}`
- **FDs:**
  - `amenity_id -> amenity_name`
  - `amenity_name -> amenity_id`
- **Normal Form:** **BCNF**.

### 4.6 `project_amenities`
- **Candidate Key:** `{project_id, amenity_id}`
- **FDs:**
  - `{project_id, amenity_id} -> (all attributes in key)` (All-key relation)
- **Normal Form:** **BCNF / 4NF / 5NF**. Pure association table without non-key attributes; eliminates multi-valued dependency anomalies.

### 4.7 `users`
- **Candidate Key:** `{user_id}`, `{phone}`, `{email}` (for non-null email)
- **FDs:**
  - `user_id -> full_name, phone, email, user_type, agent_rera_id, created_at`
  - `phone -> user_id, full_name, email, user_type, agent_rera_id, created_at`
- **Normal Form:** **BCNF**. All determinants are candidate keys.

### 4.8 `properties`
- **Candidate Key:** `{property_id}`
- **FDs:**
  - `property_id -> listed_by, project_id, locality_id, listing_type, property_type, bhk, carpet_area_sqft, floor_no, total_floors, furnishing, facing, price, maintenance_monthly, security_deposit, available_from, latitude, longitude, is_verified, status, posted_at`
- **Normal Form:** **3NF / BCNF**. All attributes are fully functionally dependent on `property_id`. Locality, project, and lister information are normalized into separate relations, preventing transitive update anomalies.

### 4.9 `price_changes`
- **Candidate Key:** `{change_id}`
- **FDs:**
  - `change_id -> property_id, old_price, new_price, changed_at`
- **Normal Form:** **BCNF**. Historical append log with no transitive attributes.

### 4.10 `enquiries`
- **Candidate Key:** `{enquiry_id}`
- **FDs:**
  - `enquiry_id -> property_id, user_id, channel, message, created_at`
- **Normal Form:** **BCNF**.

### 4.11 `site_visits`
- **Candidate Key:** `{visit_id}`
- **FDs:**
  - `visit_id -> property_id, user_id, scheduled_at, status, feedback_rating`
- **Normal Form:** **BCNF**.

### 4.12 `shortlists`
- **Candidate Key:** `{user_id, property_id}`
- **FDs:**
  - `{user_id, property_id} -> added_at`
- **Normal Form:** **BCNF**. Composite primary key determines the timestamp attribute; no partial key dependencies.

---

## 5. Referential Integrity & Foreign Key Deletion Justifications

| Foreign Key | Parent Table | Child Table | Deletion Rule | Architectural & Business Justification |
| :--- | :--- | :--- | :--- | :--- |
| `localities(city_id)` | `cities` | `localities` | `ON DELETE RESTRICT` | A city cannot be deleted if active localities exist within it. Prevents accidental geographic data corruption. |
| `projects(builder_id)` | `builders` | `projects` | `ON DELETE RESTRICT` | A builder cannot be purged while their residential projects remain in the registry. |
| `projects(locality_id)`| `localities` | `projects` | `ON DELETE RESTRICT` | A locality cannot be removed while projects are situated there. |
| `project_amenities(project_id)` | `projects` | `project_amenities` | `ON DELETE CASCADE` | If a project record is deleted, its amenity linkages have no independent existence and should be purged. |
| `project_amenities(amenity_id)` | `amenities` | `project_amenities` | `ON DELETE RESTRICT` | Prevents deleting standard catalog amenities that are actively referenced by projects. |
| `properties(listed_by)` | `users` | `properties` | `ON DELETE RESTRICT` | Platform compliance and fraud prevention: user accounts with listed properties cannot be deleted without first archiving or reassigning their listings. |
| `properties(project_id)`| `projects` | `properties` | `ON DELETE SET NULL` | If a master project society record is removed, individual property listings remain valid as independent listings rather than being deleted. |
| `properties(locality_id)`| `localities` | `properties` | `ON DELETE RESTRICT` | Locality is mandatory for geographic search filtering and cannot be orphaned. |
| `price_changes(property_id)` | `properties` | `price_changes` | `ON DELETE CASCADE` | Price change history is an audit trail belonging exclusively to that listing; deleting the listing cascades to its history. |
| `enquiries(property_id)` | `properties` | `enquiries` | `ON DELETE CASCADE` | Leads sent on a specific listing are purged if the listing itself is permanently removed. |
| `enquiries(user_id)` | `users` | `enquiries` | `ON DELETE RESTRICT` | Audit integrity: maintains record of consumer communication history. |
| `site_visits(property_id)` | `properties` | `site_visits` | `ON DELETE CASCADE` | Appointments booked for a property are deleted if the property is purged. |
| `site_visits(user_id)` | `users` | `site_visits` | `ON DELETE RESTRICT` | Prevents deleting user accounts with past or scheduled appointments. |
| `shortlists(user_id)` | `users` | `shortlists` | `ON DELETE CASCADE` | When a seeker deletes their account, their private bookmarks are deleted. |
| `shortlists(property_id)` | `properties` | `shortlists` | `ON DELETE CASCADE` | When a property listing is permanently removed, user bookmarks for it are cleared. |

---

## 6. Data Quality Findings & CSV Ingestion Strategy

During Phase 1 data inspection, several nuances in the raw CSV files were identified:

1. **Blank / Empty Values**:
   - `properties.csv`: 54,009 rows have blank `project_id` (independent houses, villas, and plots do not belong to builder projects).
   - `properties.csv`: 3,616 rows have blank `bhk`, `total_floors`, and `furnishing` (plots of land do not have rooms, floors, or furnishings).
   - `properties.csv`: 22,365 rows have blank `floor_no` (plots and single-family houses).
   - `properties.csv`: 54,060 rows have blank `security_deposit` (SALE listings do not have security deposits; only RENT listings do).
   - `properties.csv`: 54,009 rows have blank `maintenance_monthly`.
   - `enquiries.csv`: 50,057 rows have empty `message` fields (users opted for quick click-to-enquire without a text note).
   - `site_visits.csv`: 20,426 rows have empty `feedback_rating` (scheduled, cancelled, or unrated completed visits).
   - `users.csv`: 15,990 rows have empty `email` (phone-only registrations); 37,951 rows have empty `agent_rera_id` (seekers and owners do not have agent licenses).
   - `projects.csv`: 171 rows have empty `rera_id` (older projects built prior to RERA mandates).
   - **Resolution**: In `sql/02_load_data.sql`, `\copy` is executed with `WITH (FORMAT csv, HEADER true, NULL '')`. This converts all unquoted empty string fields directly into standard SQL `NULL` values.

2. **Boolean Encoding**:
   - In `properties.csv`, `is_verified` uses `'t'` and `'f'`. PostgreSQL's native `BOOLEAN` type parses `'t'` / `'f'` seamlessly during ingestion.

3. **Ingestion Dependency Order**:
   - Loading must follow topological ordering:
     1. Independent tables: `cities`, `builders`, `amenities`, `users`
     2. Second-tier references: `localities`, `projects`, `project_amenities`
     3. Core listing table: `properties`
     4. Interaction logs: `price_changes`, `enquiries`, `site_visits`, `shortlists`

---

## 7. Integrity Verification Checks

Three domain-specific integrity checks were executed against the populated database:

### Check 1: Property Locality vs. Project Locality Consistency
*Rule:* Every property associated with a builder project must share the exact same `locality_id` as the project itself.
```sql
SELECT count(*) AS check1_mismatches
FROM housing.properties p
JOIN housing.projects pj ON pj.project_id = p.project_id
WHERE p.locality_id <> pj.locality_id;
```
*Result:* **`0` mismatches**. (All 66,051 project-linked properties reside in the same locality as their parent project.)

---

### Check 2: Current Price Consistency with Latest Price Change
*Rule:* If a property has undergone price modifications in `price_changes`, its current `price` in `properties` must match the `new_price` of its latest price change event.
```sql
WITH latest_changes AS (
    SELECT DISTINCT ON (property_id) property_id, new_price
    FROM housing.price_changes
    ORDER BY property_id, changed_at DESC, change_id DESC
)
SELECT count(*) AS check2_price_mismatches
FROM housing.properties p
JOIN latest_changes lc ON lc.property_id = p.property_id
WHERE p.price <> lc.new_price;
```
*Result:* **`0` mismatches**. (Every property with price changes reflects the latest revised price.)

---

### Check 3: Property Lister Role Integrity
*Rule:* Only platform users classified as `OWNER` or `AGENT` may post property listings (`SEEKER` users cannot list properties).
```sql
SELECT count(*) AS check3_invalid_listers
FROM housing.properties p
JOIN housing.users u ON u.user_id = p.listed_by
WHERE u.user_type NOT IN ('OWNER', 'AGENT');
```
*Result:* **`0` invalid listers**. (All 120,060 property listings were posted strictly by verified owners and agents.)

---

## 8. Workload Verification & Compatibility

The complete faculty workload (`queries/workload_30.sql`) was executed against the populated schema:
- **Read Queries Tested:** `R01` through `R25` (25 read queries)
- **Write Queries Tested:** `W01` through `W05` (5 write queries)
- **Outcome:** **100% of queries executed successfully with zero syntax, constraint, or type mismatch errors.**
- All queries ran inside `BEGIN ... ROLLBACK`, guaranteeing the seed dataset remains clean and reproducible for subsequent checkpoint benchmarking.
