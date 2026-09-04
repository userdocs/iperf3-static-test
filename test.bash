#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

TARGET_VERSION="3.5.8"
REPO_DIR="openssl"

echo "==> Cloning Cygwin OpenSSL repository (with submodules)..."
if [ ! -d "$REPO_DIR" ]; then
    git clone --recurse-submodules https://cygwin.com/git/cygwin-packages/openssl.git "$REPO_DIR"
else
    echo "Directory $REPO_DIR already exists. Pulling latest changes..."
    cd "$REPO_DIR"
    git checkout -- .
    git pull
    git submodule update --init --recursive
    cd ..
fi

cd "$REPO_DIR"

echo "==> Cleaning any previous builds..."
cygport openssl.cygport clean || true

echo "==> Modifying openssl.cygport for v$TARGET_VERSION and static libraries..."

# 1. Bump the version
sed -i "s/^VERSION=.*/VERSION=$TARGET_VERSION/" openssl.cygport

# 2. Add static libraries (*.a) to libssl_devel_CONTENTS
# Checks if they are missing, then injects them right after libssl.dll.a
if ! grep -q "libcrypto\.a" openssl.cygport; then
    sed -i 's|usr/lib/libssl\.dll\.a|usr/lib/libssl.dll.a\n  usr/lib/libcrypto.a\n  usr/lib/libssl.a|' openssl.cygport
fi

# 3. Prevent the install phase from deleting static libraries
# Targets the exact rm command in src_install() and comments it out
sed -i 's|^[[:space:]]*rm \${D}/usr/lib/lib{crypto,ssl}\.a|    # &|' openssl.cygport

echo "==> Starting cygport build pipeline (fetch, prep, compile, install, package)..."
cygport openssl.cygport fetch prep compile install package

echo "==> Success! Your packages (including static libs) are located in the $PWD directory."