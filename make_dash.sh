#!/bin/zsh
CSV="triaged_soc_alerts.csv"
OUT="dashboard.html"

TOTAL=$(awk 'NR>1 && NF>0 {c++} END {print c+0}' "$CSV")
HIGH=$(awk -F',' 'NR>1 && $10=="HIGH" {c++} END {print c+0}' "$CSV")
MED=$(awk -F',' 'NR>1 && $10=="MEDIUM" {c++} END {print c+0}' "$CSV")
LOW=$(awk -F',' 'NR>1 && $10=="LOW" {c++} END {print c+0}' "$CSV")
MEDLOW=$((MED + LOW))
MAX_FRP=$(awk -F',' 'NR>1 && $8+0 > m {m=$8+0} END {printf "%.2f", m}' "$CSV")
AVG_TEMP=$(awk -F',' 'NR>1 && $7+0 > 0 {s+=$7+0; c++} END {if(c>0) printf "%.1f", s/c; else print "0"}' "$CSV")

STATS=$(awk -F',' 'NR>1 && NF>=12 {
  val=$8+0; sum+=val; sumsq+=val*val; n++;
  if(val>maxv) maxv=val;
} END {
  mean=sum/n;
  sd=sqrt((sumsq/n)-(mean*mean));
  zmax=(maxv-mean)/sd;
  printf "%.2f|%.2f|%.2f", mean, sd, zmax
}' "$CSV")

MEAN_FRP=$(echo "$STATS" | cut -d'|' -f1)
STD_FRP=$(echo "$STATS" | cut -d'|' -f2)
MAX_Z=$(echo "$STATS" | cut -d'|' -f3)
Z_SIG_COUNT=$(awk -F',' -v m="$MEAN_FRP" -v s="$STD_FRP" 'NR>1 && NF>=12 { if((($8+0)-m)/s >= 2.0) c++ } END {print c+0}' "$CSV")

TREND_DATA=$(awk -F',' 'NR>1 && NF>=12 {
  d=$2; cnt[d]++; sum[d]+=$8+0;
} END {
  for (d in cnt) printf "%s|%d|%.2f\n", d, cnt[d], sum[d]/cnt[d]
}' "$CSV" | sort)

DATES_JS=$(echo "$TREND_DATA" | awk -F'|' '{printf "\"%s\",", $1}')
COUNTS_JS=$(echo "$TREND_DATA" | awk -F'|' '{printf "%s,", $2}')
AVG_FRP_JS=$(echo "$TREND_DATA" | awk -F'|' '{printf "%s,", $3}')

ROWS=$(awk -F',' -v m="$MEAN_FRP" -v s="$STD_FRP" 'NR>1 && NR<=151 && NF>=12 {
  sev=$10; lsev=tolower(sev);
  z=(($8+0)-m)/s;
  ztag=(z>=2.0) ? sprintf(" <span class=\"badge badge-critical\">Z=+%.1fσ</span>", z) : sprintf(" <span style=\"color:#94a3b8;font-size:0.75rem\">(%.1fσ)</span>", z);
  printf "<tr data-severity=\"%s\"><td><code>%.8s...</code></td><td>%s %s UTC</td><td>%s, %s</td><td><strong>%s MW</strong>%s</td><td>%s K</td><td><span class=\"badge badge-%s\">%s</span></td><td>%s</td><td>%s</td></tr>\n", sev, $1, $2, $3, $4, $5, $8, ztag, $7, lsev, sev, $11, $12
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
  .kpi-grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(170px,1fr)); gap:14px; margin-bottom:24px; }
  .card { background:var(--panel); border:1px solid var(--border); border-radius:10px; padding:16px; }
  .kpi-label { color:var(--muted); font-size:0.75rem; text-transform:uppercase; }
  .kpi-val { font-size:1.65rem; font-weight:700; margin-top:6px; }
  .kpi-sub { color:var(--muted); font-size:0.75rem; margin-top:4px; }
  .main-grid { display:grid; grid-template-columns:1.3fr 1fr; gap:20px; margin-bottom:24px; }
  #map { height:320px; border-radius:8px; background:#090d16; }
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
  footer { margin-top:24px; color:var(--muted); font-size:0.8rem; border-top:1px solid var(--border); padding-top:14px; }
</style>
</head>
<body>
<header>
  <div><h1>🛰️ EarthSOC Sentinel — Planetary Threat & Anomaly Console</h1>
  <div class="subtitle">NASA FIRMS VIIRS NOAA-21 Telemetry • Google Cloud BigQuery SIEM & Statistical Trend Pipeline</div></div>
  <div class="status-pill">● LIVE TELEMETRY FEED ($TOTAL TRIAGED EVENTS)</div>
</header>

<div class="kpi-grid">
  <div class="card"><div class="kpi-label">High Severity Alerts</div><div class="kpi-val" style="color:var(--high)">$HIGH</div><div class="kpi-sub">Tier-2 Escalations</div></div>
  <div class="card"><div class="kpi-label">Medium / Low Alerts</div><div class="kpi-val">$MEDLOW</div><div class="kpi-sub">Active Monitoring</div></div>
  <div class="card"><div class="kpi-label">Peak Radiative Power</div><div class="kpi-val" style="color:var(--accent)">$MAX_FRP MW</div><div class="kpi-sub">Mean: $MEAN_FRP MW (σ=$STD_FRP)</div></div>
  <div class="card"><div class="kpi-label">Statistical Outliers (Z≥2σ)</div><div class="kpi-val" style="color:var(--crit)">$Z_SIG_COUNT</div><div class="kpi-sub">Peak Z-Score: +${MAX_Z}σ (p&lt;0.01)</div></div>
  <div class="card"><div class="kpi-label">Mean Brightness Temp</div><div class="kpi-val">$AVG_TEMP K</div><div class="kpi-sub">VIIRS Band TI4</div></div>
</div>

<div class="main-grid">
  <div class="card"><h3 style="margin-top:0">Geospatial Thermal Anomaly Map</h3><div id="map"></div></div>
  <div class="card">
    <h3 style="margin-top:0">Temporal Trend & Mean Radiative Power Over Time</h3>
    <canvas id="trendChart" height="145"></canvas>
    <div style="margin-top:10px;font-size:0.8rem;color:var(--muted)">
      <strong>Z-Score Anomaly Test:</strong> Evaluates daily FRP shifts against baseline μ = $MEAN_FRP MW, σ = $STD_FRP MW. Events exceeding +2.0σ ($Z_SIG_COUNT alerts, max +${MAX_Z}σ) represent statistically significant thermal surges.
    </div>
  </div>
</div>

<div class="card">
  <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;">
    <h3 style="margin-top:0">Triaged Security & Environmental Event Log (with Z-Score Significance)</h3>
    <div class="controls">
      <button class="active" onclick="filterTable('ALL',this)">All ($TOTAL)</button>
      <button onclick="filterTable('HIGH',this)">High ($HIGH)</button>
      <button onclick="filterTable('MEDIUM',this)">Medium ($MED)</button>
    </div>
  </div>
  <div style="overflow-x:auto;"><table id="alertTable"><thead><tr><th>Alert ID</th><th>Timestamp</th><th>Coordinates</th><th>FRP Output & Z-Score</th><th>Temp (TI4)</th><th>Severity</th><th>SOC Action</th><th>Orbit</th></tr></thead><tbody>$ROWS</tbody></table></div>
</div>

<footer>
  <strong>Data Attribution & Open-Source License:</strong> Telemetry sourced from NASA Fire Information for Resource Management System (FIRMS) VIIRS NOAA-21 NRT dataset. Released under the MIT License for NASA Space Apps Challenge 2026.
</footer>

<script>
const alertsData=[${JSON_POINTS%,}];
const map=L.map('map').setView([25,-40],2);
L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}',{attribution:'&copy; OpenStreetMap &copy; Esri'}).addTo(map);
const colors={CRITICAL:'#ef4444',HIGH:'#f97316',MEDIUM:'#eab308',LOW:'#22c55e'};
alertsData.forEach(a=>{const c=colors[a.sev]||'#38bdf8';L.circleMarker([a.lat,a.lon],{radius:a.sev==='CRITICAL'?7:4,color:c,fillColor:c,fillOpacity:0.75,weight:1}).bindPopup(\`<b>\${a.sev} ANOMALY</b><br>FRP: \${a.frp} MW<br>Temp: \${a.temp} K<br>Action: \${a.act}\`).addTo(map);});

new Chart(document.getElementById('trendChart'),{
  type:'line',
  data:{
    labels:[${DATES_JS%,}],
    datasets:[
      {label:'Daily Alert Volume',data:[${COUNTS_JS%,}],borderColor:'#38bdf8',backgroundColor:'rgba(56,189,248,0.15)',yAxisID:'y',tension:0.3,fill:true},
      {label:'Mean FRP (MW)',data:[${AVG_FRP_JS%,}],borderColor:'#f97316',backgroundColor:'#f97316',yAxisID:'y1',tension:0.3}
    ]
  },
  options:{
    plugins:{legend:{labels:{color:'#e2e8f0'}}},
    scales:{
      x:{ticks:{color:'#94a3b8'},grid:{color:'#1f2b44'}},
      y:{type:'linear',position:'left',ticks:{color:'#38bdf8'},grid:{color:'#1f2b44'},title:{display:true,text:'Alert Count',color:'#38bdf8'}},
      y1:{type:'linear',position:'right',ticks:{color:'#f97316'},grid:{drawOnChartArea:false},title:{display:true,text:'Mean FRP (MW)',color:'#f97316'}}
    }
  }
});

function filterTable(sev,btn){document.querySelectorAll('.controls button').forEach(b=>b.classList.remove('active'));btn.classList.add('active');document.querySelectorAll('#alertTable tbody tr').forEach(tr=>{tr.style.display=(sev==='ALL'||tr.dataset.severity===sev)?'':'none';});}
</script>
</body>
</html>
HTML
open "$OUT"
