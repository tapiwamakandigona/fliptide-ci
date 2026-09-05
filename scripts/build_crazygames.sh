#!/usr/bin/env bash
# Build the CrazyGames upload package (F10): relative base href so it runs from
# any folder, self-hosted renderer (no gstatic), no source-map/.symbols junk.
# Output: docs/crazygames/fliptide-web.zip
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --wasm --no-wasm-dry-run --base-href / -o build/web_cg
sed -i 's#<base href="/">#<base href="./">#' build/web_cg/index.html
find build/web_cg/canvaskit -name '*.symbols' -delete
rm -f build/web_cg/flutter_service_worker.js   # CrazyGames serves from its own CDN; no SW
mkdir -p docs/crazygames
rm -f docs/crazygames/fliptide-web.zip
python3 -c "import shutil; shutil.make_archive('docs/crazygames/fliptide-web', 'zip', 'build/web_cg')"
ls -la docs/crazygames/fliptide-web.zip
python3 -c "import zipfile; z=zipfile.ZipFile('docs/crazygames/fliptide-web.zip'); print(len(z.namelist()), 'files', sum(i.file_size for i in z.infolist())//1024, 'KB uncompressed')"
