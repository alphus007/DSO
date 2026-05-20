# DevSecOps WP Lab — Automated Vulnerability Discovery & Remediation

WordPress + WPScan + GitHub Actions — DSO 2026

A two-stage pipeline:

1. Stand up a deliberately old WordPress (`wordpress:5.0-php7.2-apache`) and scan it with WPScan to surface real findings.
2. Build a hardened image (`Dockerfile.hardened`, based on `wordpress:6.8-php8.3-apache`), push to GHCR and Docker Hub, re-scan, and gate the build on remaining critical findings.

## Layout

```
.
├── README.md
├── Dockerfile.hardened
├── docker-entrypoint-hardened.sh
├── DevSecOps_WP_Lab_Report.pdf     ← the writeup (generated from real scans)
├── build_report.py                  ← regenerates the PDF from scans/*.json
├── docker/
│   ├── docker-compose.yml           ← vulnerable baseline stack (port 8080)
│   ├── docker-compose.hardened.yml  ← hardened stack from local image (port 8081)
│   └── wp-config-placeholder.txt
├── scans/
│   ├── baseline_*.json/.txt
│   └── hardened_*.json/.txt
├── src/
│   └── notes.txt
└── .github/workflows/
    └── scan.yml                     ← 3-job pipeline
```

## Run it locally

### Baseline (vulnerable)

```bash
docker compose -f docker/docker-compose.yml up -d
# open http://localhost:8080/ and finish the install wizard
docker run --rm --network host wpscanteam/wpscan \
  --url http://localhost:8080 --enumerate u,p,t --force --no-banner
```

### Hardened

```bash
docker build -f Dockerfile.hardened -t wordpress-hardened:local .
docker compose -f docker/docker-compose.hardened.yml up -d
# open http://localhost:8081/ and finish the install wizard
docker run --rm --network host wpscanteam/wpscan \
  --url http://localhost:8081 --enumerate u,p,t --force --no-banner
```

### Regenerate the report PDF

```bash
pip install reportlab
python3 build_report.py
```

## GitHub Actions

`.github/workflows/scan.yml` has three jobs:

| Job | What it does |
|-----|-------------|
| `wpscan-baseline` | Brings up the vulnerable stack on a runner, scans, uploads + commits artifacts |
| `build-hardened` | Builds `Dockerfile.hardened`, pushes `hardened-latest` + `sha-<hash>` to GHCR (and Docker Hub if the secret is set) |
| `wpscan-hardened` | Pulls the new image, scans it, and **fails the build** if CRITICAL findings (CVSS ≥ 9) or an `insecure` core remain |

### Required secrets

| Secret | What for |
|--------|----------|
| `WPSCAN_API_TOKEN` | optional — enables vulnerability detail in scan output |
| `DOCKERHUB_USERNAME` | optional — Docker Hub push is skipped if unset |
| `DOCKERHUB_TOKEN`    | paired with the username |

`GITHUB_TOKEN` is provided automatically.

## What's hardened

See `DevSecOps_WP_Lab_Report.pdf` for the full before/after. Short version:

- WP core: 5.0 → 6.8.x (PHP 7.2 → 8.3)
- OS update + removed `wget`, `git`, `openssh-client`
- Apache: `ServerTokens Prod`, `ServerSignature Off`, security headers (CSP, XFO, XCTO, Referrer, Permissions)
- Apache deny on `xmlrpc.php`, `wp-config.php`, dotfiles, `?author=` queries, and PHP under `wp-content/uploads/`
- PHP: `expose_php Off`, `allow_url_fopen/include Off`, `disable_functions` set, HttpOnly + strict-mode cookies
- WordPress: `DISALLOW_FILE_EDIT`, `WP_AUTO_UPDATE_CORE`, deleted `readme.html` / `license.txt` / `wp-config-sample.php`, install with `siteowner` instead of `admin`
- File perms 644/755, `chown -R www-data`, Docker `HEALTHCHECK`

## Published images (set up after first CI run)

| Registry | Image |
|----------|-------|
| GHCR     | `ghcr.io/<owner>/wordpress-hardened:hardened-latest` |
| Docker Hub | `<user>/wordpress-hardened:hardened-latest` |
