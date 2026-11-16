# 🛰️ EarthSOC Sentinel
**NASA Space Apps Challenge 2026 | Challenge: *Be An Earth System Trend Detective!***

EarthSOC Sentinel applies cybersecurity Security Operations Center (SOC) principles to Earth observation—ingesting live **NASA FIRMS VIIRS NOAA-21** satellite thermal telemetry into **Google Cloud BigQuery**, suppressing low-confidence sensor noise via SQL detection rules, and surfacing prioritized anomalies on an interactive dark-mode SIEM console.

## Architecture & Pipeline
1. **Data Ingestion:** NASA VIIRS NOAA-21 24-hour thermal detections (`nasa_firms_threats.csv`) loaded into BigQuery (`earthsoc-sentinel.nasa_telemetry.raw_firms_detections`).
2. **SQL SIEM Triage Engine (`soc_triage_engine.sql`):** Filters false positives (`confidence != 'l'`), assigns UUID alert IDs, classifies severity tiers (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`), and routes Tier-2 escalations.
3. **Interactive Console (`dashboard.html`):** Dark-mode geospatial hotspot map (Leaflet.js), severity breakdown chart (Chart.js), and filterable event log across 500 triaged alerts.
