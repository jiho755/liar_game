#!/usr/bin/env bash
# 구글 플레이 스토어용 www 폴더(store/www)를 만든다. 여러 번 실행해도 결과가 같다(idempotent).
#  - 루트 index.html 은 건드리지 않고 읽기만 한다.
#  - (a) 상단의 자동 업데이트 로더(<script> ... jiho755.github.io ...)를 제거
#  - (b) Google Fonts <link> 를 지우고 store/www/fonts 의 로컬 woff2 @font-face 로 교체
#  - 폰트는 npm 패키지 @fontsource/jua, @fontsource/noto-sans-kr (SIL OFL 1.1) 에서 가져온다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SRC="$REPO_ROOT/index.html"
OUT_DIR="$SCRIPT_DIR/www"
FONT_DIR="$OUT_DIR/fonts"
FONTSOURCE_JUA_VERSION="${FONTSOURCE_JUA_VERSION:-5.3.0}"
FONTSOURCE_NOTO_VERSION="${FONTSOURCE_NOTO_VERSION:-5.3.1}"

[ -f "$SRC" ] || { echo "index.html 을 찾을 수 없음: $SRC" >&2; exit 1; }
command -v node >/dev/null || { echo "node 가 필요합니다" >&2; exit 1; }

NOTO_WEIGHTS="400 500 700 900"
FONT_FILES=()
for w in $NOTO_WEIGHTS; do
  FONT_FILES+=("noto-sans-kr-korean-$w-normal.woff2" "noto-sans-kr-latin-$w-normal.woff2")
done
FONT_FILES+=("jua-korean-400-normal.woff2" "jua-latin-400-normal.woff2")

mkdir -p "$FONT_DIR"

need_fonts=0
for f in "${FONT_FILES[@]}"; do
  [ -s "$FONT_DIR/$f" ] || need_fonts=1
done

if [ "$need_fonts" = 1 ]; then
  echo "[prepare] 폰트 woff2 내려받는 중 (npm @fontsource)"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  (
    cd "$TMP"
    npm init -y >/dev/null
    npm i --no-audit --no-fund --silent \
      "@fontsource/jua@$FONTSOURCE_JUA_VERSION" \
      "@fontsource/noto-sans-kr@$FONTSOURCE_NOTO_VERSION"
  )
  for f in "${FONT_FILES[@]}"; do
    case "$f" in
      jua-*) pkg=jua ;;
      *)     pkg=noto-sans-kr ;;
    esac
    cp "$TMP/node_modules/@fontsource/$pkg/files/$f" "$FONT_DIR/$f"
  done
  cp "$TMP/node_modules/@fontsource/jua/LICENSE" "$FONT_DIR/LICENSE-jua-OFL.txt"
  cp "$TMP/node_modules/@fontsource/noto-sans-kr/LICENSE" "$FONT_DIR/LICENSE-noto-sans-kr-OFL.txt"
else
  echo "[prepare] 폰트가 이미 있음 -> 다운로드 생략"
fi

for f in "${FONT_FILES[@]}"; do
  [ -s "$FONT_DIR/$f" ] || { echo "폰트 파일 누락: $f" >&2; exit 1; }
done

echo "[prepare] index.html 변환"
node - "$SRC" "$OUT_DIR/index.html" <<'NODE'
const fs = require('fs');
const [src, out] = process.argv.slice(2);
let html = fs.readFileSync(src, 'utf8');

// (a) 자동 업데이트 로더 제거: <head> 안에서 jiho755.github.io 를 포함한 첫 <script> 블록만 제거
const headEnd = html.indexOf('</head>');
const scriptRe = /<script>[\s\S]*?<\/script>\s*/g;
let removed = 0;
const head = html.slice(0, headEnd).replace(scriptRe, (m) => {
  if (removed === 0 && m.includes('jiho755.github.io') && m.includes('location.replace')) {
    removed++;
    return '';
  }
  return m;
});
if (removed !== 1) { console.error('자동 업데이트 로더 블록을 찾지 못했습니다'); process.exit(1); }
html = head + html.slice(headEnd);

// (b) Google Fonts <link> 전부 제거 (preconnect 포함)
const linkRe = /<link\b[^>]*(?:fonts\.googleapis\.com|fonts\.gstatic\.com)[^>]*>\s*/g;
const linkCount = (html.match(linkRe) || []).length;
if (linkCount !== 4) { console.error('Google Fonts <link> 4개를 예상했지만 ' + linkCount + '개 발견'); process.exit(1); }
html = html.replace(linkRe, '');

// 로컬 @font-face (이름은 기존 CSS 와 동일: 'Jua', 'Noto Sans KR')
const LATIN = 'U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+2000-206F,U+2074,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD';
const face = (family, weight, file, range) =>
  '@font-face{font-family:\'' + family + '\';font-style:normal;font-display:swap;font-weight:' + weight +
  ';src:url(fonts/' + file + ') format(\'woff2\')' + (range ? ';unicode-range:' + range : '') + '}';
const faces = [];
for (const w of [400, 500, 700, 900]) {
  faces.push(face('Noto Sans KR', w, 'noto-sans-kr-korean-' + w + '-normal.woff2'));
  faces.push(face('Noto Sans KR', w, 'noto-sans-kr-latin-' + w + '-normal.woff2', LATIN));
}
faces.push(face('Jua', 400, 'jua-korean-400-normal.woff2'));
faces.push(face('Jua', 400, 'jua-latin-400-normal.woff2', LATIN));
const block = '<style>\n/* 로컬 폰트 (@fontsource, SIL OFL 1.1) - 스토어 빌드용 */\n' + faces.join('\n') + '\n</style>\n';

// <title> 바로 뒤, 원래 폰트 링크가 있던 자리 근처에 삽입
const titleEnd = html.indexOf('</title>');
if (titleEnd < 0) { console.error('<title> 을 찾지 못했습니다'); process.exit(1); }
const ins = titleEnd + '</title>'.length;
html = html.slice(0, ins) + '\n' + block + html.slice(ins).replace(/^\n/, '');

// 최종 검증
for (const bad of ['googleapis.com', 'gstatic.com', 'jiho755.github.io']) {
  if (html.includes(bad)) { console.error('변환 후에도 남아 있음: ' + bad); process.exit(1); }
}
fs.writeFileSync(out, html);
console.log('[prepare] 작성: ' + out + ' (' + html.length + ' bytes)');
NODE

echo "[prepare] 완료: $OUT_DIR"
