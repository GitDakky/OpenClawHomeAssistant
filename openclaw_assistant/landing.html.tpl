<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OpenClaw Super Home Assistant</title>
  <style>
    :root{
      --bg:#04070d;
      --bg-accent:#091322;
      --panel:#0b1220cc;
      --panel-strong:#0f1728;
      --panel-soft:#111b2f;
      --line:#20314b;
      --line-strong:#32527a;
      --text:#eef4ff;
      --muted:#97a8c4;
      --accent:#57a6ff;
      --accent-strong:#2b7cff;
      --accent-soft:#7ce7d2;
      --warn:#ffb24a;
      --danger:#ff6d6d;
      --success:#51d9a6;
      --code:#08111d;
      --shadow:0 24px 80px rgba(0,0,0,.42);
      --radius:24px;
    }
    *{box-sizing:border-box}
    html,body{margin:0;min-height:100%}
    body{
      font-family:"Space Grotesk","Avenir Next","Segoe UI",sans-serif;
      color:var(--text);
      background:
        radial-gradient(circle at top left, rgba(42,96,255,.22), transparent 34%),
        radial-gradient(circle at top right, rgba(66,214,177,.12), transparent 28%),
        linear-gradient(180deg, #07101c 0%, #04070d 55%, #020409 100%);
      padding:28px 18px 36px;
    }
    a,button{font:inherit}
    code,pre{
      font-family:"SFMono-Regular","JetBrains Mono","Cascadia Code",monospace;
    }
    .shell{
      max-width:1280px;
      margin:0 auto;
      display:grid;
      gap:22px;
    }
    .hero{
      display:grid;
      grid-template-columns:minmax(0,1.28fr) minmax(320px,.92fr);
      gap:20px;
      align-items:stretch;
    }
    .panel{
      position:relative;
      overflow:hidden;
      border-radius:var(--radius);
      border:1px solid rgba(110,145,190,.18);
      background:linear-gradient(180deg, rgba(12,19,33,.96), rgba(8,14,24,.96));
      box-shadow:var(--shadow);
      backdrop-filter:blur(14px);
    }
    .panel::before{
      content:"";
      position:absolute;
      inset:0;
      pointer-events:none;
      background:linear-gradient(140deg, rgba(87,166,255,.08), transparent 35%, rgba(124,231,210,.06));
    }
    .hero-main{
      padding:30px 30px 28px;
      display:grid;
      gap:22px;
      min-height:360px;
    }
    .eyebrow{
      display:inline-flex;
      align-items:center;
      gap:10px;
      color:var(--accent-soft);
      font-size:13px;
      font-weight:700;
      text-transform:uppercase;
      letter-spacing:.16em;
    }
    .eyebrow::before{
      content:"";
      width:34px;
      height:2px;
      border-radius:999px;
      background:linear-gradient(90deg, var(--accent), var(--accent-soft));
      box-shadow:0 0 18px rgba(87,166,255,.5);
    }
    h1{
      margin:0;
      font-size:clamp(38px, 5vw, 64px);
      line-height:.96;
      letter-spacing:-.05em;
      max-width:10ch;
    }
    .lede{
      margin:0;
      max-width:58ch;
      color:#cad7ea;
      font-size:17px;
      line-height:1.65;
    }
    .hero-copy{
      display:grid;
      gap:14px;
    }
    .chip-row,
    .action-row{
      display:flex;
      gap:12px;
      flex-wrap:wrap;
      align-items:center;
    }
    .chip{
      display:inline-flex;
      align-items:center;
      gap:10px;
      min-height:42px;
      padding:10px 14px;
      border-radius:999px;
      background:rgba(9,18,32,.88);
      border:1px solid rgba(103,137,179,.22);
      color:var(--muted);
      font-size:13px;
    }
    .chip code{
      color:var(--text);
      background:transparent;
      padding:0;
      font-size:13px;
    }
    .hero-note{
      display:grid;
      gap:10px;
      max-width:64ch;
      padding:18px 20px;
      border-radius:20px;
      background:linear-gradient(180deg, rgba(11,22,38,.84), rgba(8,16,29,.78));
      border:1px solid rgba(87,166,255,.16);
    }
    .hero-note b{
      color:var(--text);
      font-size:15px;
    }
    .hero-note p{
      margin:0;
      color:var(--muted);
      line-height:1.65;
      font-size:14px;
    }
    .hero-side{
      padding:24px;
      display:grid;
      gap:14px;
      align-content:start;
    }
    .mini-card{
      position:relative;
      border-radius:20px;
      padding:18px 18px 16px;
      background:linear-gradient(180deg, rgba(14,24,40,.94), rgba(8,15,26,.9));
      border:1px solid rgba(108,145,191,.18);
    }
    .mini-card h2{
      margin:0 0 6px;
      font-size:15px;
      letter-spacing:.08em;
      text-transform:uppercase;
      color:#d3deee;
    }
    .mini-card p{
      margin:0;
      color:var(--muted);
      font-size:14px;
      line-height:1.6;
    }
    .status-grid{
      display:grid;
      gap:12px;
    }
    .status-item{
      display:grid;
      grid-template-columns:28px 1fr;
      gap:12px;
      align-items:start;
      padding:16px 16px 15px;
      border-radius:18px;
      background:linear-gradient(180deg, rgba(12,19,33,.92), rgba(8,14,24,.88));
      border:1px solid rgba(88,114,146,.18);
      min-height:82px;
      font-size:14px;
      line-height:1.55;
    }
    .status-item .icon{
      display:grid;
      place-items:center;
      width:28px;
      height:28px;
      border-radius:10px;
      background:rgba(87,166,255,.12);
      font-size:15px;
    }
    .status-item b{color:var(--text)}
    .status-label{
      font-size:12px;
      text-transform:uppercase;
      letter-spacing:.12em;
      color:var(--muted);
      margin-bottom:6px;
      display:block;
    }
    .action-row .btn{
      display:inline-flex;
      align-items:center;
      justify-content:center;
      gap:10px;
      min-height:48px;
      padding:0 18px;
      border:0;
      border-radius:16px;
      text-decoration:none;
      cursor:pointer;
      transition:transform .18s ease, filter .18s ease, box-shadow .18s ease;
    }
    .btn:hover{transform:translateY(-1px);filter:brightness(1.07)}
    .btn.primary{
      color:#07111f;
      font-weight:700;
      background:linear-gradient(135deg, #64b3ff, #7ce7d2);
      box-shadow:0 12px 28px rgba(87,166,255,.22);
    }
    .btn.secondary{
      color:var(--text);
      background:rgba(17,27,47,.92);
      border:1px solid rgba(88,114,146,.22);
    }
    .btn.ghost{
      color:#d9f0ff;
      background:rgba(18,35,57,.72);
      border:1px solid rgba(124,231,210,.18);
    }
    .banner-stack{
      display:grid;
      gap:14px;
    }
    .banner{
      padding:16px 18px;
      border-radius:18px;
      border:1px solid transparent;
      font-size:14px;
      line-height:1.65;
    }
    .banner.info{
      background:linear-gradient(180deg, rgba(18,35,57,.86), rgba(10,20,34,.82));
      border-color:rgba(87,166,255,.26);
      color:#d8e7ff;
    }
    .banner.warn{
      background:linear-gradient(180deg, rgba(57,34,12,.82), rgba(34,20,7,.78));
      border-color:rgba(255,178,74,.34);
      color:#ffe2b7;
    }
    .banner.error{
      background:linear-gradient(180deg, rgba(59,16,20,.82), rgba(34,10,12,.78));
      border-color:rgba(255,109,109,.34);
      color:#ffd0d0;
    }
    .banner.success{
      background:linear-gradient(180deg, rgba(9,44,33,.82), rgba(5,25,19,.78));
      border-color:rgba(81,217,166,.3);
      color:#d8fff0;
    }
    .wizard{
      padding:20px 22px;
      border-radius:22px;
      border:1px solid rgba(110,145,190,.18);
      background:linear-gradient(180deg, rgba(12,19,33,.96), rgba(9,15,25,.94));
      box-shadow:var(--shadow);
    }
    .wizard h3{
      margin:0 0 10px;
      font-size:18px;
      letter-spacing:-.02em;
    }
    .wizard p,
    .wizard li{
      color:var(--muted);
      line-height:1.75;
      font-size:14px;
    }
    .wizard ol,
    .wizard ul{
      margin:8px 0 0;
      padding-left:22px;
    }
    .guides{
      display:grid;
      grid-template-columns:repeat(2, minmax(0, 1fr));
      gap:18px;
    }
    .ops-grid{
      display:grid;
      grid-template-columns:minmax(0, 1.35fr) minmax(320px, .95fr);
      gap:18px;
      align-items:start;
    }
    .ops-panel{
      padding:22px;
      display:grid;
      gap:16px;
    }
    .ops-panel.wide{
      grid-row:span 2;
    }
    .ops-head{
      display:grid;
      gap:6px;
    }
    .ops-head h3,
    .stack-card h4,
    .file-group h4{
      margin:0;
      font-size:20px;
      letter-spacing:-.03em;
    }
    .ops-head p,
    .stack-card p,
    .file-group p{
      margin:0;
      color:var(--muted);
      font-size:14px;
      line-height:1.65;
    }
    .editor-layout{
      display:grid;
      grid-template-columns:minmax(220px, .8fr) minmax(0, 1.4fr);
      gap:16px;
      align-items:start;
    }
    .file-groups{
      display:grid;
      gap:16px;
    }
    .file-group{
      display:grid;
      gap:10px;
    }
    .file-list{
      display:grid;
      gap:8px;
      max-height:280px;
      overflow:auto;
      padding-right:4px;
    }
    .file-btn{
      text-align:left;
      width:100%;
      border:1px solid rgba(88,114,146,.18);
      background:rgba(9,17,30,.78);
      color:var(--text);
      border-radius:14px;
      padding:12px 14px;
      cursor:pointer;
      transition:border-color .18s ease, transform .18s ease, background .18s ease;
    }
    .file-btn:hover{
      transform:translateY(-1px);
      border-color:rgba(124,231,210,.34);
    }
    .file-btn.active{
      border-color:rgba(87,166,255,.4);
      background:rgba(14,27,46,.92);
      box-shadow:0 0 0 1px rgba(87,166,255,.16) inset;
    }
    .file-btn .small{
      display:block;
      margin-top:4px;
      color:var(--muted);
      font-size:12px;
      line-height:1.5;
    }
    .editor-shell{
      display:grid;
      gap:12px;
      min-width:0;
    }
    .editor-toolbar{
      display:flex;
      gap:12px;
      justify-content:space-between;
      align-items:flex-start;
      flex-wrap:wrap;
    }
    .editor-toolbar strong{
      display:block;
      font-size:16px;
    }
    .editor{
      width:100%;
      min-height:420px;
      resize:vertical;
      border-radius:18px;
      border:1px solid rgba(88,114,146,.22);
      background:var(--code);
      color:#e4efff;
      padding:16px;
      font-family:"SFMono-Regular","JetBrains Mono","Cascadia Code",monospace;
      font-size:13px;
      line-height:1.65;
      outline:none;
    }
    .stack{
      display:grid;
      gap:12px;
    }
    .stack-card{
      padding:16px;
      border-radius:18px;
      background:rgba(9,17,30,.76);
      border:1px solid rgba(88,114,146,.18);
      display:grid;
      gap:10px;
    }
    .stack-card pre{
      margin:0;
      max-height:220px;
    }
    .pill-row{
      display:flex;
      gap:10px;
      flex-wrap:wrap;
    }
    .pill{
      display:inline-flex;
      align-items:center;
      min-height:34px;
      padding:0 12px;
      border-radius:999px;
      background:rgba(14,27,46,.92);
      border:1px solid rgba(88,114,146,.18);
      color:#deebff;
      font-size:12px;
      letter-spacing:.04em;
      text-transform:uppercase;
    }
    .pill.good{
      border-color:rgba(81,217,166,.3);
      color:#bfffe5;
    }
    .pill.warn{
      border-color:rgba(255,178,74,.34);
      color:#ffe2b7;
    }
    .pill.off{
      border-color:rgba(255,109,109,.26);
      color:#ffd0d0;
    }
    .integration-grid{
      display:grid;
      gap:12px;
    }
    .integration-card{
      border-radius:18px;
      padding:16px;
      background:rgba(9,17,30,.76);
      border:1px solid rgba(88,114,146,.18);
      display:grid;
      gap:8px;
    }
    .integration-card b{
      font-size:15px;
    }
    .integration-card .meta{
      color:var(--muted);
      font-size:13px;
      line-height:1.6;
      word-break:break-word;
    }
    .guide-card{
      padding:18px 18px 10px;
    }
    details{
      border-radius:18px;
      background:rgba(9,17,30,.72);
      border:1px solid rgba(88,114,146,.18);
      overflow:hidden;
    }
    details > summary{
      cursor:pointer;
      padding:16px 18px;
      font-size:15px;
      font-weight:700;
      color:#dfe9f8;
      list-style:none;
    }
    details > summary::-webkit-details-marker{display:none}
    details > div{
      padding:0 18px 18px;
      color:var(--muted);
      font-size:14px;
      line-height:1.7;
    }
    pre{
      margin:10px 0 0;
      overflow:auto;
      border-radius:16px;
      padding:14px;
      background:var(--code);
      border:1px solid rgba(88,114,146,.18);
      color:#d8e8ff;
      font-size:12px;
      line-height:1.6;
    }
    code{
      background:rgba(7,17,31,.9);
      padding:2px 6px;
      border-radius:8px;
      color:#d8e8ff;
      font-size:12px;
    }
    .terminal-shell{
      padding:22px;
      display:grid;
      gap:16px;
    }
    .terminal-head{
      display:flex;
      gap:14px;
      justify-content:space-between;
      align-items:flex-end;
      flex-wrap:wrap;
    }
    .terminal-head h3{
      margin:4px 0 0;
      font-size:28px;
      letter-spacing:-.04em;
    }
    .terminal-head p{
      margin:0;
      color:var(--muted);
      font-size:14px;
      max-width:64ch;
      line-height:1.65;
    }
    .term{
      height:64vh;
      min-height:420px;
      border-radius:20px;
      border:1px solid rgba(84,121,166,.24);
      overflow:hidden;
      background:#020409;
      box-shadow:inset 0 1px 0 rgba(255,255,255,.04);
    }
    iframe{
      width:100%;
      height:100%;
      border:0;
      background:#020409;
    }
    .hidden{display:none}
    .badge{
      display:inline-flex;
      align-items:center;
      justify-content:center;
      min-height:32px;
      padding:0 12px;
      border-radius:999px;
      font-size:12px;
      font-weight:700;
      text-transform:uppercase;
      letter-spacing:.12em;
    }
    .badge.secure{background:rgba(81,217,166,.16);color:#b4ffd9;border:1px solid rgba(81,217,166,.28)}
    .badge.insecure{background:rgba(255,109,109,.14);color:#ffc8c8;border:1px solid rgba(255,109,109,.26)}
    .badge.mode{background:rgba(87,166,255,.16);color:#dbeaff;border:1px solid rgba(87,166,255,.28)}
    .subtle{
      color:var(--muted);
      font-size:13px;
      line-height:1.6;
    }
    @media (max-width: 1040px){
      .hero{grid-template-columns:1fr}
      .guides{grid-template-columns:1fr}
      .ops-grid{grid-template-columns:1fr}
      .ops-panel.wide{grid-row:auto}
      .editor-layout{grid-template-columns:1fr}
    }
    @media (max-width: 720px){
      body{padding:18px 12px 24px}
      .hero-main,.hero-side,.terminal-shell{padding:18px}
      .status-item{min-height:unset}
      h1{max-width:none}
      .terminal-head h3{font-size:24px}
      .term{height:56vh;min-height:340px}
    }
  </style>
</head>
<body>
  <div class="shell">
    <section class="hero">
      <div class="panel hero-main">
        <div class="hero-copy">
          <div class="eyebrow">GitDakky Fork Operator Console</div>
          <h1>OpenClaw Super Home Assistant</h1>
          <p class="lede">
            Modernized Home Assistant runtime for OpenClaw with a darker operator-first shell,
            cleaner migration handling, and a clearer separation from the legacy add-on line.
          </p>
        </div>

        <div class="chip-row">
          <div class="chip">Bundled OpenClaw <code>__OPENCLAW_BUNDLED_VERSION__</code></div>
          <div class="chip">Gateway mode <code>__ACCESS_MODE__</code></div>
          <span class="badge mode" id="modeBadge">__ACCESS_MODE__</span>
          <span class="badge" id="secureBadge"></span>
        </div>

        <div class="action-row">
          <a class="btn primary" id="gwbtn" href="__GATEWAY_PUBLIC_URL____GW_PUBLIC_URL_PATH__?token=__GATEWAY_TOKEN__" target="_blank" rel="noopener noreferrer">Open Gateway Web UI</a>
          <a class="btn secondary" href="./terminal/" target="_self">Open Terminal (full page)</a>
          <a class="btn ghost hidden" id="certBtn" href="" target="_blank" rel="noopener noreferrer">Download CA Certificate</a>
        </div>

        <div class="hero-note">
          <b>Fork identity and migration</b>
          <p>
            This install is intentionally separate from the legacy OpenClaw Assistant add-on.
            On a first start, the fork tries to stop the old add-on, import its add-on config,
            and continue from the migrated state without reusing the old identity.
          </p>
          <p>
            Clean installs also default to separate ports so the fork does not collide with the abandoned line before migration runs.
          </p>
        </div>
      </div>

      <aside class="panel hero-side">
        <div class="mini-card">
          <h2>Runtime Snapshot</h2>
          <p>
            Live status, secure-context state, access mode, and disk pressure are surfaced here first so
            operators can see the next action without digging through logs.
          </p>
        </div>

        <div class="status-grid">
          <div class="status-item" id="statusGateway">
            <span class="icon">GW</span>
            <span><span class="status-label">Gateway</span>Checking runtime health...</span>
          </div>
          <div class="status-item" id="statusSecure">
            <span class="icon">TLS</span>
            <span><span class="status-label">Secure Context</span>Checking browser security requirements...</span>
          </div>
          <div class="status-item" id="statusAccess">
            <span class="icon">CFG</span>
            <span><span class="status-label">Access Mode</span><b>__ACCESS_MODE__</b></span>
          </div>
          <div class="status-item" id="statusDisk">
            <span class="icon" id="diskIcon">DSK</span>
            <span id="diskText"><span class="status-label">Disk</span>__DISK_USED__ / __DISK_TOTAL__ (__DISK_PCT__) - __DISK_AVAIL__ free</span>
          </div>
        </div>
      </aside>
    </section>

    <div class="banner-stack">
      <div class="banner warn hidden" id="migrationBanner">
        <b>Migration note:</b> OpenClaw requires HTTPS or localhost for the Control UI.
        Plain HTTP LAN access will be rejected. Switch <code>access_mode</code> to <b>lan_https</b>
        for the cleanest built-in secure path.
      </div>
      <div class="banner warn hidden" id="diskBanner">
        <b>Low disk space:</b> <span id="diskBannerText"></span><br>
        Open the terminal and run <code>oc-cleanup</code>. For Docker-level cleanup, use a host root shell and run
        <code>docker image prune -a</code>.
      </div>
      <div class="banner error hidden" id="errorBanner"></div>
      <div class="banner success hidden" id="successBanner"></div>
    </div>

    <section class="wizard hidden" id="wizard">
      <h3>Recommended next step</h3>
      <div id="wizardContent"></div>
    </section>

    <section class="guides">
      <div class="panel guide-card">
        <details>
          <summary>Token and access quick help</summary>
          <div>
            <p>
              The Gateway UI opens in a separate tab to avoid Home Assistant ingress websocket quirks.
              In most local installs the launch URL is derived automatically. Set <code>gateway_public_url</code> only when you need to override the detected host or point at a reverse-proxy / Tailscale URL.
            </p>
            <p>
              If the Gateway UI says <b>Unauthorized</b>, retrieve the token in the embedded terminal:
            </p>
            <pre>jq -r '.gateway.auth.token' /config/.openclaw/openclaw.json</pre>
            <p class="subtle">
              Since OpenClaw v2026.2.22+, <code>openclaw config get</code> redacts secrets, so read the file directly.
            </p>
          </div>
        </details>
      </div>

      <div class="panel guide-card">
        <details>
          <summary>MCP setup (Home Assistant control)</summary>
          <div>
            <p><b>MCP</b> lets OpenClaw control Home Assistant entities, services, and automations directly.</p>
            <p><b>Automatic:</b> create a long-lived access token in Home Assistant, paste it into <code>homeassistant_token</code>, enable <code>auto_configure_mcp</code>, and restart the app.</p>
            <p><b>Manual:</b></p>
            <pre>mcporter config add HA "http://localhost:8123/api/mcp" \
  --header "Authorization=Bearer YOUR_LONG_LIVED_TOKEN" \
  --scope home</pre>
            <p><b>After upgrades:</b></p>
            <pre>mcporter call home-assistant.GetLiveContext</pre>
          </div>
        </details>
      </div>

      <div class="panel guide-card">
        <details>
          <summary>Reverse-proxy recipes (NPM / Caddy / Traefik / Tailscale)</summary>
          <div>
            <p><b>Nginx Proxy Manager</b></p>
            <pre>Scheme:   https
Forward:  &lt;HA-IP&gt;:18790
WS:       ON
SSL tab:  Request a new SSL certificate</pre>
            <p><b>Caddy</b></p>
            <pre>openclaw.example.com {
    reverse_proxy &lt;HA-IP&gt;:18790
}</pre>
            <p><b>Traefik</b></p>
            <pre>- "traefik.http.routers.openclaw.rule=Host(`openclaw.example.com`)"
- "traefik.http.routers.openclaw.tls.certresolver=le"
- "traefik.http.services.openclaw.loadbalancer.server.port=18790"</pre>
            <p><b>Tailscale HTTPS</b></p>
            <pre># 1. Set access_mode to tailnet_https
# 2. Enable Tailscale HTTPS certificates
# 3. tailscale cert &lt;machine-name&gt;.ts.net
# 4. Set gateway_public_url to https://&lt;machine-name&gt;.ts.net:18790</pre>
          </div>
        </details>
      </div>

      <div class="panel guide-card">
        <details>
          <summary>Operator notes</summary>
          <div>
            <p>
              If you migrated from the older add-on line, the fork now reconciles legacy single-agent state into the current per-agent
              OpenClaw layout so sessions, auth, and model state continue to work under <code>agents/main</code>.
            </p>
            <p>
              Same-host CLI and TUI pairing requests are auto-approved on loopback-style installs to reduce local operator friction without opening remote pairing.
            </p>
            <p>
              For a full recovery pass, run <code>openclaw doctor --non-interactive</code> from the embedded terminal.
            </p>
          </div>
        </details>
      </div>
    </section>

    <section class="ops-grid">
      <section class="panel ops-panel wide">
        <div class="ops-head">
          <div class="eyebrow">Workspace and Skills</div>
          <h3>Editable operator bootstrap</h3>
          <p>
            The add-on seeds a managed OpenClaw workspace and a Home Assistant skill pack on first boot.
            Edit the key files here if you want to tune the assistant manually without leaving the dashboard.
          </p>
        </div>
        <div class="editor-layout">
          <div class="file-groups">
            <div class="file-group">
              <h4>Workspace files</h4>
              <p>Always-on identity, bootstrap, memory, and tool-use rules.</p>
              <div class="file-list" id="workspaceList"></div>
            </div>
            <div class="file-group">
              <h4>Bundled skills</h4>
              <p>Home Assistant, diagnostics, research, Domotz, BACnet, and MQTT guidance.</p>
              <div class="file-list" id="skillList"></div>
            </div>
          </div>
          <div class="editor-shell">
            <div class="editor-toolbar">
              <div>
                <strong id="editorTitle">Choose a file to inspect</strong>
                <div class="subtle" id="editorPath">Files are loaded from persistent storage under /config.</div>
              </div>
              <div class="action-row">
                <button class="btn secondary" id="reloadFileBtn" type="button">Reload</button>
                <button class="btn primary" id="saveFileBtn" type="button">Save file</button>
              </div>
            </div>
            <textarea class="editor" id="fileEditor" spellcheck="false" placeholder="Select a workspace file or skill file to edit."></textarea>
          </div>
        </div>
      </section>

      <section class="panel ops-panel">
        <div class="ops-head">
          <div class="eyebrow">Automation Runtime</div>
          <h3>Cron and heartbeat visibility</h3>
          <p>
            This section reflects live OpenClaw scheduler state so you can see what jobs exist,
            whether the cron scheduler is healthy, and what the latest heartbeat recorded.
          </p>
        </div>
        <div class="stack">
          <div class="stack-card">
            <h4>Scheduler summary</h4>
            <div class="pill-row" id="scheduleSummary">
              <span class="pill">Loading</span>
            </div>
          </div>
          <div class="stack-card">
            <h4>Cron jobs</h4>
            <pre id="cronJobsBlock">Loading live cron state...</pre>
          </div>
          <div class="stack-card">
            <h4>Recent cron runs</h4>
            <pre id="cronRunsBlock">Loading recent run history...</pre>
          </div>
          <div class="stack-card">
            <h4>Last heartbeat</h4>
            <pre id="heartbeatBlock">Loading last heartbeat...</pre>
          </div>
        </div>
      </section>

      <section class="panel ops-panel">
        <div class="ops-head">
          <div class="eyebrow">Integration Rack</div>
          <h3>Research, broker, and network sources</h3>
          <p>
            Context7, Domotz, MQTT, BACnet, and the lightweight system graph all surface here so the operator
            can see what live intelligence is actually wired in before asking the agent to use it.
          </p>
        </div>
        <div class="integration-grid" id="integrationGrid">
          <div class="integration-card">
            <b>Loading integration state...</b>
            <div class="meta">The dashboard API is gathering runtime metadata.</div>
          </div>
        </div>
      </section>
    </section>

    <section class="panel terminal-shell">
      <div class="terminal-head">
        <div>
          <div class="eyebrow">Embedded Terminal</div>
          <h3>Direct operator console</h3>
        </div>
        <p>
          Keep onboarding, doctor runs, token inspection, and migration recovery inside the add-on.
          The terminal remains first-class here; the page around it just stops looking like a default admin stub.
        </p>
      </div>
      <div class="term">
        <iframe src="./terminal/" title="Terminal"></iframe>
      </div>
    </section>
  </div>

  <script>
  (function() {
    const ACCESS_MODE = '__ACCESS_MODE__';
    const GATEWAY_MODE = '__GATEWAY_MODE__';
    const GATEWAY_BIND_MODE = '__GATEWAY_BIND_MODE__';
    const GATEWAY_PORT = '__GATEWAY_PORT__';
    const HTTPS_PORT = '__HTTPS_PORT__';
    const GW_PUBLIC_URL = '__GATEWAY_PUBLIC_URL__';
    const GW_TOKEN = '__GATEWAY_TOKEN__';
    const DISK_PCT = '__DISK_PCT__';
    const DISK_AVAIL = '__DISK_AVAIL__';
    const DISK_USED = '__DISK_USED__';
    const DISK_TOTAL = '__DISK_TOTAL__';
    const DASHBOARD_API_BASE = './super/api';

    const $ = id => document.getElementById(id);
    const escapeHtml = value => String(value ?? '').replace(/[&<>"]/g, ch => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[ch]));
    const prettyJson = value => {
      if (value === null || value === undefined || value === '') return 'No data.';
      if (typeof value === 'string') return value;
      try { return JSON.stringify(value, null, 2); } catch { return String(value); }
    };
    const browserHost = window.location.hostname || '';
    const browserProtocol = window.location.protocol || 'http:';
    function resolveGatewayBaseUrl() {
      if (GW_PUBLIC_URL) {
        return GW_PUBLIC_URL.replace(/\/$/, '');
      }
      if (GATEWAY_MODE !== 'local') {
        return '';
      }
      if (ACCESS_MODE === 'lan_https' && HTTPS_PORT && browserHost) {
        return `https://${browserHost}:${HTTPS_PORT}`;
      }
      if (ACCESS_MODE === 'local_only') {
        if (browserHost === 'localhost' || browserHost === '127.0.0.1') {
          return `http://127.0.0.1:${GATEWAY_PORT}`;
        }
        return '';
      }
      if (ACCESS_MODE === 'custom' && GATEWAY_BIND_MODE === 'lan' && browserHost && GATEWAY_PORT) {
        return `http://${browserHost}:${GATEWAY_PORT}`;
      }
      if (ACCESS_MODE === 'custom' && GATEWAY_BIND_MODE === 'loopback' && (browserHost === 'localhost' || browserHost === '127.0.0.1')) {
        return `http://127.0.0.1:${GATEWAY_PORT}`;
      }
      if (ACCESS_MODE === 'lan_reverse_proxy' && browserProtocol === 'https:' && browserHost) {
        return `https://${browserHost}`;
      }
      return '';
    }
    const RESOLVED_GATEWAY_BASE_URL = resolveGatewayBaseUrl();
    let activeFileKey = '';

    const isSecure = window.isSecureContext;
    const secureBadge = $('secureBadge');
    const statusSecure = $('statusSecure');
    if (isSecure) {
      secureBadge.textContent = 'Secure';
      secureBadge.className = 'badge secure';
      statusSecure.innerHTML = '<span class="icon">TLS</span><span><span class="status-label">Secure Context</span>Browser context is <b>ready</b> for device identity and Control UI auth.</span>';
    } else {
      secureBadge.textContent = 'Not Secure';
      secureBadge.className = 'badge insecure';
      statusSecure.innerHTML = '<span class="icon">TLS</span><span><span class="status-label">Secure Context</span>Browser context is <b>not secure</b>. Control UI requires HTTPS or localhost.</span>';
    }

    (async function checkGateway() {
      const statusEl = $('statusGateway');
      try {
        const url = RESOLVED_GATEWAY_BASE_URL
          ? RESOLVED_GATEWAY_BASE_URL + '/api/health' + (GW_TOKEN ? ('?token=' + encodeURIComponent(GW_TOKEN)) : '')
          : '/api/health';
        const r = await fetch(url, { mode: 'no-cors', cache: 'no-store' }).catch(() => null);
        if (r && (r.ok || r.type === 'opaque')) {
          statusEl.innerHTML = '<span class="icon">GW</span><span><span class="status-label">Gateway</span>Gateway runtime looks <b>reachable</b>.</span>';
        } else {
          statusEl.innerHTML = '<span class="icon">GW</span><span><span class="status-label">Gateway</span>Gateway is <b>still starting</b> or not yet reachable from this page.</span>';
        }
      } catch {
        statusEl.innerHTML = '<span class="icon">GW</span><span><span class="status-label">Gateway</span>Gateway is <b>unreachable</b> from this page right now.</span>';
      }
    })();

    const ERROR_MAP = {
      'control ui requires device identity': {
        friendly: 'The Gateway UI requires HTTPS or localhost (secure context). Plain HTTP over LAN is blocked since OpenClaw v2026.2.21.',
        fix: ACCESS_MODE === 'lan_https'
          ? 'Your app is configured for lan_https. Open the gateway via the HTTPS URL above and install the CA certificate on your device.'
          : 'Switch <code>access_mode</code> to <b>lan_https</b> in app Configuration, then restart. This enables a built-in HTTPS proxy for LAN access.'
      },
      'requires secure context': {
        friendly: 'The browser is not in a secure context. HTTPS or localhost is required.',
        fix: 'Use the HTTPS URL provided by the app, or place the gateway behind a reverse proxy with TLS.'
      },
      'pairing required': {
        friendly: 'The Gateway requires device pairing before the Control UI can connect.',
        fix: ACCESS_MODE === 'lan_https'
          ? 'Restart the app — by default it sets <code>controlUi.dangerouslyDisableDeviceAuth: true</code> in lan_https mode to reduce LAN pairing friction while keeping token auth enabled.'
          : 'Use <b>lan_https</b> for the simplest path, or approve pending devices manually from the embedded terminal.'
      },
      'origin not allowed': {
        friendly: 'The Gateway rejected the browser origin. The Control UI URL is not in the allow-list.',
        fix: ACCESS_MODE === 'lan_https'
          ? 'Restart the app so it can refresh HTTPS origins and certificates for the current LAN IP.'
          : 'Manually add your origin: <code>openclaw config set gateway.controlUi.allowedOrigins \'["https://YOUR_IP:18790"]\'</code>'
      },
      '1008': {
        friendly: 'The websocket closed with code 1008.',
        fix: 'Check whether the problem is secure context, origin policy, or pairing approval in the app logs.'
      }
    };

    window.translateError = function(rawError) {
      const lower = (rawError || '').toLowerCase();
      for (const [pattern, info] of Object.entries(ERROR_MAP)) {
        if (lower.includes(pattern)) {
          return info;
        }
      }
      return null;
    };

    if (ACCESS_MODE === 'custom') {
      $('migrationBanner').classList.remove('hidden');
    }

    if (DISK_PCT) {
      const pctNum = parseInt(DISK_PCT, 10);
      const diskIcon = $('diskIcon');
      const statusDisk = $('statusDisk');
      if (pctNum >= 90) {
        diskIcon.textContent = 'WRN';
        statusDisk.style.borderColor = 'rgba(255,109,109,.4)';
        $('diskBanner').classList.remove('hidden');
        $('diskBannerText').textContent =
          `Disk is ${DISK_PCT} full (${DISK_AVAIL} free of ${DISK_TOTAL}).`;
      } else if (pctNum >= 75) {
        diskIcon.textContent = 'OBS';
        statusDisk.style.borderColor = 'rgba(255,178,74,.42)';
        $('diskBanner').classList.remove('hidden');
        $('diskBannerText').textContent =
          `Disk is ${DISK_PCT} full (${DISK_AVAIL} free of ${DISK_TOTAL}). Consider cleanup before the next image update.`;
      } else {
        diskIcon.textContent = 'OK';
      }
    }

    if (ACCESS_MODE === 'lan_https' && HTTPS_PORT) {
      const certBtn = $('certBtn');
      const host = window.location.hostname || 'homeassistant.local';
      certBtn.href = 'https://' + host + ':' + HTTPS_PORT + '/cert/ca.crt';
      certBtn.classList.remove('hidden');
    }

    const wizardEl = $('wizard');
    const wizardContent = $('wizardContent');

    if (ACCESS_MODE === 'lan_https') {
      wizardEl.classList.remove('hidden');
      wizardContent.innerHTML = `
        <div class="banner success">Built-in HTTPS proxy is active on port <b>${HTTPS_PORT}</b>.</div>
        <ol>
          <li>Use <b>Open Gateway Web UI</b> above. The link will target HTTPS automatically.</li>
          <li>If the browser warns on first load, proceed once or install the local CA certificate for trust.</li>
          <li>For phones and tablets, use <b>Download CA Certificate</b> once and install it so the gateway opens cleanly after that.</li>
        </ol>`;
    } else if (ACCESS_MODE === 'lan_reverse_proxy') {
      wizardEl.classList.remove('hidden');
      wizardContent.innerHTML = `
        <ol>
          <li>Point your HTTPS reverse proxy at <code>&lt;HA-IP&gt;:${GW_PUBLIC_URL ? new URL(GW_PUBLIC_URL).port || '18790' : '18790'}</code>.</li>
          <li>Only set <code>gateway_public_url</code> if the final external hostname differs from the Home Assistant host you are already using.</li>
          <li>Set <code>gateway_trusted_proxies</code> to your proxy IP or CIDR.</li>
          <li>Restart the app after saving the configuration.</li>
        </ol>`;
    } else if (ACCESS_MODE === 'tailnet_https') {
      wizardEl.classList.remove('hidden');
      wizardContent.innerHTML = `
        <ol>
          <li>Confirm Tailscale is running on the Home Assistant host.</li>
          <li>Enable HTTPS certificates in Tailnet admin.</li>
          <li>Issue a certificate for the machine and set <code>gateway_public_url</code> to the final HTTPS host if the add-on cannot derive it automatically.</li>
          <li>Restart the app once the URL is in place.</li>
        </ol>`;
    } else if (ACCESS_MODE === 'local_only') {
      wizardEl.classList.remove('hidden');
      wizardContent.innerHTML = `
        <div class="banner info">Gateway is loopback-only. Use the embedded terminal or the same host for direct operator work.</div>
        <p>To reach the Control UI from phones or other browsers, switch <code>access_mode</code> to <b>lan_https</b>.</p>`;
    } else if (ACCESS_MODE === 'custom' && !isSecure) {
      wizardEl.classList.remove('hidden');
      wizardContent.innerHTML = `
        <div class="banner warn">This page is not in a secure context, so the browser cannot satisfy current Control UI requirements over plain LAN HTTP.</div>
        <p><b>Recommended:</b> switch <code>access_mode</code> to one of these in <b>Settings -> Apps -> OpenClaw Super Home Assistant -> Configuration</b>:</p>
        <ul>
          <li><b>lan_https</b> for the easiest built-in HTTPS path</li>
          <li><b>lan_reverse_proxy</b> if you already run NPM, Caddy, or Traefik</li>
          <li><b>tailnet_https</b> if your remote path is Tailscale-first</li>
        </ul>`;
    }

    function setBanner(targetId, message, hidden) {
      const element = $(targetId);
      if (!element) return;
      if (hidden || !message) {
        element.classList.add('hidden');
        if (targetId === 'errorBanner' || targetId === 'successBanner') {
          element.textContent = '';
        }
        return;
      }
      element.classList.remove('hidden');
      if (targetId === 'errorBanner' || targetId === 'successBanner') {
        element.textContent = message;
      }
    }

    async function fetchDashboardJson(path, options) {
      const response = await fetch(`${DASHBOARD_API_BASE}${path}`, Object.assign({ cache: 'no-store' }, options || {}));
      if (!response.ok) {
        throw new Error(`dashboard api ${path} failed (${response.status})`);
      }
      return response.json();
    }

    function renderFileButtons(containerId, entries) {
      const container = $(containerId);
      if (!container) return;
      container.innerHTML = '';
      entries.forEach(entry => {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'file-btn';
        if (entry.key === activeFileKey) {
          button.classList.add('active');
        }
        button.innerHTML = `<span>${escapeHtml(entry.name)}</span><span class="small">${escapeHtml(entry.path)}</span>`;
        button.addEventListener('click', () => openDashboardFile(entry.key));
        container.appendChild(button);
      });
    }

    async function openDashboardFile(fileKey) {
      const payload = await fetchDashboardJson(`/file?key=${encodeURIComponent(fileKey)}`);
      activeFileKey = payload.key;
      $('editorTitle').textContent = payload.key.replace(/^workspace:/, '').replace(/^skill:/, '');
      $('editorPath').textContent = payload.path;
      $('fileEditor').value = payload.content || '';
      renderLastState();
    }

    async function saveDashboardFile() {
      if (!activeFileKey) {
        setBanner('errorBanner', 'Choose a workspace or skill file before saving.', false);
        return;
      }
      await fetchDashboardJson('/file', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          key: activeFileKey,
          content: $('fileEditor').value
        })
      });
      setBanner('errorBanner', '', true);
      setBanner('successBanner', `Saved ${activeFileKey} to persistent storage.`, false);
      setTimeout(() => setBanner('successBanner', '', true), 3000);
      await loadDashboardState();
    }

    function schedulerPills(schedule) {
      const pills = [];
      const cronStatus = schedule?.cronStatus || {};
      const cronJobs = schedule?.cronJobs || {};
      const heartbeat = schedule?.heartbeatLast || {};
      if (cronStatus.error) {
        pills.push('<span class="pill off">Cron status unavailable</span>');
      } else {
        pills.push('<span class="pill good">Cron scheduler visible</span>');
      }
      const jobCount = Array.isArray(cronJobs.data?.jobs) ? cronJobs.data.jobs.length : Array.isArray(cronJobs.data) ? cronJobs.data.length : null;
      if (jobCount !== null) {
        pills.push(`<span class="pill ${jobCount > 0 ? 'good' : 'warn'}">${jobCount} cron job${jobCount === 1 ? '' : 's'}</span>`);
      }
      if (heartbeat.error) {
        pills.push('<span class="pill warn">Heartbeat unreadable</span>');
      } else {
        pills.push('<span class="pill good">Heartbeat reachable</span>');
      }
      return pills.join('');
    }

    function renderIntegrations(data, graph) {
      const grid = $('integrationGrid');
      const cards = [];
      const buildCard = (title, configured, meta) => `
        <div class="integration-card">
          <b>${escapeHtml(title)}</b>
          <div class="pill-row">
            <span class="pill ${configured ? 'good' : 'off'}">${configured ? 'Configured' : 'Not configured'}</span>
          </div>
          <div class="meta">${meta}</div>
        </div>`;

      cards.push(buildCard('Context7', !!data?.context7?.configured, `Secret path: <code>${escapeHtml(data?.context7?.secretPath || '')}</code>`));
      cards.push(buildCard('Domotz', !!data?.domotz?.configured, `Site ID: <code>${escapeHtml(data?.domotz?.siteId || 'unset')}</code><br>Secret path: <code>${escapeHtml(data?.domotz?.secretPath || '')}</code>`));
      cards.push(buildCard('MQTT / HiveMQ', !!data?.mqtt?.configured, `Broker: <code>${escapeHtml(data?.mqtt?.brokerUrl || 'unset')}</code><br>Username: ${data?.mqtt?.usernameConfigured ? 'configured' : 'unset'}<br>Password: ${data?.mqtt?.passwordConfigured ? 'configured' : 'unset'}`));
      cards.push(buildCard('BACnet Scout', !!data?.bacnet?.configured, escapeHtml(data?.bacnet?.notes || 'Opt-in only.')));
      cards.push(buildCard('Home Assistant MCP', !!data?.homeAssistantMcp?.configured, `Token path: <code>${escapeHtml(data?.homeAssistantMcp?.tokenPath || '')}</code>`));
      cards.push(`
        <div class="integration-card">
          <b>System Graph</b>
          <div class="pill-row">
            <span class="pill good">${escapeHtml(String(graph?.nodeCount ?? 0))} nodes</span>
            <span class="pill good">${escapeHtml(String(graph?.edgeCount ?? 0))} edges</span>
          </div>
          <div class="meta">SQLite path: <code>${escapeHtml(graph?.path || '')}</code></div>
        </div>`);
      grid.innerHTML = cards.join('');
    }

    let lastDashboardState = null;
    function renderLastState() {
      if (!lastDashboardState) return;
      renderFileButtons('workspaceList', lastDashboardState.workspaceFiles || []);
      renderFileButtons('skillList', lastDashboardState.skillFiles || []);
    }

    async function loadDashboardState() {
      try {
        const payload = await fetchDashboardJson('/state');
        lastDashboardState = payload;
        renderLastState();
        $('scheduleSummary').innerHTML = schedulerPills(payload.schedule || {});
        $('cronJobsBlock').textContent = prettyJson(payload.schedule?.cronJobs?.error || payload.schedule?.cronJobs?.data);
        $('cronRunsBlock').textContent = prettyJson(payload.schedule?.cronRuns?.error || payload.schedule?.cronRuns?.data);
        $('heartbeatBlock').textContent = prettyJson(payload.schedule?.heartbeatLast?.error || payload.schedule?.heartbeatLast?.data);
        renderIntegrations(payload.integrations || {}, payload.graph || {});
        if (!activeFileKey && payload.workspaceFiles?.length) {
          await openDashboardFile(payload.workspaceFiles[0].key);
        }
      } catch (error) {
        setBanner('errorBanner', `Dashboard data could not be loaded: ${error.message}`, false);
        $('cronJobsBlock').textContent = 'Dashboard API unavailable.';
        $('cronRunsBlock').textContent = 'Dashboard API unavailable.';
        $('heartbeatBlock').textContent = 'Dashboard API unavailable.';
      }
    }

    $('reloadFileBtn').addEventListener('click', () => {
      if (activeFileKey) openDashboardFile(activeFileKey);
    });
    $('saveFileBtn').addEventListener('click', saveDashboardFile);
    loadDashboardState();

  })();
  </script>
</body>
</html>
    const gwButton = $('gwbtn');
    if (RESOLVED_GATEWAY_BASE_URL) {
      gwButton.href = `${RESOLVED_GATEWAY_BASE_URL}/?token=${encodeURIComponent(GW_TOKEN)}`;
    } else if (!GW_PUBLIC_URL) {
      gwButton.classList.remove('primary');
      gwButton.classList.add('secondary');
      gwButton.textContent = 'Configure Gateway URL';
      gwButton.href = '#';
      gwButton.addEventListener('click', function(event) {
        event.preventDefault();
        setBanner('errorBanner', 'The add-on could not derive a usable Gateway URL automatically for this access mode. Set gateway_public_url only if you are using a reverse proxy, Tailscale hostname, or another non-default path.', false);
      });
    }
