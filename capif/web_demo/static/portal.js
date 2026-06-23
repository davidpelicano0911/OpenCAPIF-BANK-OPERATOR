// Shared logic for both portals.

async function runAction(endpoint, body) {
  const opts = { method: "POST" };
  if (body) {
    opts.headers = { "Content-Type": "application/json" };
    opts.body = JSON.stringify(body);
  }
  const r = await fetch(endpoint, opts);
  return r.json();
}

function badge(http, ok) {
  if (http == null) return `<span class="badge bad">ERR</span>`;
  return `<span class="badge ${ok ? "ok" : "bad"}">${http}</span>`;
}

function render(result) {
  const out = document.getElementById("out");
  const card = document.createElement("div");
  card.className = "card " + (result.ok ? "" : "fail");

  let html = `<h3>${result.title}</h3>`;
  if (result.summary) html += `<p class="summary">${result.summary}</p>`;

  const d = result.data || {};
  if (d.decision) {
    const approve = d.decision === "APPROVE";
    html += `<div class="decision ${approve ? "approve" : "block"}">
               <div class="phone">${d.phone || ""}</div>
               <div class="big">${approve ? "TRANSACTION APPROVED" : "TRANSACTION BLOCKED"}</div>
             </div>`;
  }
  if (d.apis) {
    html += d.apis.map(a => `<div class="api-found">
        <b>${a.name}</b><div class="muted">${a.description}</div>
        <div class="muted">${a.endpoint || ""}</div></div>`).join("");
  }
  if (d.logs) {
    html += d.logs.length
      ? d.logs.map(l => `<div class="api-found">
          <b>${l.operation || ""} ${l.apiName || ""}</b>
          <div class="muted">${l.uri || ""} &middot; HTTP ${l.result || ""}</div>
          <div class="muted">${l.invocationTime || ""}</div></div>`).join("")
      : `<div class="muted">No invocations logged yet.</div>`;
  }
  if (d.certificates) {
    html += `<div class="chips">` +
      d.certificates.map(c => `<span class="chip">${c} certificate</span>`).join("") + `</div>`;
  }
  if (d.api_id) html += `<div class="muted">API ID: ${d.api_id} &middot; ${d.endpoint || ""}</div>`;
  if (d.token) html += `<div class="muted">token: ${d.token}</div>`;

  if (result.calls && result.calls.length) {
    html += `<div class="calls">` + result.calls.map(c =>
      `<div class="call">${badge(c.http, c.ok)} <span>${c.label}</span>
       <span class="muted">${c.detail || ""}</span></div>`).join("") + `</div>`;
  }
  if (result.mongo) html += `<div class="mongo">Stored in CAPIF &rarr; ${result.mongo}</div>`;

  // Real data returned by the server, collapsible for the curious.
  if (result.data && Object.keys(result.data).length) {
    html += `<details class="raw"><summary>Show raw data (JSON)</summary>
      <pre>${escapeHtml(JSON.stringify(result.data, null, 2))}</pre></details>`;
  }

  card.innerHTML = html;
  out.appendChild(card);
  card.scrollIntoView({ behavior: "smooth", block: "center" });
  refreshState();
  return result;
}

function escapeHtml(s) {
  return String(s).replace(/[&<>]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" }[c]));
}

// Shared-state bar: shows what BOTH actors have done through the single CapifFlow
// on the server. Refreshed after each action and via a light poll, so e.g. the
// Bank tab reflects the API the Operator just published.
async function refreshState() {
  const bar = document.getElementById("state-bar");
  if (!bar) return;
  let s;
  try { s = await (await fetch("/api/state")).json(); }
  catch (e) { return; }
  const item = (on, label) =>
    `<span class="state-item ${on ? "on" : "off"}">${on ? "●" : "○"} ${label}</span>`;
  bar.innerHTML =
    item(s.operator_registered, "Operator registered") +
    item(s.api_published, "API published") +
    item(s.invoker_registered, "Bank registered") +
    item(s.has_token, "Token issued");

  // Sync buttons with the SERVER state so a browser reload does NOT force redoing
  // earlier steps — the work lives in the shared CapifFlow, not in the page.
  if (s.operator_registered) enable("b-publish");   // Operator portal
  if (s.api_published) enable("b-audit");
  if (s.invoker_registered) enable("b-discover");    // Bank portal
  if (s.discovered) enable("b-token");
  if (s.has_token) {
    enable("b-check"); enable("phone");
    const hint = document.getElementById("check-hint");
    if (hint) hint.textContent =
      "Unlocked. Try +351912345678 (safe) or +351911111111 (SIM swapped).";
  }
}

// Wire a button to an endpoint. onOk runs only if the action succeeded.
function wire(btnId, endpoint, body, onOk) {
  const btn = document.getElementById(btnId);
  if (!btn) return;
  btn.addEventListener("click", async () => {
    btn.disabled = true;
    const label = btn.textContent;
    btn.textContent = "Working...";
    let res;
    try { res = render(await runAction(endpoint, body)); }
    catch (e) { res = render({ ok: false, title: "Error", summary: "Connection to server failed." }); }
    btn.textContent = label;
    btn.disabled = false;
    if (res && res.ok && onOk) onOk();
  });
}

function enable(id) { const el = document.getElementById(id); if (el) el.disabled = false; }

async function resetAll() {
  await runAction("/api/reset");
  location.reload();
}

// Keep the shared-state bar fresh so each tab reflects the other actor's progress.
if (document.getElementById("state-bar")) {
  refreshState();
  setInterval(refreshState, 4000);
}
