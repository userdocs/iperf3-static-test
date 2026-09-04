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

echo "==> Modifying openssl.cygport for v$TARGET_VERSION (/usr/local Fully Static Build)..."

# 1. Bump the version
sed -i "s/^VERSION=.*/VERSION=$TARGET_VERSION/" openssl.cygport

# 2. Dynamically set and uncomment MAKEOPTS using the host's actual core count
CPU_CORES=$(nproc)
sed -i 's|.*MAKEOPTS+=.*|MAKEOPTS+=" -j'"$CPU_CORES"'"|g' openssl.cygport

# 3. Switch build configuration to fully static (no-shared, no-dso, no-comp)
sed -i 's/\<shared\>/no-shared no-dso no-comp/g' openssl.cygport

# 4. Safely update any path starting with 'usr/' to 'usr/local/' (handles prefix, contents, and install moves)
sed -i 's|\busr/|usr/local/|g' openssl.cygport

# 5. Remove libssl3 from PKG_NAMES and clean up any orphaned runtime blocks if present
sed -i 's/libssl3//g' openssl.cygport
sed -i '/^libssl3_/d' openssl.cygport
sed -i '/^_CATEGORY=/d' openssl.cygport
sed -i '/^_SUMMARY=/d' openssl.cygport
sed -i '/^_REQUIRES=/d' openssl.cygport
sed -i '/^_CONTENTS=/,/^"/d' openssl.cygport

# 6. Remove non-existent dynamic import libs (.dll.a) and ensure static libraries (.a) are present in devel contents
sed -i '/libcrypto\.dll\.a/d' openssl.cygport
sed -i '/libssl\.dll\.a/d' openssl.cygport
if ! grep -q "libcrypto\.a" openssl.cygport; then
    sed -i 's|usr/local/include/openssl/|usr/local/include/openssl/\n  usr/local/lib/libcrypto.a\n  usr/local/lib/libssl.a|' openssl.cygport
fi

# 7. Ensure static libraries are not deleted in src_install() and clean up old dll chmod commands
sed -i 's|rm \${D}/usr/lib/lib{crypto,ssl}\.a|# &|' openssl.cygport
sed -i '/chmod 0755 \${D}\/usr\/local\/bin\/\*\.dll/d' openssl.cygport

echo "==> Starting cygport /usr/local static build pipeline with $CPU_CORES cores..."
cygport openssl.cygport fetch prep compile install package

echo "==> Automatically installing packages to /usr/local..."
tar -xvf libssl-devel-*.tar.xz -C /
tar -xvf openssl-*.tar.xz -C /
tar -xvf openssl-perl-*.tar.xz -C /

echo "==> Success! OpenSSL built, packaged, and installed locally to /usr/local."