# Phase 1: Problem Understanding

## Business Context

Housing.com supports renting and buying homes through property listings, projects, builders and localities. Users can search, shortlist properties, send enquiries and schedule site visits. The existing database has no documented schema, and several product operations are experiencing performance issues.

## Business Problems

| Problem | Business need and affected stakeholder | Classification | Related queries |
|---------|----------------------------------------|----------------|-----------------|
| P1: Slow rent and buy searches | Home seekers (tenants and buyers) need fast property searches with filters, price per sq. ft., map view and amenity filters. | Customer-facing / real-time | R01, R02, R05, R09, R16 |
| P2: Slow property and project pages | Buyers, tenants and investors need property and project details, including RERA information, to load quickly. | Customer-facing / real-time | R03, R10, R11, R24 |
| P3: Slow owner and agent operations | Owners and agents need responsive dashboards, site-visit schedules, price-change history and listing status updates. | Customer-facing / real-time | R06, R07, W01, W02, W03, W05 |
| P4: Delayed alerts and follow-ups | Owners, agents and seekers need timely price-drop alerts, lead follow-ups and identification of stale listings. | Customer-facing / real-time | R08, R12, R17 |
| P5: Empty projects-without-listings report | Builder-partnership teams need to identify projects that have no property listings so they can improve listing coverage. | Reporting / analytics | R13 |
| P6: Slow business insights | Investors, agents and growth teams need price trends, rental yield, agent rankings, visit ratings and conversion-funnel insights. | Reporting / analytics | R04, R14, R15, R21, R25 |
| P7: Slow trust and safety reports with 20× growth expected | Trust and safety and platform teams need reliable reports and queries that continue performing as listing data grows. | Reporting / analytics | R18, R19, R20, R22, R23, W04 |

## Assumptions

1. Property searches, property pages and operational updates are expected to respond quickly because they directly support user and business activities.
2. Alerts and follow-ups are expected to run regularly, approximately every hour, as described in the problem statement.
3. Business insights and platform reports can involve larger data scans and are primarily analytical workloads.
4. The 20× growth mentioned in P7 refers to expected growth in listing data; the large dataset for testing will be supplied by the faculty.
5. Query results must remain correct while database performance is improved.

## Objective

The goal is to reconstruct a correct database schema from the available data exports, measure the performance of the 30 supplied SQL queries, optimize them without changing their results, and evaluate scalability using the larger dataset.
