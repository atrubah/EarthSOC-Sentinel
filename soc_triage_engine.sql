-- EarthSOC Sentinel: SIEM-Style Thermal Anomaly & Triage Engine
SELECT
  GENERATE_UUID() AS alert_id,
  acq_date AS detection_date,
  LPAD(CAST(acq_time AS STRING), 4, '0') AS utc_time,
  ROUND(latitude, 4) AS latitude,
  ROUND(longitude, 4) AS longitude,
  satellite,
  ROUND(bright_ti4, 2) AS brightness_kelvin,
  ROUND(frp, 2) AS fire_radiative_power_mw,
  confidence AS raw_confidence,
  CASE
    WHEN frp >= 100.0 AND confidence = 'h' THEN 'CRITICAL'
    WHEN frp >= 50.0 OR confidence = 'h' THEN 'HIGH'
    WHEN frp >= 15.0 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS soc_severity,
  CASE
    WHEN confidence = 'l' THEN 'SUPPRESSED_FALSE_POSITIVE'
    WHEN frp >= 50.0 THEN 'ESCALATE_TIER2_INCIDENT'
    ELSE 'ACTIVE_MONITORING'
  END AS triage_status,
  CASE
    WHEN daynight = 'D' THEN 'Daytime Pass'
    ELSE 'Nighttime Pass'
  END AS orbit_pass
FROM
  `earthsoc-sentinel.nasa_telemetry.raw_firms_detections`
WHERE
  confidence != 'l'
ORDER BY
  fire_radiative_power_mw DESC
LIMIT 500;
