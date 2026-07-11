const state = {
  overview: null,
  history: null,
  lastAction: null,
  resident: null,
  services: [],
  filter: "",
  autoRefresh: true,
  refreshIntervalSecs: 15,
  refreshTimer: null,
};

const $ = (id) => document.getElementById(id);

async function fetchJson(url, options = {}) {
  const response = await fetch(url, {
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
    ...options,
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(text || `HTTP ${response.status}`);
  }
  return response.json();
}

function metricCard(label, value, detail = "") {
  return `
    <article class="metric">
      <span>${label}</span>
      <strong>${value}</strong>
      ${detail ? `<div class="muted">${detail}</div>` : ""}
    </article>
  `;
}

function setRefreshState(text) {
  $("refreshState").textContent = text;
}

function queryWithFilter(path, serviceOverride = undefined) {
  const service = serviceOverride === undefined ? state.filter : serviceOverride;
  if (!service) {
    return path;
  }
  const joiner = path.includes("?") ? "&" : "?";
  return `${path}${joiner}service=${encodeURIComponent(service)}`;
}

function formatCpuMem(service) {
  const first = (service.stats || [])[0] || {};
  const cpu = first.cpu_percent == null ? "-" : `${first.cpu_percent.toFixed(2)}%`;
  const mem = first.mem_percent == null ? "-" : `${first.mem_percent.toFixed(2)}%`;
  return { cpu, mem };
}

function formatTopSignals(service) {
  const entries = Object.entries(service.signal_totals || {})
    .filter(([, count]) => Number(count) > 0)
    .sort((left, right) => Number(right[1]) - Number(left[1]))
    .slice(0, 3)
    .map(([name, count]) => `${name}:${count}`);
  return entries.join(" | ") || "-";
}

function renderMetrics(payload) {
  const services = payload.services || [];
  const ok = services.filter((item) => item.status === "ok").length;
  const degraded = services.filter((item) => item.status !== "ok").length;
  const avgScore =
    services.length > 0
      ? Math.round(services.reduce((sum, item) => sum + (item.quantum_score || 0), 0) / services.length)
      : 0;
  $("metrics").innerHTML = [
    metricCard("Tracked Services", String(services.length)),
    metricCard("Healthy", String(ok)),
    metricCard("Needs Attention", String(degraded)),
    metricCard("Average Score", `${avgScore}/100`, state.filter ? `filter: ${state.filter}` : (payload.generated_at || "")),
  ].join("");
}

function renderServiceFilter() {
  const select = $("serviceFilter");
  const current = state.filter;
  const options = ['<option value="">All services</option>']
    .concat(
      state.services.map((service) => {
        const selected = service === current ? " selected" : "";
        return `<option value="${service}"${selected}>${service}</option>`;
      }),
    )
    .join("");
  select.innerHTML = options;
}

function renderServices(payload) {
  const template = $("serviceCardTemplate");
  const servicesGrid = $("servicesGrid");
  servicesGrid.innerHTML = "";

  for (const service of payload.services || []) {
    const fragment = template.content.cloneNode(true);
    const root = fragment.querySelector(".service-card");
    const score = Math.max(0, Math.min(100, service.quantum_score || 0));
    const stats = formatCpuMem(service);
    const probe = service.healthcheck_target_path || (service.compose_healthcheck ? "custom" : "-");
    const topSignals = formatTopSignals(service);

    fragment.querySelector(".service-name").textContent = service.service;
    fragment.querySelector(".service-compose").textContent = service.compose_file.split("/").slice(-1)[0];

    const badge = fragment.querySelector(".service-status");
    badge.textContent = `${service.status} / ${service.risk_level}`;
    badge.classList.add(service.risk_level || service.status);

    fragment.querySelector(".score-fill").style.width = `${score}%`;

    fragment.querySelector(".service-stats").innerHTML = [
      `<div class="stat-row">Score: ${score} | Containers: ${service.container_count}</div>`,
      `<div class="stat-row">CPU: ${stats.cpu} | Memory: ${stats.mem}</div>`,
      `<div class="stat-row">Probe: ${probe} | Signals: ${topSignals}</div>`,
    ].join("");

    fragment.querySelector(".service-action").innerHTML = `
      <div class="action-row">Recommended: ${service.recommended_action} (${service.recommendation_confidence})</div>
      <div class="action-row">Cooldown: ${service.cooldown_remaining_secs || 0}s</div>
    `;

    fragment.querySelector(".service-controls").innerHTML = `
      <div class="control-actions">
        <button class="secondary small" data-action="diagnose" data-service="${service.service}">Diagnose</button>
        <button class="ghost small" data-action="rolling-restart" data-service="${service.service}">Rolling Restart</button>
      </div>
    `;

    fragment.querySelector(".reason-list").innerHTML = (service.reasons || [])
      .slice(0, 4)
      .map((reason) => `<div class="reason-chip">${reason}</div>`)
      .join("");

    root.style.animationDelay = `${servicesGrid.children.length * 40}ms`;
    servicesGrid.appendChild(fragment);
  }

  $("overviewMeta").textContent = state.filter ? `${payload.generated_at || "ready"} | ${state.filter}` : (payload.generated_at || "ready");
}

function renderHistory(payload) {
  const historyFeed = $("historyFeed");
  const events = payload.events || [];
  if (!events.length) {
    historyFeed.innerHTML = '<div class="muted">History henuz bos.</div>';
    return;
  }
  historyFeed.innerHTML = events
    .slice()
    .reverse()
    .map((event) => {
      const mode = event.mode ? ` | ${event.mode}` : "";
      return `
        <div class="history-row">
          <strong>${event.kind}${mode}</strong>
          <div class="muted">${event.timestamp || ""}</div>
        </div>
      `;
    })
    .join("");
}

function renderResident(payload) {
  const residentFeed = $("residentFeed");
  const resident = payload.resident_state || {};
  const heartbeat = payload.heartbeat || {};
  const lastReport = payload.last_report || {};
  const reports = payload.reports || [];
  residentFeed.innerHTML = [
    `
      <div class="history-row">
        <strong>Cycle ${resident.cycle || 0} | ${resident.last_diagnose_status || "unknown"}</strong>
        <div class="muted">heartbeat: ${heartbeat.timestamp || "-"}</div>
      </div>
    `,
    `
      <div class="history-row">
        <strong>Autopilot ${resident.last_autopilot_mode || "dry-run"}</strong>
        <div class="muted">actions: ${resident.last_autopilot_actions || 0}</div>
      </div>
    `,
    `
      <div class="history-row">
        <strong>Last report: ${lastReport.kind || "-"}</strong>
        <div class="muted">${lastReport.status || "unknown"} | ${lastReport.timestamp || "-"}</div>
      </div>
    `,
    ...reports.slice(0, 3).map(
      (report) => `
        <div class="history-row">
          <strong>${report.kind || "report"} | ${report.status || "unknown"}</strong>
          <div class="muted">${report.name || ""}</div>
        </div>
      `,
    ),
  ].join("");
}

function renderActions(payload) {
  const actionsFeed = $("actionsFeed");
  const actions = payload.actions || [];
  if (!actions.length) {
    actionsFeed.innerHTML = '<div class="muted">Aksiyon akisi beklemede.</div>';
    return;
  }
  actionsFeed.innerHTML = actions
    .map((action) => {
      const blocked = (action.blocked_by || []).join(", ") || "none";
      return `
        <div class="history-row">
          <strong>${action.service} -> ${action.decision}</strong>
          <div class="muted">blocked: ${blocked}</div>
        </div>
      `;
    })
    .join("");
}

async function refreshServicesCatalog() {
  const payload = await fetchJson("./api/services");
  state.services = (payload.services || [])
    .map((item) => item.service)
    .sort((left, right) => left.localeCompare(right));
  renderServiceFilter();
}

async function loadOverview() {
  setRefreshState("Refreshing...");
  const [services, overview, history, resident] = await Promise.all([
    fetchJson("./api/services"),
    fetchJson(queryWithFilter("./api/overview")),
    fetchJson("./api/history?limit=12"),
    fetchJson("./api/resident"),
  ]);
  state.services = (services.services || [])
    .map((item) => item.service)
    .sort((left, right) => left.localeCompare(right));
  state.overview = overview;
  state.history = history;
  state.resident = resident;
  renderServiceFilter();
  renderMetrics(overview);
  renderServices(overview);
  renderHistory(history);
  renderResident(resident);
  if (state.lastAction) {
    renderActions(state.lastAction);
  }
  setRefreshState(`Last refresh ${new Date().toLocaleTimeString()}`);
}

async function runDiagnose(service = state.filter || null) {
  setRefreshState(`Diagnosing ${service || "all services"}...`);
  const payload = await fetchJson(queryWithFilter("./api/diagnose", service || ""));
  state.overview = payload;
  renderMetrics(payload);
  renderServices(payload);
  state.history = await fetchJson("./api/history?limit=12");
  renderHistory(state.history);
  state.resident = await fetchJson("./api/resident");
  renderResident(state.resident);
  setRefreshState(`Diagnose complete ${new Date().toLocaleTimeString()}`);
}

async function runAutopilot(apply) {
  setRefreshState(`${apply ? "Applying" : "Planning"} autopilot...`);
  const payload = await fetchJson("./api/autopilot", {
    method: "POST",
    body: JSON.stringify({ apply, service: state.filter || null }),
  });
  state.lastAction = payload;
  renderActions(payload);
  state.history = await fetchJson("./api/history?limit=12");
  renderHistory(state.history);
  state.resident = await fetchJson("./api/resident");
  renderResident(state.resident);
  state.overview = await fetchJson(queryWithFilter("./api/overview"));
  renderMetrics(state.overview);
  renderServices(state.overview);
  setRefreshState(`Autopilot ${apply ? "apply" : "dry-run"} complete`);
}

async function runRollingRestart(service) {
  const confirmed = window.confirm(`${service} servisi icin rolling-restart calistirilsin mi?`);
  if (!confirmed) {
    return;
  }
  setRefreshState(`Rolling restart ${service}...`);
  const payload = await fetchJson("./api/rolling-restart", {
    method: "POST",
    body: JSON.stringify({ service, dry_run: false, delay_secs: 2.0 }),
  });
  state.lastAction = payload;
  renderActions(payload);
  await loadOverview();
  state.history = await fetchJson("./api/history?limit=12");
  renderHistory(state.history);
  state.resident = await fetchJson("./api/resident");
  renderResident(state.resident);
  setRefreshState(`Rolling restart complete for ${service}`);
}

function restartAutoRefresh() {
  if (state.refreshTimer) {
    clearInterval(state.refreshTimer);
    state.refreshTimer = null;
  }
  if (!state.autoRefresh) {
    setRefreshState("Auto-refresh paused");
    return;
  }
  $("autoRefreshLabel").textContent = "On";
  state.refreshTimer = setInterval(() => {
    loadOverview().catch((error) => setRefreshState(`Auto-refresh error: ${error.message}`));
  }, state.refreshIntervalSecs * 1000);
}

function bindServiceGridActions() {
  $("servicesGrid").addEventListener("click", async (event) => {
    const button = event.target.closest("button[data-action]");
    if (!button) {
      return;
    }
    const action = button.dataset.action;
    const service = button.dataset.service;
    if (!service) {
      return;
    }
    try {
      if (action === "diagnose") {
        await runDiagnose(service);
      } else if (action === "rolling-restart") {
        await runRollingRestart(service);
      }
    } catch (error) {
      setRefreshState(`Action failed: ${error.message}`);
    }
  });
}

async function boot() {
  $("refreshBtn").addEventListener("click", loadOverview);
  $("diagnoseBtn").addEventListener("click", runDiagnose);
  $("autopilotDryBtn").addEventListener("click", () => runAutopilot(false));
  $("autopilotApplyBtn").addEventListener("click", () => runAutopilot(true));
  $("serviceFilter").addEventListener("change", async (event) => {
    state.filter = event.target.value || "";
    await loadOverview();
  });
  $("clearFilterBtn").addEventListener("click", async () => {
    state.filter = "";
    $("serviceFilter").value = "";
    await loadOverview();
  });
  $("autoRefreshToggle").addEventListener("change", (event) => {
    state.autoRefresh = Boolean(event.target.checked);
    $("autoRefreshLabel").textContent = state.autoRefresh ? "On" : "Off";
    restartAutoRefresh();
  });
  $("refreshInterval").addEventListener("change", (event) => {
    state.refreshIntervalSecs = Number(event.target.value || 15);
    restartAutoRefresh();
  });
  bindServiceGridActions();

  try {
    await refreshServicesCatalog();
    await loadOverview();
    restartAutoRefresh();
  } catch (error) {
    $("servicesGrid").innerHTML = `<div class="reason-chip">Panel yuklenemedi: ${error.message}</div>`;
    $("historyFeed").innerHTML = `<div class="reason-chip">API error: ${error.message}</div>`;
    setRefreshState(`API error: ${error.message}`);
  }
}

boot();
