#!/usr/bin/env bash
# Installs the exactly pinned tools of the formal-verification tracks
# (formal/) into .cache/formal, checks every download against its sha256,
# and writes .cache/formal/env.sh, which the track runners read.
#
#   tool/formal/install.sh [tla] [lean] [lean434] [z3] [bend]   (default: all)
#
#   tla      tla2tools.jar, TLC 2.19 (tlaplus v1.7.4)   formal/tla/*/run.sh
#   lean     Lean 4.35.0, Linux x86_64                  formal/lean/run.sh
#   lean434  Lean 4.34.0, Linux x86_64                  formal/bend/run.sh
#   z3       z3-solver, tool/formal/requirements.txt    formal/lean/run.sh (../smt)
#   bend     Bend 2.0.39, Linux x64                     formal/bend/run.sh
#
# It is idempotent: a tool already installed with the pinned checksum is
# kept, so a second run downloads nothing. A download that does not match
# its sha256 is deleted and the run fails; nothing is moved into place.
#
# Environment:
#   FORMAL_CACHE   where to install (default: .cache/formal in the repository)
#   FORMAL_MIRROR  a directory with the release files under their upstream
#                  names (tla2tools.jar, lean-4.35.0-linux.tar.zst,
#                  lean-4.34.0-linux.tar.zst, bend-2.0.39-linux-x64.tar.gz).
#                  They are read from there instead of downloaded, and checked
#                  against the same sha256. For machines without network
#                  access to github.com.
#   PYTHON         the Python for the z3 virtual environment (default python3;
#                  CI uses 3.13, the version requirements.txt is compiled for)
#
# Needs: curl (unless FORMAL_MIRROR), sha256sum, tar, zstd (the Lean
# archives), and Java 11 or later on PATH to run TLC afterwards.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
CACHE="${FORMAL_CACHE:-$REPO/.cache/formal}"
MIRROR="${FORMAL_MIRROR:-}"
PYTHON="${PYTHON:-python3}"

# The pins. Each sha256 was checked against the upstream release file and
# against the copy the tracks were verified with.
TLA_VERSION=1.7.4 # TLC2 Version 2.19 of 08 August 2024 (rev: 5a47802)
TLA_URL="https://github.com/tlaplus/tlaplus/releases/download/v$TLA_VERSION/tla2tools.jar"
TLA_SHA256=936a262061c914694dfd669a543be24573c45d5aa0ff20a8b96b23d01e050e88
LEAN_VERSION=4.35.0
LEAN_SHA256=7289597a44543246c9227b8cae501767e095ce17f6d448b95fc4a8dc97268f6d
LEAN434_VERSION=4.34.0
LEAN434_SHA256=caaa98356098c85dc0fcbbd28e1ec66f39eb6551829972b752ff20e1286b646b
BEND_VERSION=2.0.39
BEND_SHA256=6cf462fd8f70b094a4950ebb709a9c4ffd8f1d1189d9cedf1fd63cd5d041c7ab
REQUIREMENTS="$HERE/requirements.txt"

ALL=(tla lean lean434 z3 bend)
if [[ $# -eq 0 ]]; then
  set -- "${ALL[@]}"
fi
for tool in "$@"; do
  case "$tool" in
    tla | lean | lean434 | z3 | bend) ;;
    *)
      echo "usage: $0 [tla] [lean] [lean434] [z3] [bend]" >&2
      exit 2
      ;;
  esac
done

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

[[ "$(uname -s)-$(uname -m)" == Linux-x86_64 ]] \
  || fail "the pinned archives are for Linux x86_64; this is $(uname -s) $(uname -m)"
command -v sha256sum >/dev/null || fail "sha256sum is needed to verify the downloads"

mkdir -p "$CACHE/stamps"
TMP="$(mktemp -d "$CACHE/tmp.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

sha256_of() { sha256sum "$1" | awk '{print $1}'; }

# fetch NAME URL SHA256 -> prints the path of a verified copy of NAME.
fetch() {
  local name="$1" url="$2" want="$3" file got
  if [[ -n "$MIRROR" ]]; then
    file="$MIRROR/$name"
    [[ -f "$file" ]] || fail "FORMAL_MIRROR has no $name ($file)"
    echo "  from mirror: $file" >&2
  else
    command -v curl >/dev/null || fail "curl is needed to download $url (or set FORMAL_MIRROR)"
    file="$TMP/$name"
    echo "  downloading $url" >&2
    curl --proto '=https' --tlsv1.2 -fsSL --retry 3 --retry-all-errors -o "$file" "$url" \
      || fail "the download failed: $url"
  fi
  got="$(sha256_of "$file")"
  if [[ "$got" != "$want" ]]; then
    [[ -n "$MIRROR" ]] || rm -f "$file"
    fail "sha256 mismatch for $name: expected $want, got $got; not installed"
  fi
  echo "  sha256 ok: $got" >&2
  echo "$file"
}

# installed NAME STAMP -> true when NAME was installed with STAMP.
installed() { [[ -f "$CACHE/stamps/$1" && "$(cat "$CACHE/stamps/$1")" == "$2" ]]; }

# place DIR TARGET NAME STAMP: moves DIR to TARGET and records STAMP.
place() {
  local dir="$1" target="$2" name="$3" stamp="$4"
  rm -f "$CACHE/stamps/$name"
  rm -rf "$target"
  mv "$dir" "$target"
  echo "$stamp" >"$CACHE/stamps/$name"
}

install_tla() {
  local jar="$CACHE/tla2tools.jar" file
  if [[ -f "$jar" && "$(sha256_of "$jar")" == "$TLA_SHA256" ]]; then
    echo "tla: tla2tools.jar $TLA_VERSION already installed"
    return
  fi
  echo "tla: tla2tools.jar $TLA_VERSION (TLC 2.19)"
  file="$(fetch tla2tools.jar "$TLA_URL" "$TLA_SHA256")"
  cp "$file" "$TMP/tla2tools.jar.new"
  mv "$TMP/tla2tools.jar.new" "$jar"
}

# install_lean NAME VERSION SHA256
install_lean() {
  local name="$1" version="$2" sha="$3" archive file target
  archive="lean-$version-linux.tar.zst"
  target="$CACHE/lean-$version-linux"
  if installed "$name" "$sha" && [[ -x "$target/bin/lean" && -x "$target/bin/lake" ]]; then
    echo "$name: Lean $version already installed"
    return
  fi
  command -v zstd >/dev/null || fail "zstd is needed to unpack $archive (apt install zstd)"
  echo "$name: Lean $version"
  file="$(fetch "$archive" "https://github.com/leanprover/lean4/releases/download/v$version/$archive" "$sha")"
  mkdir -p "$TMP/$name"
  tar --no-same-owner --zstd -xf "$file" -C "$TMP/$name"
  [[ -x "$TMP/$name/lean-$version-linux/bin/lean" ]] || fail "$archive has no lean-$version-linux/bin/lean"
  rm -f "$TMP/$archive"
  place "$TMP/$name/lean-$version-linux" "$target" "$name" "$sha"
  "$target/bin/lean" --version
}

install_z3() {
  local venv="$CACHE/venv" stamp
  stamp="$(sha256_of "$REQUIREMENTS") $("$PYTHON" -c 'import platform; print(platform.python_version())')"
  if installed z3 "$stamp" && "$venv/bin/python" -c 'import z3' 2>/dev/null; then
    echo "z3: z3-solver already installed ($("$venv/bin/python" -c 'import z3; print(z3.get_full_version())'))"
    return
  fi
  echo "z3: z3-solver from tool/formal/requirements.txt (--require-hashes), $("$PYTHON" --version)"
  "$PYTHON" -m venv "$TMP/venv"
  "$TMP/venv/bin/python" -m pip install --quiet --disable-pip-version-check --no-deps \
    --require-hashes -r "$REQUIREMENTS"
  # A venv records its own path: build it in place, not in TMP.
  rm -rf "$TMP/venv"
  rm -f "$CACHE/stamps/z3"
  rm -rf "$venv"
  "$PYTHON" -m venv "$venv"
  "$venv/bin/python" -m pip install --quiet --disable-pip-version-check --no-deps \
    --require-hashes -r "$REQUIREMENTS"
  echo "$stamp" >"$CACHE/stamps/z3"
  echo "  z3 $("$venv/bin/python" -c 'import z3; print(z3.get_full_version())')"
}

install_bend() {
  local archive="bend-$BEND_VERSION-linux-x64.tar.gz" target="$CACHE/bend-$BEND_VERSION" file
  if installed bend "$BEND_SHA256" && [[ -x "$target/bin/bend" ]]; then
    echo "bend: Bend $BEND_VERSION already installed"
    return
  fi
  echo "bend: Bend $BEND_VERSION"
  file="$(fetch "$archive" "https://github.com/bendlang/bend/releases/download/v$BEND_VERSION/$archive" "$BEND_SHA256")"
  mkdir -p "$TMP/bend"
  # The archive is made on macOS; GNU tar warns about its extended headers.
  tar --no-same-owner --warning=no-unknown-keyword -xzf "$file" -C "$TMP/bend"
  [[ -x "$TMP/bend/bend/bin/bend" && -d "$TMP/bend/bend/bend2" ]] || fail "$archive has no bend/bin/bend"
  place "$TMP/bend/bend" "$target" bend "$BEND_SHA256"
  echo "  $(BEND_NO_TELEMETRY=1 "$target/bin/bend" version | head -1)"
}

for tool in "$@"; do
  case "$tool" in
    tla) install_tla ;;
    lean) install_lean lean "$LEAN_VERSION" "$LEAN_SHA256" ;;
    lean434) install_lean lean434 "$LEAN434_VERSION" "$LEAN434_SHA256" ;;
    z3) install_z3 ;;
    bend) install_bend ;;
  esac
done

# env.sh names every tool present in the cache. A variable already set wins,
# so TLA2TOOLS=... make verify still points a track at another copy.
ENV="$CACHE/env.sh"
{
  echo "# Written by tool/formal/install.sh. Source it (bash) to use the pinned tools;"
  echo "# the formal/*/run.sh runners read it themselves. A variable already set wins."
  # shellcheck disable=SC2016 # written literally, expanded when env.sh is sourced
  echo 'FORMAL_CACHE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"'
  if [[ -f "$CACHE/tla2tools.jar" ]]; then
    # shellcheck disable=SC2016
    echo 'export TLA2TOOLS="${TLA2TOOLS:-$FORMAL_CACHE/tla2tools.jar}"'
  fi
  if [[ -x "$CACHE/lean-$LEAN_VERSION-linux/bin/lean" ]]; then
    echo "export LEAN_HOME=\"\${LEAN_HOME:-\$FORMAL_CACHE/lean-$LEAN_VERSION-linux}\""
  fi
  if [[ -x "$CACHE/lean-$LEAN434_VERSION-linux/bin/lean" ]]; then
    echo "export LEAN434_HOME=\"\${LEAN434_HOME:-\$FORMAL_CACHE/lean-$LEAN434_VERSION-linux}\""
  fi
  if [[ -x "$CACHE/venv/bin/python" ]]; then
    # shellcheck disable=SC2016
    echo 'export Z3_PYTHON="${Z3_PYTHON:-$FORMAL_CACHE/venv/bin/python}"'
  fi
  if [[ -x "$CACHE/bend-$BEND_VERSION/bin/bend" ]]; then
    echo "export BEND=\"\${BEND:-\$FORMAL_CACHE/bend-$BEND_VERSION/bin/bend}\""
    echo "export BEND_NO_TELEMETRY=1"
  fi
} >"$TMP/env.sh"
mv "$TMP/env.sh" "$ENV"
echo "wrote $ENV:"
grep '^export' "$ENV" | sed 's/^/  /'
