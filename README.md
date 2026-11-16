# 🛰️ EarthSOC Sentinel
**NASA Space Apps Challenge 2026 | Challenge: *Be An Earth System Trend Detective!***

EarthSOC Sentinel applies cybersecurity Security Operations Center (SOC) principles to Earth observation—ingesting live **NASA FIRMS VIIRS NOAA-21** satellite thermal telemetry into **Google Cloud BigQuery**, suppressing low-confidence sensor noise via SQL detection rules, computing Z-score statistical anomaly tests across multi-day orbital passes, and surfacing prioritized incidents on an interactive dark-mode SIEM console.

## Architecture & Pipeline
1. **Data Ingestion:** NASA VIIRS NOAA-21 thermal detections (`nasa_firms_threats.csv`) loaded into Google Cloud BigQuery (`earthsoc-sentinel.nasa_telemetry.raw_firms_detections`).
2. **SQL SIEM & Statistical Triage Engine (`soc_triage_engine.sql`):** Filters false positives (`confidence != 'l'`), assigns UUID alert IDs, classifies severity tiers (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`), and calculates statistical Z-scores ($Z = (x - \mu)/\sigma$) to flag statistically significant ($Z \ge 2.0\sigma$, $p < 0.05$) thermal surges.
3. **Interactive Console (`dashboard.html`):** Dark-mode geospatial hotspot map (Leaflet.js), multi-day temporal trend & mean FRP chart (Chart.js), and filterable event log across 500 triaged alerts.

## Data Sources & Credits
- **NASA Data:** NASA Fire Information for Resource Management System (FIRMS) — VIIRS NOAA-21 NRT Active Fire / Thermal Anomalies dataset (`https://firms.modaps.eosdis.nasa.gov/`).
- **Mapping & Visualization Libraries:** Leaflet.js, Esri World Dark Gray Base basemap tiles, and Chart.js.
- **AI Tools Disclosure:** Google Gemini was used during development as a technical coding assistant for SQL query structuring, shell build scripting, and HTML/CSS/JavaScript dashboard scaffolding.

## License
This project is open-source and licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.
