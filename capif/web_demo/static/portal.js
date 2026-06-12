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

  card.innerHTML = html;
  out.appendChild(card);
  card.scrollIntoView({ behavior: "smooth", block: "center" });
  return result;
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
