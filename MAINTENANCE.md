# Maintenance

This fork is maintained as a Home Assistant image build that bundles a pinned OpenClaw release.

## Source of truth

- Bundled OpenClaw version pin: `openclaw_assistant/Dockerfile`
  - `ARG BUILD_ARCH=...` selects the Home Assistant Debian base image template
  - `ARG OPENCLAW_VERSION=...`
- Add-on release version: `openclaw_assistant/config.yaml`
- Published image name: `openclaw_assistant/config.yaml`
- User-facing release notes: `openclaw_assistant/CHANGELOG.md`
- User docs: `README.md`, `DOCS.md`

## Safe bump workflow

1. Verify the target version is actually published upstream.
   - `npm view openclaw dist-tags --json`
   - `npm view openclaw@<version> version dist.tarball engines bin --json`
   - If the requested version is not on npm and not tagged upstream, do not silently invent it.
2. Update `ARG OPENCLAW_VERSION` in `openclaw_assistant/Dockerfile`.
3. Keep the build pipeline aligned with current Home Assistant guidance.
   - `build.yaml` is intentionally removed.
   - The Dockerfile is the build source of truth.
   - `.github/workflows/build-addon.yaml` publishes the multi-arch image from `main`.
4. Review upstream drift before shipping:
   - `openclaw --version`
   - `openclaw gateway --help`
   - `openclaw node --help`
   - `openclaw onboard --help`
   - Gateway auth / Control UI docs
5. Re-check wrapper assumptions in:
   - `openclaw_assistant/run.sh`
   - `openclaw_assistant/oc_config_helper.py`
   - `openclaw_assistant/render_nginx.py`
   - `openclaw_assistant/landing.html.tpl`
6. Update:
   - `openclaw_assistant/config.yaml` add-on version
   - `openclaw_assistant/CHANGELOG.md`
   - `README.md` and `DOCS.md` bundled-version references if needed
7. Run validation:

```sh
bash -n openclaw_assistant/run.sh
python3 -m py_compile openclaw_assistant/oc_config_helper.py
python3 -m py_compile openclaw_assistant/render_nginx.py
python3 -c "import xml.etree.ElementTree as ET; ET.parse('assets/openclaw-hero.svg'); ET.parse('assets/openclaw-architecture.svg')"
```

## Known wrapper-specific risk

When the add-on switches to `trusted-proxy` auth, OpenClaw 2026.4.x rejects configs that still contain a shared gateway token. The helper script must remove `gateway.auth.token` in `trusted-proxy` mode and regenerate one when switching back to `token` mode.
