#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

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

echo "==> Modifying openssl.cygport (Fully Static Build)..."

# 2. Adjust MAKEOPTS for available cores
CPU_CORES=$(nproc)
sed -i "s|.*MAKEOPTS+=.*|MAKEOPTS=\"-j$CPU_CORES\"|g" openssl.cygport

# 3. Switch configuration to fully static
sed -i 's/shared Cygwin/no-shared no-dso no-comp Cygwin/' openssl.cygport

# 4. Remove logic for dynamic libraries and static library deletion
# shellcheck disable=SC2016
sed -i '/rm \${D}\/usr\/lib\/lib{crypto,ssl}\.a/d' openssl.cygport

# 5. Skip doc/man page generation (cyginstall runs full make install)
# shellcheck disable=SC2016
sed -i 's|^\s*cyginstall\s*$|    make DESTDIR="${D}" install_sw install_ssldirs|' openssl.cygport

echo "==> Starting cygport static build pipeline with $CPU_CORES cores..."
cygport openssl.cygport fetch prep compile install

echo "==> Automatically installing files to /..."
cp -a openssl-*/inst/* /

echo "==> Success! OpenSSL built and installed locally."
