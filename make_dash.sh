#!/bin/zsh
CSV="triaged_soc_alerts.csv"
OUT="dashboard.html"
TOTAL=$(awk 'NR>1 && NF>0 {c++} END {print c+0}' "$CSV")
CRIT=$(awk -F',' 'NR>1 && $10=="CRITICAL" {c++} END {print c+0}' "$CSV")
HIGH=$(awk -F',' 'NR>1 && $10=="HIGH" {c++} END {print c+0}' "$CSV")
MED=$(awk -F',' 'NR>1 && $10=="MEDIUM" {c++} END {print c+0}' "$CSV")
LOW=$(awk -F',' 'NR>1 && $10=="LOW" {c++} END {print c+0}' "$CSV")
MEDLOW=$((MED + LOW))
MAX_FRP=$(awk -F',' 'NR>1 && $8+0 > m {m=$8+0} END {printf "%.2f", m}' "$CSV")
AVG_TEMP=$(awk -F',' 'NR>1 && $7+0 > 0 {s+=$7+0; c++} END {if(c>0) printf "%.1f", s/c; else print "0"}' "$CSV")

ROWS=$(awk -F',' 'NR>1 && NR<=151 && NF>=12 {
  sev=$10; lsev=tolower(sev);
  printf "<tr data-severity=\"%s\"><td><code>%.8s...</code></td><td>%s %s UTC</td><td>%s, %s</td><td><strong>%s MW</strong></td><td>%s K</td><td><span class=\"badge badge-%s\">%s</span></td><td>%s</td><td>%s</td></tr>\n", sev, $1, $2, $3, $4, $5, $8, $7, lsev, sev, $11, $12
}' "$CSV")

JSON_POINTS=$(awk -F',' 'NR>1 && NR<=201 && NF>=12 {
  printf "{\"lat\":%s,\"lon\":%s,\"frp\":%s,\"temp\":%s,\"sev\":\"%s\",\"act\":\"%s\"},", $4, $5, $8, $7, $10, $11
}' "$CSV")

cat << HTML > "$OUT"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>EarthSOC Sentinel | Planetary Threat & Anomaly Console</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
<script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
<style>
  :root { --bg:#0b0f19; --panel:#131a2a; --border:#1f2b44; --text:#e2e8f0; --muted:#94a3b8; --crit:#ef4444; --high:#f97316; --med:#eab308; --low:#22c55e; --accent:#38bdf8; }
  body { margin:0; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif; background:var(--bg); color:var(--text); padding:24px; }
  header { display:flex; justify-content:space-between; align-items:center; border-bottom:1px solid var(--border); padding-bottom:16px; margin-bottom:24px; flex-wrap:wrap; gap:12px; }
  h1 { margin:0; font-size:1.5rem; color:var(--accent); }
  .subtitle { color:var(--muted); font-size:0.9rem; margin-top:4px; }
  .status-pill { background:rgba(34,197,94,0.15); color:var(--low); border:1px solid var(--low); padding:6px 12px; border-radius:999px; font-size:0.8rem; font-weight:600; }
  .kpi-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:16px; margin-bottom:24px; }
  .card { background:var(--panel); border:1px solid var(--border); border-radius:10px; padding:16px; }
  .kpi-label { color:var(--muted); font-size:0.8rem; text-transform:uppercase; }
  .kpi-val { font-size:1.8rem; font-weight:700; margin-top:6px; }
  .main-grid { display:grid; grid-template-columns:1.4fr 1fr; gap:20px; margin-bottom:24px; }
  #map { height:340px; border-radius:8px; background:#090d16; }
  .controls { margin-bottom:12px; display:flex; gap:8px; flex-wrap:wrap; }
  button { background:var(--panel); color:var(--text); border:1px solid var(--border); padding:6px 14px; border-radius:6px; cursor:pointer; font-weight:600; }
  button:hover, button.active { border-color:var(--accent); color:var(--accent); }
  table { width:100%; border-collapse:collapse; font-size:0.85rem; }
  th, td { text-align:left; padding:10px 12px; border-bottom:1px solid var(--border); }
  th { color:var(--muted); font-weight:600; }
  .badge { padding:3px 8px; border-radius:4px; font-weight:700; font-size:0.75rem; }
  .badge-critical { background:rgba(239,68,68,0.2); color:var(--crit); }
  .badge-high { background:rgba(249,115,22,0.2); color:var(--high); }
  .badge-medium { background:rgba(234,179,8,0.2); color:var(--med); }
  .badge-low { background:rgba(34,197,94,0.2); color:var(--low); }
</style>
</head>
<body>
<header>
  <div><h1>🛰️ EarthSOC Sentinel — Planetary Threat & Anomaly Console</h1>
  <div class="subtitle">NASA VIIRS NOAA-21 Telemetry • Google Cloud BigQuery SIEM Triage Pipeline</div></div>
  <div class="status-pill">● LIVE TELEMETRY FEED ($TOTAL TRIAGED EVENTS)</div>
</header>
<div class="kpi-grid">
  <div class="card"><div class="kpi-label">Critical Incidents</div><div class="kpi-val" style="color:var(--crit)">$CRIT</div></div>
  <div class="card"><div class="kpi-label">High Severity</div><div class="kpi-val" style="color:var(--high)">$HIGH</div></div>
  <div class="card"><div class="kpi-label">Medium / Low</div><div class="kpi-val">$MEDLOW</div></div>
  <div class="card"><div class="kpi-label">Peak Radiative Power</div><div class="kpi-val" style="color:var(--accent)">$MAX_FRP MW</div></div>
  <div class="card"><div class="kpi-label">Mean Brightness Temp</div><div class="kpi-val">$AVG_TEMP K</div></div>
</div>
<div class="main-grid">
  <div class="card"><h3 style="margin-top:0">Geospatial Thermal Anomaly Map</h3><div id="map"></div></div>
  <div class="card"><h3 style="margin-top:0">SOC Alert Severity Distribution</h3><canvas id="sevChart" height="230"></canvas></div>
</div>
<div class="card">
  <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;">
    <h3 style="margin-top:0">Triaged Security & Environmental Event Log</h3>
    <div class="controls">
      <button class="active" onclick="filterTable('ALL',this)">All ($TOTAL)</button>
      <button onclick="filterTable('CRITICAL',this)">Critical ($CRIT)</button>
      <button onclick="filterTable('HIGH',this)">High ($HIGH)</button>
      <button onclick="filterTable('MEDIUM',this)">Medium ($MED)</button>
    </div>
  </div>
  <div style="overflow-x:auto;"><table id="alertTable"><thead><tr><th>Alert ID</th><th>Timestamp</th><th>Coordinates</th><th>FRP Output</th><th>Temp (TI4)</th><th>Severity</th><th>SOC Action</th><th>Orbit</th></tr></thead><tbody>$ROWS</tbody></table></div>
</div>
<script>
const alertsData=[${JSON_POINTS%,}];
const map=L.map('map').setView([25,-40],2);
L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',{attribution:'&copy; OpenStreetMap &copy; CARTO'}).addTo(map);
const colors={CRITICAL:'#ef4444',HIGH:'#f97316',MEDIUM:'#eab308',LOW:'#22c55e'};
alertsData.forEach(a=>{const c=colors[a.sev]||'#38bdf8';L.circleMarker([a.lat,a.lon],{radius:a.sev==='CRITICAL'?7:4,color:c,fillColor:c,fillOpacity:0.75,weight:1}).bindPopup(\`<b>\${a.sev} ANOMALY</b><br>FRP: \${a.frp} MW<br>Temp: \${a.temp} K<br>Action: \${a.act}\`).addTo(map);});
new Chart(document.getElementById('sevChart'),{type:'doughnut',data:{labels:['Critical','High','Medium','Low'],datasets:[{data:[$CRIT,$HIGH,$MED,$LOW],backgroundColor:['#ef4444','#f97316','#eab308','#22c55e'],borderWidth:0}]},options:{plugins:{legend:{labels:{color:'#e2e8f0'}}}}});
function filterTable(sev,btn){document.querySelectorAll('.controls button').forEach(b=>b.classList.remove('active'));btn.classList.add('active');document.querySelectorAll('#alertTable tbody tr').forEach(tr=>{tr.style.display=(sev==='ALL'||tr.dataset.severity===sev)?'':'none';});}
</script>
</body>
</html>
HTML
open "$OUT"
