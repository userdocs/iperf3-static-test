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

echo "==> Modifying openssl.cygport for v$TARGET_VERSION (Fully Static Build)..."

# 1. Bump the version
sed -i "s/^VERSION=.*/VERSION=$TARGET_VERSION/" openssl.cygport

# 2. Adjust MAKEOPTS for available cores
CPU_CORES=$(nproc)
sed -i "s|.*MAKEOPTS+=.*|MAKEOPTS=\"-j$CPU_CORES\"|g" openssl.cygport

# 3. Switch prefix to /usr/local and configuration to fully static
# sed -i 's|--prefix=/usr|--prefix=/usr/local|g' openssl.cygport
sed -i 's/shared Cygwin/no-shared no-dso no-comp Cygwin/' openssl.cygport

# 4. Remove logic for dynamic libraries and static library deletion
sed -i '/rm \${D}\/usr\/lib\/lib{crypto,ssl}\.a/d' openssl.cygport
sed -i '/chmod 0755 \${D}\/usr\/bin\/\*\.dll/d' openssl.cygport
sed -i '/# install_runtime_libs mistakenly uses 0644/d' openssl.cygport

# 5. Fix hardcoded /usr/bin for the new /usr/local prefix
# sed -i 's|\${D}/usr/bin|\${D}/usr/local/bin|g' openssl.cygport

# 6. Skip doc/man page generation (cyginstall runs full make install)
sed -i 's|^\s*cyginstall\s*$|    make DESTDIR="${D}" install_sw install_ssldirs|' openssl.cygport

echo "==> Starting cygport static build pipeline with $CPU_CORES cores..."
cygport openssl.cygport fetch prep compile install

echo "==> Automatically installing files to /..."
cp -a openssl-*/inst/* /

echo "==> Success! OpenSSL built and installed locally."
