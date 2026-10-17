#!/usr/bin/env bash
# Downloads archives into ~/Downloads/indirilen/ (under $HOME/indirilen).
# Does not extract, install, or run anything.
# Archives with a published checksum are verified with sha256sum.
# Tailscale, YunoHost, YOURLS, Dub, and Astro have no checksum check.
# Dub tracks the current main branch, so its archive changes over time.
set -euo pipefail

BASE="${HOME}/indirilen"
TMP_DIR="$(mktemp -d)"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

download() {
    local url="$1"
    local dest="$2"
    curl -fL --retry 3 --retry-delay 2 -o "$dest" "$url"
}

verify_sha256() {
    local file="$1"
    local expected="$2"
    printf '%s  %s\n' "$expected" "$file" | sha256sum -c -
}

echo "==> Downloading Tailscale 1.102.4..."
mkdir -p "$BASE/tailscale"
download \
    "https://pkgs.tailscale.com/stable/tailscale_1.102.4_amd64.tgz" \
    "$BASE/tailscale/tailscale_1.102.4_amd64.tgz"

echo "==> Downloading YunoHost 12.1.41.2..."
mkdir -p "$BASE/yunohost"
download \
    "https://codeload.github.com/YunoHost/yunohost/tar.gz/refs/tags/debian/12.1.41.2" \
    "$BASE/yunohost/yunohost-12.1.41.2.tar.gz"

echo "==> Downloading YOURLS 1.10.6..."
mkdir -p "$BASE/yourls"
download \
    "https://github.com/YOURLS/YOURLS/archive/refs/tags/1.10.6.tar.gz" \
    "$BASE/yourls/YOURLS-1.10.6.tar.gz"

echo "==> Downloading Ansible Core 2.21.4..."
mkdir -p "$BASE/ansible"
download \
    "https://files.pythonhosted.org/packages/df/72/2152230f254bd9c6b892f95d6d291a96fd09b632ce01c6b406eda8c5cd75/ansible_core-2.21.4.tar.gz" \
    "$BASE/ansible/ansible_core-2.21.4.tar.gz"
verify_sha256 "$BASE/ansible/ansible_core-2.21.4.tar.gz" \
    "81a9329f4f12cfa5008dcab5d1bf23ae69b7effc08c0f00048ab2461147ae95a"

echo "==> Downloading Ghost 6.65.0..."
mkdir -p "$BASE/ghost"
download \
    "https://github.com/TryGhost/Ghost/releases/download/v6.65.0/ghost-6.65.0.tgz" \
    "$BASE/ghost/ghost-6.65.0.tgz"
verify_sha256 "$BASE/ghost/ghost-6.65.0.tgz" \
    "13318d07a2c44a1ab96fb49bfb45855f53028ff7fbee6428d050ba73fa72b9e4"

echo "==> Downloading Dub (main)..."
mkdir -p "$BASE/dub"
download \
    "https://github.com/dubinc/dub/archive/refs/heads/main.tar.gz" \
    "$BASE/dub/dub-main.tar.gz"

echo "==> Downloading LinkStack 4.8.6..."
mkdir -p "$BASE/linkstack"
download \
    "https://github.com/LinkStackOrg/LinkStack/releases/download/v4.8.6/linkstack.zip" \
    "$BASE/linkstack/linkstack-4.8.6.zip"
verify_sha256 "$BASE/linkstack/linkstack-4.8.6.zip" \
    "1de6e53c24889b110fd2ddf5d63aadab434dadd99b8137679bbaa0a6644393ce"

echo "==> Downloading Astro 7.3.5..."
mkdir -p "$BASE/astro"
download \
    "https://github.com/withastro/astro/archive/refs/tags/astro@7.3.5.tar.gz" \
    "$BASE/astro/astro-7.3.5.tar.gz"

echo "==> Downloading Wiki.js 2.5.315..."
mkdir -p "$BASE/wiki-js"
download \
    "https://github.com/requarks/wiki/releases/download/v2.5.315/wiki-js.tar.gz" \
    "$BASE/wiki-js/wiki-js-2.5.315.tar.gz"
verify_sha256 "$BASE/wiki-js/wiki-js-2.5.315.tar.gz" \
    "34cb53223ff2b00be3cc98cc8190535322b4fcc0a7af1d114c1225143e63f5e4"

echo "==> Downloading Uptime Kuma 2.5.5..."
mkdir -p "$BASE/uptime-kuma"
download \
    "https://github.com/louislam/uptime-kuma/releases/download/2.5.5/dist.tar.gz" \
    "$BASE/uptime-kuma/uptime-kuma-2.5.5-dist.tar.gz"
verify_sha256 "$BASE/uptime-kuma/uptime-kuma-2.5.5-dist.tar.gz" \
    "913e308587dc241993a714befb949bea417f22d000032828dc1b5e6645cb5d4b"

echo "==> Downloading Gotify 3.1.1..."
mkdir -p "$BASE/gotify"
download \
    "https://github.com/gotify/server/releases/download/v3.1.1/gotify-linux-amd64.zip" \
    "$BASE/gotify/gotify-linux-amd64-3.1.1.zip"
verify_sha256 "$BASE/gotify/gotify-linux-amd64-3.1.1.zip" \
    "d452faad071981d191d5c95f70d0f9520dc2ef2336b2b03055e12cfabfbae2d2"

echo
echo "All archives downloaded to: $BASE"
