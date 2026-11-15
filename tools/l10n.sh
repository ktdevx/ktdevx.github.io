#!/usr/bin/env bash
# 日本語の原本（content/ja）と翻訳ファイル（po/<lang>/）から、各言語の記事を作る。
#
#   tools/l10n.sh update [<lang>...]  原本から .pot を作り、po/<lang>/ の .po を更新する（なければ作る）
#   tools/l10n.sh build  [<lang>...]  .po から content/<lang>/ を作り直す
#   tools/l10n.sh status [<lang>...]  ページごとの翻訳の状況を表示する
#
# <lang> を省略すると L10N_LANGS のすべての言語を対象にする。
# monde の実行ファイルは環境変数 MONDE で指定できる（既定は PATH 上の monde）。
#
# build は、訳し終えた（fuzzy・未翻訳・missing が 0 の）ページだけを出力する。
# 訳し終えていないページも原文混じりで確認したいときは L10N_ALLOW_PARTIAL=1 を指定する。
# 訳文が文書の構造を変えるおそれがあるという monde の警告が出たときは失敗する。
set -euo pipefail

L10N_LANGS=(en zh-cn)
SOURCE_LANG=ja
FRONT_MATTER_KEYS=title
MONDE=${MONDE:-monde}

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

die() { echo "l10n: $*" >&2; exit 1; }

# Hugo の言語コードから PO の Language ヘッダの値へ
po_lang() {
  case $1 in
    zh-cn) echo zh_CN ;;
    *) echo "$1" ;;
  esac
}

# content/ja/blog/foo/index.md -> blog/foo、content/ja/blog/_index.md -> blog/_index
page_id() {
  local rel=${1#content/$SOURCE_LANG/}
  rel=${rel%.md}
  rel=${rel%/index}
  echo "$rel"
}

sources() {
  find "content/$SOURCE_LANG" -name '*.md' -type f | LC_ALL=C sort
}

check_lang() {
  local l
  for l in "${L10N_LANGS[@]}"; do
    [[ $l == "$1" ]] && return 0
  done
  die "unknown language: $1 (known: ${L10N_LANGS[*]})"
}

select_langs() {
  if (($# == 0)); then
    langs=("${L10N_LANGS[@]}")
  else
    local l
    for l in "$@"; do check_lang "$l"; done
    langs=("$@")
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cmd_update() {
  select_langs "$@"
  local src id pot po lang
  local -A live=()
  while IFS= read -r src; do
    id=$(page_id "$src")
    pot=$tmp/$(echo "$id" | tr / _).pot
    "$MONDE" extract -q --front-matter-keys "$FRONT_MATTER_KEYS" -o "$pot" "$src"
    for lang in "${langs[@]}"; do
      po=po/$lang/$id.po
      live[$po]=1
      mkdir -p "$(dirname "$po")"
      if [[ -f $po ]]; then
        cp -- "$po" "$tmp/prev.po"
        "$MONDE" update -q -o "$po" "$pot" "$po"
        # monde は POT-Creation-Date を毎回書き換えるので、ほかに変化がなければ元に戻す
        if cmp -s <(grep -v '^"POT-Creation-Date: ' "$tmp/prev.po") \
                  <(grep -v '^"POT-Creation-Date: ' "$po"); then
          cp -- "$tmp/prev.po" "$po"
        fi
      else
        "$MONDE" init -q -l "$(po_lang "$lang")" -o "$po" "$pot"
        echo "l10n: created $po"
      fi
    done
  done < <(sources)

  # 原本が消えたページの .po を消す
  for lang in "${langs[@]}"; do
    [[ -d po/$lang ]] || continue
    while IFS= read -r po; do
      if [[ -z ${live[$po]:-} ]]; then
        rm -- "$po"
        echo "l10n: removed $po (source page no longer exists)"
      fi
    done < <(find "po/$lang" -name '*.po' -type f)
    find "po/$lang" -type d -empty -delete
  done
}

# translate を実行し、統計の行を変数 stats に入れる。警告があれば warn=1。
run_translate() {
  local src=$1 po=$2 out=$3 log=$tmp/translate.log
  "$MONDE" translate --front-matter-keys "$FRONT_MATTER_KEYS" -o "$out" "$src" "$po" 2>"$log"
  stats=$(grep '^translate:' "$log" || true)
  warn=0
  if grep -q ': warning: ' "$log"; then
    grep ': warning: ' "$log" | sed "s|^|$po: |" >&2
    warn=1
  fi
}

# stats が「訳し終えた」を表すか
is_complete() {
  [[ $stats == *"no translatable messages"* ]] && return 0
  [[ $stats =~ ([0-9]+)\ fuzzy,\ ([0-9]+)\ untranslated,\ ([0-9]+)\ missing ]] || return 1
  ((BASH_REMATCH[1] == 0 && BASH_REMATCH[2] == 0 && BASH_REMATCH[3] == 0))
}

cmd_build() {
  select_langs "$@"
  local src id po out lang built skipped failed=0
  for lang in "${langs[@]}"; do
    rm -rf "content/$lang"
    built=0 skipped=0
    while IFS= read -r src; do
      id=$(page_id "$src")
      po=po/$lang/$id.po
      out=content/$lang/${src#content/$SOURCE_LANG/}
      if [[ ! -f $po ]]; then
        skipped=$((skipped + 1))
        continue
      fi
      mkdir -p "$(dirname "$out")"
      run_translate "$src" "$po" "$out"
      ((warn)) && failed=1
      if is_complete || [[ ${L10N_ALLOW_PARTIAL:-} == 1 ]]; then
        built=$((built + 1))
      else
        rm -f -- "$out"
        echo "l10n: skipped $po (${stats#translate: })"
        skipped=$((skipped + 1))
      fi
    done < <(sources)
    find "content/$lang" -type d -empty -delete 2>/dev/null || true
    echo "l10n: $lang: $built pages built, $skipped pages skipped"
  done
  ((failed == 0)) || die "some translations may change the document structure (see warnings above)"
}

cmd_status() {
  select_langs "$@"
  local src id po lang
  for lang in "${langs[@]}"; do
    while IFS= read -r src; do
      id=$(page_id "$src")
      po=po/$lang/$id.po
      if [[ ! -f $po ]]; then
        printf '%-6s %-60s no .po\n' "$lang" "$id"
        continue
      fi
      run_translate "$src" "$po" "$tmp/out.md"
      if is_complete; then
        printf '%-6s %-60s done\n' "$lang" "$id"
      else
        printf '%-6s %-60s %s\n' "$lang" "$id" "${stats#translate: }"
      fi
    done < <(sources)
  done
}

(($# >= 1)) || die "usage: $0 {update|build|status} [<lang>...]"
command -v "$MONDE" >/dev/null || die "monde not found (set MONDE or add it to PATH)"
sub=$1
shift
case $sub in
  update) cmd_update "$@" ;;
  build) cmd_build "$@" ;;
  status) cmd_status "$@" ;;
  *) die "unknown command: $sub" ;;
esac
