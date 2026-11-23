#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
cd "$PROJECT_DIR"
PORT="${PORT:-3000}"
STATIC_DIR="$PROJECT_DIR/dist"
DEPLOYMENT_FILE="/home/runner/work/_temp/omgithub-web/deployment-output.json"

run() { /usr/bin/time -p "$@"; }

if [[ -f package.json ]]; then
  run npm install --no-audit --no-fund
  if run node -e 'const p=require("./package.json");process.exit(p.scripts?.build?0:1)'; then
    run npm run build
  fi
fi

run mkdir -p "$STATIC_DIR"
if [[ -f "$PROJECT_DIR/app/index.html" ]]; then
  run cp -a "$PROJECT_DIR/app/." "$STATIC_DIR/"
elif [[ -f "$PROJECT_DIR/index.html" && ! -f "$STATIC_DIR/index.html" ]]; then
  run cp "$PROJECT_DIR/index.html" "$STATIC_DIR/index.html"
fi
[[ -f "$STATIC_DIR/index.html" ]] || { echo "No built static index.html in $STATIC_DIR" >&2; exit 1; }
run mkdir -p "$(dirname "$DEPLOYMENT_FILE")"
run node - "$PROJECT_DIR" "$STATIC_DIR" "$DEPLOYMENT_FILE" <<'NODE'
const fs = require('node:fs');
const path = require('node:path');
const [project, directory, output] = process.argv.slice(2);
fs.writeFileSync(output, JSON.stringify({ project: path.resolve(project), directory: path.resolve(directory) }));
NODE

export PORT STATIC_DIR
run node - "$STATIC_DIR" "$PORT" <<'NODE'
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(process.argv[2]);
const port = Number(process.argv[3]);
const types = { '.html':'text/html; charset=utf-8', '.css':'text/css; charset=utf-8', '.js':'text/javascript; charset=utf-8', '.json':'application/json; charset=utf-8', '.svg':'image/svg+xml', '.png':'image/png', '.jpg':'image/jpeg', '.ico':'image/x-icon' };
http.createServer((req, res) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname); }
  catch { res.writeHead(400).end('Bad request'); return; }
  let file = path.resolve(root, '.' + pathname);
  if (file !== root && !file.startsWith(root + path.sep)) { res.writeHead(403).end('Forbidden'); return; }
  try { if (fs.statSync(file).isDirectory()) file = path.join(file, 'index.html'); }
  catch {}
  fs.stat(file, (err, stat) => {
    if (err || !stat.isFile()) { res.writeHead(404, { 'Content-Type':'text/plain; charset=utf-8' }).end('Not found'); return; }
    res.writeHead(200, { 'Content-Type':types[path.extname(file).toLowerCase()] || 'application/octet-stream', 'Content-Length':stat.size, 'Cache-Control':'no-cache' });
    if (req.method === 'HEAD') res.end(); else fs.createReadStream(file).pipe(res);
  });
}).listen(port, '0.0.0.0', () => console.log(`SOUND CAR static server listening on 0.0.0.0:${port} (${root})`));
NODE
