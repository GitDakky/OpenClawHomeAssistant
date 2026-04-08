<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>OpenClaw Super Home Assistant</title>
  <style>
    :root{
      --bg:#05080d;
      --bg-accent:#0a1017;
      --panel:#0d141ccc;
      --panel-strong:#121a24;
      --panel-soft:#16202b;
      --line:#243240;
      --line-strong:#35607b;
      --text:#e9eef5;
      --muted:#96a4b3;
      --accent:#78a6c7;
      --accent-strong:#9cc1dc;
      --accent-soft:#6f8fa8;
      --warn:#f2b84b;
      --danger:#e36c6c;
      --success:#58c18d;
      --code:#0a1118;
      --shadow:0 18px 48px rgba(0,0,0,.34);
      --radius:18px;
    }
    *{box-sizing:border-box}
    html,body{margin:0;min-height:100%}
    body{
      font-family:"IBM Plex Sans","Aptos","Segoe UI",sans-serif;
      color:var(--text);
      background:
        radial-gradient(circle at top left, rgba(90,126,156,.16), transparent 32%),
        radial-gradient(circle at top right, rgba(56,84,106,.12), transparent 26%),
        linear-gradient(180deg, #091018 0%, #05080d 58%, #03050a 100%);
      padding:28px 18px 36px;
      font-size:14px;
    }
    a,button{font:inherit}
    code,pre{
      font-family:"IBM Plex Mono","JetBrains Mono","Cascadia Code",monospace;
      font-variant-numeric:tabular-nums;
    }
    .shell{
      max-width:1120px;
      margin:0 auto;
      display:grid;
      gap:18px;
    }
    .hero{
      display:grid;
      grid-template-columns:1fr;
      gap:16px;
    }
    .panel{
      position:relative;
      overflow:hidden;
      border-radius:var(--radius);
      border:1px solid rgba(97,123,145,.18);
      background:linear-gradient(180deg, rgba(13,20,28,.97), rgba(9,14,20,.97));
      box-shadow:var(--shadow);
      backdrop-filter:blur(12px);
    }
    .panel::before{
      content:"";
      position:absolute;
      inset:0;
      pointer-events:none;
      background:linear-gradient(140deg, rgba(140,174,198,.06), transparent 38%, rgba(91,122,146,.05));
    }
    .hero-main{
      padding:26px 26px 24px;
      display:grid;
      gap:18px;
    }
    .eyebrow{
      display:inline-flex;
      align-items:center;
      gap:10px;
      color:#b2c2d2;
      font-size:11px;
      font-weight:700;
      text-transform:uppercase;
      letter-spacing:.18em;
    }
    .eyebrow::before{
      content:"";
      width:34px;
      height:2px;
      border-radius:999px;
      background:linear-gradient(90deg, var(--accent), var(--accent-soft));
      box-shadow:0 0 12px rgba(120,166,199,.32);
    }
    h1{
      margin:0;
      font-size:clamp(30px, 4.2vw, 46px);
      line-height:1;
      letter-spacing:-.04em;
      max-width:12ch;
    }
    .lede{
      margin:0;
      max-width:58ch;
      color:#c1ccd8;
      font-size:14px;
      line-height:1.6;
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
      min-height:36px;
      padding:8px 12px;
      border-radius:999px;
      background:rgba(12,18,26,.9);
      border:1px solid rgba(88,110,129,.24);
      color:var(--muted);
      font-size:11px;
      text-transform:uppercase;
      letter-spacing:.08em;
    }
    .chip code{
      color:var(--text);
      background:transparent;
      padding:0;
      font-size:11px;
    }
    .hero-note{
      display:grid;
      gap:10px;
      max-width:64ch;
      padding:18px 20px;
      border-radius:16px;
      background:linear-gradient(180deg, rgba(14,20,27,.9), rgba(10,15,21,.86));
      border:1px solid rgba(94,119,139,.18);
    }
    .hero-note b{
      color:var(--text);
      font-size:13px;
      letter-spacing:.08em;
      text-transform:uppercase;
    }
    .hero-note p{
      margin:0;
      color:var(--muted);
      line-height:1.55;
      font-size:12px;
    }
    .hero-side{
      padding:22px;
      display:grid;
      gap:16px;
    }
    .mini-card{
      position:relative;
      border-radius:16px;
      padding:16px 16px 14px;
      background:linear-gradient(180deg, rgba(14,21,28,.95), rgba(10,15,21,.92));
      border:1px solid rgba(93,117,136,.18);
    }
    .mini-card h2{
      margin:0 0 6px;
      font-size:12px;
      letter-spacing:.14em;
      text-transform:uppercase;
      color:#d2d9e1;
    }
    .mini-card p{
      margin:0;
      color:var(--muted);
      font-size:12px;
      line-height:1.55;
    }
    .status-grid{
      display:grid;
      grid-template-columns:repeat(4, minmax(0, 1fr));
      gap:10px;
    }
    .status-item{
      display:grid;
      grid-template-columns:28px 1fr;
      gap:12px;
      align-items:start;
      padding:14px 14px 13px;
      border-radius:16px;
      background:linear-gradient(180deg, rgba(13,19,26,.94), rgba(9,14,20,.9));
      border:1px solid rgba(77,99,117,.2);
      font-size:14px;
      line-height:1.45;
    }
    .status-item .icon{
      display:grid;
      place-items:center;
      width:28px;
      height:28px;
      border-radius:8px;
      background:rgba(120,166,199,.1);
      font-size:12px;
      font-weight:700;
      letter-spacing:.08em;
    }
    .status-item.good{
      border-color:rgba(88,193,141,.3);
      background:linear-gradient(180deg, rgba(10,30,22,.95), rgba(8,18,14,.92));
    }
    .status-item.good .icon{
      background:rgba(88,193,141,.18);
      color:#d7ffe9;
    }
    .status-item.warn{
      border-color:rgba(242,184,75,.32);
      background:linear-gradient(180deg, rgba(45,30,12,.95), rgba(26,17,7,.92));
    }
    .status-item.warn .icon{
      background:rgba(242,184,75,.18);
      color:#ffe4b4;
    }
    .status-item.off{
      border-color:rgba(227,108,108,.32);
      background:linear-gradient(180deg, rgba(49,18,18,.95), rgba(26,10,10,.92));
    }
    .status-item.off .icon{
      background:rgba(227,108,108,.18);
      color:#ffd5d5;
    }
    .status-item b{color:var(--text)}
    .status-label{
      font-size:10px;
      text-transform:uppercase;
      letter-spacing:.14em;
      color:var(--muted);
      margin-bottom:6px;
      display:block;
    }
    .action-row .btn{
      display:inline-flex;
      align-items:center;
      justify-content:center;
      gap:10px;
      min-height:42px;
      padding:0 16px;
      border:0;
      border-radius:12px;
      text-decoration:none;
      cursor:pointer;
      transition:transform .18s ease, filter .18s ease, box-shadow .18s ease;
      font-size:12px;
      letter-spacing:.08em;
      text-transform:uppercase;
    }
    .btn:hover{transform:translateY(-1px);filter:brightness(1.07)}
    .btn.primary{
      color:#07111f;
      font-weight:700;
      background:linear-gradient(135deg, #64b3ff, #7ce7d2);
      box-shadow:0 10px 24px rgba(120,166,199,.18);
    }
    .btn.secondary{
      color:var(--text);
      background:rgba(19,28,39,.92);
      border:1px solid rgba(88,114,146,.24);
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
    .tab-shell{
      padding:18px 20px 20px;
      display:grid;
      gap:16px;
    }
    .tab-shell-head{
      display:flex;
      gap:14px;
      justify-content:space-between;
      align-items:flex-end;
      flex-wrap:wrap;
    }
    .tab-shell-head h2{
      margin:4px 0 0;
      font-size:22px;
      letter-spacing:-.04em;
    }
    .tab-shell-head p{
      margin:0;
      max-width:70ch;
      color:var(--muted);
      font-size:12px;
      line-height:1.55;
    }
    .tab-bar{
      display:flex;
      gap:10px;
      flex-wrap:wrap;
    }
    .tab-btn{
      appearance:none;
      border:1px solid rgba(88,114,146,.22);
      background:rgba(10,17,24,.86);
      color:#d6e2f0;
      min-height:38px;
      padding:0 14px;
      border-radius:11px;
      cursor:pointer;
      font-size:11px;
      font-weight:700;
      letter-spacing:.1em;
      text-transform:uppercase;
      transition:transform .18s ease, border-color .18s ease, background .18s ease, color .18s ease;
    }
    .tab-btn:hover{
      transform:translateY(-1px);
      border-color:rgba(120,166,199,.32);
    }
    .tab-btn.active{
      border-color:rgba(120,166,199,.4);
      background:linear-gradient(180deg, rgba(18,38,58,.96), rgba(12,24,39,.94));
      color:#eff7ff;
      box-shadow:0 0 0 1px rgba(120,166,199,.14) inset;
    }
    .tab-panels{
      display:grid;
      gap:18px;
    }
    .tab-panel{
      display:none;
      gap:18px;
      align-content:start;
    }
    .tab-panel.active{
      display:grid;
    }
    .banner{
      padding:14px 16px;
      border-radius:14px;
      border:1px solid transparent;
      font-size:12px;
      line-height:1.55;
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
      padding:18px 20px;
      border-radius:16px;
      border:1px solid rgba(110,145,190,.18);
      background:linear-gradient(180deg, rgba(12,18,24,.98), rgba(9,14,20,.96));
      box-shadow:var(--shadow);
    }
    .wizard h3{
      margin:0 0 10px;
      font-size:16px;
      letter-spacing:-.02em;
    }
    .wizard p,
    .wizard li{
      color:var(--muted);
      line-height:1.65;
      font-size:12px;
    }
    .wizard ol,
    .wizard ul{
      margin:8px 0 0;
      padding-left:22px;
    }
    .guides{
      display:grid;
      grid-template-columns:1fr;
      gap:18px;
    }
    .ops-grid{
      display:grid;
      grid-template-columns:1fr;
      gap:18px;
      align-items:start;
    }
    .ops-panel{
      padding:20px;
      display:grid;
      gap:14px;
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
      font-size:17px;
      letter-spacing:-.03em;
    }
    .ops-head p,
    .stack-card p,
    .file-group p{
      margin:0;
      color:var(--muted);
      font-size:12px;
      line-height:1.55;
    }
    .editor-layout{
      display:grid;
      grid-template-columns:1fr;
      gap:16px;
      align-items:start;
    }
    .file-groups{
      display:grid;
      grid-template-columns:repeat(2, minmax(0, 1fr));
      gap:16px;
    }
    .file-group{
      display:grid;
      gap:10px;
    }
    .file-list{
      display:grid;
      gap:8px;
      max-height:220px;
      overflow:auto;
      padding-right:4px;
    }
    .file-btn{
      text-align:left;
      width:100%;
      border:1px solid rgba(88,114,146,.18);
      background:rgba(9,17,30,.78);
      color:var(--text);
      border-radius:12px;
      padding:10px 12px;
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
      font-size:11px;
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
      font-size:14px;
    }
    .editor{
      width:100%;
      min-height:380px;
      resize:vertical;
      border-radius:14px;
      border:1px solid rgba(88,114,146,.22);
      background:var(--code);
      color:#e4efff;
      padding:16px;
      font-family:"SFMono-Regular","JetBrains Mono","Cascadia Code",monospace;
      font-size:12px;
      line-height:1.6;
      outline:none;
    }
    .stack{
      display:grid;
      gap:12px;
    }
    .stack-card{
      padding:14px;
      border-radius:14px;
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
      min-height:30px;
      padding:0 10px;
      border-radius:999px;
      background:rgba(14,27,46,.92);
      border:1px solid rgba(88,114,146,.18);
      color:#deebff;
      font-size:10px;
      letter-spacing:.1em;
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
      grid-template-columns:repeat(2, minmax(0, 1fr));
      gap:12px;
      min-height:220px;
    }
    .integration-card{
      border-radius:14px;
      padding:14px;
      background:rgba(9,17,30,.76);
      border:1px solid rgba(88,114,146,.18);
      display:grid;
      gap:8px;
      align-content:start;
      min-height:200px;
    }
    .integration-card b{
      font-size:15px;
    }
    .integration-card .meta{
      color:var(--muted);
      font-size:12px;
      line-height:1.5;
      word-break:break-word;
    }
    .guide-card{
      padding:22px;
      display:grid;
      gap:12px;
    }
    details{
      border-radius:14px;
      background:rgba(11,17,23,.76);
      border:1px solid rgba(88,114,146,.18);
      overflow:hidden;
    }
    details > summary{
      cursor:pointer;
      padding:14px 16px;
      font-size:13px;
      font-weight:700;
      color:#dfe9f8;
      list-style:none;
    }
    details > summary::-webkit-details-marker{display:none}
    details > div{
      padding:0 16px 16px;
      color:var(--muted);
      font-size:12px;
      line-height:1.6;
    }
    pre{
      margin:10px 0 0;
      overflow:auto;
      border-radius:12px;
      padding:12px;
      background:var(--code);
      border:1px solid rgba(88,114,146,.18);
      color:#d8e8ff;
      font-size:11px;
      line-height:1.55;
    }
    code{
      background:rgba(7,17,31,.9);
      padding:2px 6px;
      border-radius:8px;
      color:#d8e8ff;
      font-size:11px;
    }
    .terminal-shell{
      padding:20px;
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
      font-size:24px;
      letter-spacing:-.04em;
    }
    .terminal-head p{
      margin:0;
      color:var(--muted);
      font-size:12px;
      max-width:64ch;
      line-height:1.55;
    }
    .term{
      height:64vh;
      min-height:400px;
      border-radius:16px;
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
      letter-spacing:.14em;
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
      .guides{grid-template-columns:1fr}
      .ops-panel.wide{grid-row:auto}
      .editor-layout{grid-template-columns:1fr}
      .status-grid{grid-template-columns:repeat(2, minmax(0, 1fr))}
      .integration-grid{grid-template-columns:1fr}
    }
    @media (max-width: 720px){
      body{padding:18px 12px 24px}
      .hero-main,.hero-side,.terminal-shell{padding:18px}
      .status-item{min-height:unset}
      .status-grid{grid-template-columns:1fr}
      .file-groups{grid-template-columns:1fr}
      h1{max-width:none}
      .terminal-head h3{font-size:24px}
      .term{height:56vh;min-height:340px}
    }
  </style>
</head>
<body>
  <div class="shell">
    <section class="panel terminal-shell">
      <div class="terminal-head">
        <div>
          <div class="eyebrow">Embedded Terminal</div>
          <h3>Direct operator console</h3>
          <p>
            Keep doctor runs, token inspection, migration recovery, and live debugging in the terminal first.
            The rest of the page is split into tabs so the operator surface stays compact and predictable.
          </p>
        </div>
        <div class="action-row">
          <a class="btn secondary" href="./terminal/" target="_self">Open Terminal (full page)</a>
        </div>
      </div>
      <div class="term">
        <iframe src="./terminal/" title="Terminal"></iframe>
      </div>
    </section>

    <section class="panel tab-shell">
      <div class="tab-shell-head">
        <div>
          <div class="eyebrow">Operator Sections</div>
          <h2>Jump to the surface you need</h2>
        </div>
        <p>
          The operator page now keeps one work surface in view at a time: overview, help, workspace, runtime, insights, or integrations.
        </p>
      </div>
      <div class="tab-bar" role="tablist" aria-label="Operator sections">
        <button class="tab-btn active" type="button" role="tab" aria-selected="true" aria-controls="tab-overview" data-tab-target="overview">Overview</button>
        <button class="tab-btn" type="button" role="tab" aria-selected="false" aria-controls="tab-help" data-tab-target="help">Help</button>
        <button class="tab-btn" type="button" role="tab" aria-selected="false" aria-controls="tab-workspace" data-tab-target="workspace">Workspace</button>
        <button class="tab-btn" type="button" role="tab" aria-selected="false" aria-controls="tab-runtime" data-tab-target="runtime">Runtime</button>
        <button class="tab-btn" type="button" role="tab" aria-selected="false" aria-controls="tab-insights" data-tab-target="insights">Insights</button>
        <button class="tab-btn" type="button" role="tab" aria-selected="false" aria-controls="tab-integrations" data-tab-target="integrations">Integrations</button>
      </div>
    </section>

    <div class="tab-panels">
      <section class="tab-panel active" id="tab-overview" data-tab-panel="overview" role="tabpanel">
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
      </section>

      <section class="tab-panel" id="tab-help" data-tab-panel="help" role="tabpanel">
        <section class="guides">
          <div class="panel guide-card">
            <div class="ops-head">
              <div class="eyebrow">Operator Help</div>
              <h3>Access, control, and recovery notes</h3>
              <p>
                Keep the guidance in one place. Open the section you need without turning the landing page into four competing documentation cards.
              </p>
            </div>

            <details>
              <summary>Token and access quick help</summary>
              <div>
                <p>
                  The Gateway UI opens in a separate tab to avoid Home Assistant ingress websocket quirks.
                  In most local installs the launch URL is derived automatically. Set <code>gateway_public_url</code> only when you need to override the detected host or point at a reverse-proxy / Tailscale URL.
                </p>
                <p>
                  If this add-on is using a remote gateway, keep <code>gateway_remote_url</code> as the backend <code>ws://</code> or <code>wss://</code> endpoint.
                  Set <code>gateway_public_url</code> separately only when you want this page to open a browser-facing <code>http://</code> or <code>https://</code> Control UI URL.
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
                <p>
                  This fork mounts the live Home Assistant config tree at <code>/ha-config</code>. Keep <code>/config</code> for OpenClaw workspace state and use <code>/ha-config</code> for <code>configuration.yaml</code>, <code>secrets.yaml</code>, <code>custom_components/</code>, <code>packages/</code>, and <code>.storage/</code>.
                </p>
              </div>
            </details>
          </div>
        </section>
      </section>

      <section class="tab-panel" id="tab-workspace" data-tab-panel="workspace" role="tabpanel">
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
                <div class="subtle" id="editorPath">Dashboard editing targets the add-on workspace under /config. The live Home Assistant config root is mounted separately at /ha-config.</div>
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
      </section>

      <section class="tab-panel" id="tab-runtime" data-tab-panel="runtime" role="tabpanel">
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
      </section>

      <section class="tab-panel" id="tab-insights" data-tab-panel="insights" role="tabpanel">
        <section class="panel ops-panel">
        <div class="ops-head">
          <div class="eyebrow">Home Intelligence</div>
          <h3>Read-only operator insights</h3>
          <p>
            These cards turn live Home Assistant state plus local add-on settings into a bounded operator summary:
            homeowner changes, energy pressure, system drift, predictive maintenance, and security posture.
          </p>
        </div>
        <div class="integration-grid" id="insightGrid">
          <div class="integration-card">
            <b>Loading insight cards...</b>
            <div class="meta">The dashboard API is building a read-only snapshot from Home Assistant and the add-on runtime.</div>
          </div>
        </div>
        </section>
      </section>

      <section class="tab-panel" id="tab-integrations" data-tab-panel="integrations" role="tabpanel">
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
    </div>
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
    const tabButtons = Array.from(document.querySelectorAll('[data-tab-target]'));
    const tabPanels = Array.from(document.querySelectorAll('[data-tab-panel]'));
    const TAB_STORAGE_KEY = 'openclaw.operatorTab';
    function setStatusCard(targetId, level, icon, label, message) {
      const element = $(targetId);
      if (!element) return;
      element.className = `status-item ${level}`;
      element.innerHTML = `<span class="icon">${icon}</span><span><span class="status-label">${label}</span>${message}</span>`;
    }
    function activateTab(name, syncHash = true) {
      let found = false;
      tabButtons.forEach(button => {
        const active = button.dataset.tabTarget === name;
        button.classList.toggle('active', active);
        button.setAttribute('aria-selected', active ? 'true' : 'false');
        if (active) found = true;
      });
      tabPanels.forEach(panel => {
        const active = panel.dataset.tabPanel === name;
        panel.classList.toggle('active', active);
      });
      if (!found) return;
      try { window.localStorage.setItem(TAB_STORAGE_KEY, name); } catch {}
      if (syncHash) {
        const nextHash = `tab-${name}`;
        if (window.location.hash !== `#${nextHash}`) {
          history.replaceState(null, '', `#${nextHash}`);
        }
      }
    }
    tabButtons.forEach(button => {
      button.addEventListener('click', () => activateTab(button.dataset.tabTarget));
    });
    const initialTab = (() => {
      const hashMatch = window.location.hash.match(/^#tab-([a-z0-9_-]+)$/i);
      if (hashMatch && tabButtons.some(button => button.dataset.tabTarget === hashMatch[1])) {
        return hashMatch[1];
      }
      try {
        const stored = window.localStorage.getItem(TAB_STORAGE_KEY);
        if (stored && tabButtons.some(button => button.dataset.tabTarget === stored)) {
          return stored;
        }
      } catch {}
      return 'overview';
    })();
    activateTab(initialTab, false);
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
        setBanner(
          'errorBanner',
          GATEWAY_MODE !== 'local'
            ? 'Remote gateway mode is active. Keep gateway_remote_url as the backend ws:// or wss:// endpoint, and set gateway_public_url only if you want this page to open a browser-facing http:// or https:// Control UI URL.'
            : 'The add-on could not derive a usable Gateway URL automatically for this access mode. Set gateway_public_url only if you are using a reverse proxy, Tailscale hostname, or another non-default path.',
          false
        );
      });
    }

    const isSecure = window.isSecureContext;
    const secureBadge = $('secureBadge');
    if (isSecure) {
      secureBadge.textContent = 'Secure';
      secureBadge.className = 'badge secure';
      setStatusCard('statusSecure', 'good', 'TLS', 'Secure Context', 'Browser context is <b>ready</b> for device identity and Control UI auth.');
    } else {
      secureBadge.textContent = 'Not Secure';
      secureBadge.className = 'badge insecure';
      setStatusCard('statusSecure', 'off', 'TLS', 'Secure Context', 'Browser context is <b>not secure</b>. Control UI requires HTTPS or localhost.');
    }

    setStatusCard(
      'statusAccess',
      ACCESS_MODE === 'custom' ? 'warn' : 'good',
      'CFG',
      'Access Mode',
      `<b>${escapeHtml(ACCESS_MODE)}</b>`
    );

    (async function checkGateway() {
      if (GATEWAY_MODE !== 'local' && !RESOLVED_GATEWAY_BASE_URL) {
        setStatusCard('statusGateway', 'warn', 'GW', 'Gateway', 'Remote gateway mode is active. Set <b>gateway_public_url</b> if you want this page to open or probe the remote Control UI directly.');
        return;
      }
      try {
        const url = RESOLVED_GATEWAY_BASE_URL
          ? RESOLVED_GATEWAY_BASE_URL + '/api/health' + (GW_TOKEN ? ('?token=' + encodeURIComponent(GW_TOKEN)) : '')
          : '/api/health';
        const r = await fetch(url, { mode: 'no-cors', cache: 'no-store' }).catch(() => null);
        if (r && (r.ok || r.type === 'opaque')) {
          setStatusCard('statusGateway', 'good', 'GW', 'Gateway', 'Gateway runtime looks <b>reachable</b>.');
        } else {
          setStatusCard('statusGateway', 'warn', 'GW', 'Gateway', 'Gateway is <b>still starting</b> or not yet reachable from this page.');
        }
      } catch {
        setStatusCard('statusGateway', 'off', 'GW', 'Gateway', 'Gateway is <b>unreachable</b> from this page right now.');
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
      if (pctNum >= 90) {
        diskIcon.textContent = 'WRN';
        setStatusCard('statusDisk', 'off', 'WRN', 'Disk', `${escapeHtml(DISK_USED)} / ${escapeHtml(DISK_TOTAL)} (${escapeHtml(DISK_PCT)}) - ${escapeHtml(DISK_AVAIL)} free`);
        $('diskBanner').classList.remove('hidden');
        $('diskBannerText').textContent =
          `Disk is ${DISK_PCT} full (${DISK_AVAIL} free of ${DISK_TOTAL}).`;
      } else if (pctNum >= 75) {
        diskIcon.textContent = 'OBS';
        setStatusCard('statusDisk', 'warn', 'OBS', 'Disk', `${escapeHtml(DISK_USED)} / ${escapeHtml(DISK_TOTAL)} (${escapeHtml(DISK_PCT)}) - ${escapeHtml(DISK_AVAIL)} free`);
        $('diskBanner').classList.remove('hidden');
        $('diskBannerText').textContent =
          `Disk is ${DISK_PCT} full (${DISK_AVAIL} free of ${DISK_TOTAL}). Consider cleanup before the next image update.`;
      } else {
        diskIcon.textContent = 'OK';
        setStatusCard('statusDisk', 'good', 'OK', 'Disk', `${escapeHtml(DISK_USED)} / ${escapeHtml(DISK_TOTAL)} (${escapeHtml(DISK_PCT)}) - ${escapeHtml(DISK_AVAIL)} free`);
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

    if (GATEWAY_MODE !== 'local') {
      wizardEl.classList.remove('hidden');
      wizardContent.innerHTML = `
        <div class="banner info">Remote gateway mode is active. This add-on stays the operator surface while the real gateway runs elsewhere.</div>
        <ol>
          <li>Keep <code>gateway_remote_url</code> as the backend <code>ws://</code> or <code>wss://</code> endpoint used by the add-on runtime.</li>
          <li>If you want <b>Open Gateway Web UI</b> to open the remote Control UI, set <code>gateway_public_url</code> to the browser-facing <code>http://</code> or <code>https://</code> URL.</li>
          <li>Use the remote gateway's auth token when the UI asks for it.</li>
          <li>Do not paste a websocket URL into <code>gateway_public_url</code>.</li>
        </ol>`;
    } else if (ACCESS_MODE === 'lan_https') {
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
      cards.push(buildCard('GitHub Issues', !!data?.githubIssues?.configured, `Repo: <code>${escapeHtml(data?.githubIssues?.repo || 'GitDakky/OpenClawHomeAssistant')}</code><br>Command: <code>${escapeHtml(data?.githubIssues?.command || 'oc-report-issue')}</code><br>Secret path: <code>${escapeHtml(data?.githubIssues?.secretPath || '')}</code>`));
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

    function renderInsights(insights) {
      const grid = $('insightGrid');
      const cards = [];
      const order = ['homeowner', 'energy', 'system', 'maintenance', 'security'];
      const buildList = (items, emptyLabel) => {
        if (!items || !items.length) {
          return `<div class="meta">${escapeHtml(emptyLabel)}</div>`;
        }
        return `<ul>${items.map(item => `<li>${escapeHtml(item)}</li>`).join('')}</ul>`;
      };

      order.forEach(key => {
        const card = insights?.[key];
        if (!card) {
          return;
        }
        const statusClass = card.status === 'good' ? 'good' : card.status === 'warn' ? 'warn' : 'off';
        cards.push(`
          <div class="integration-card">
            <b>${escapeHtml(card.title || key)}</b>
            <div class="pill-row">
              <span class="pill ${statusClass}">${escapeHtml((card.status || 'info').toUpperCase())}</span>
              ${(card.pills || []).map(item => `<span class="pill">${escapeHtml(item)}</span>`).join('')}
            </div>
            <div class="meta">${escapeHtml(card.summary || '')}</div>
            <div class="meta"><b>Highlights</b>${buildList(card.highlights, 'No notable signals right now.')}</div>
            <div class="meta"><b>Next actions</b>${buildList(card.actions, 'No immediate operator action suggested.')}</div>
          </div>`);
      });

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
        renderInsights(payload.insights || {});
        renderIntegrations(payload.integrations || {}, payload.graph || {});
        if (!activeFileKey && payload.workspaceFiles?.length) {
          await openDashboardFile(payload.workspaceFiles[0].key);
        }
      } catch (error) {
        setBanner('errorBanner', `Dashboard data could not be loaded: ${error.message}`, false);
        $('cronJobsBlock').textContent = 'Dashboard API unavailable.';
        $('cronRunsBlock').textContent = 'Dashboard API unavailable.';
        $('heartbeatBlock').textContent = 'Dashboard API unavailable.';
        $('insightGrid').innerHTML = '<div class="integration-card"><b>Insight cards unavailable</b><div class="meta">Dashboard API unavailable.</div></div>';
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
