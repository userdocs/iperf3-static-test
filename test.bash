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

# 2. Dynamically set and uncomment MAKEOPTS using the host's actual core count
CPU_CORES=$(nproc)
sed -i 's|.*MAKEOPTS+=.*|MAKEOPTS+=" -j'"$CPU_CORES"'"|g' openssl.cygport

# 3. Switch build configuration to fully static
sed -i 's/shared Cygwin/no-shared no-dso no-comp Cygwin/' openssl.cygport

# 4. Ensure static libraries are not deleted in src_install() and clean up any old dll chmod commands
sed -i 's|rm \${D}/usr/lib/lib{crypto,ssl}\.a|# &|' openssl.cygport
sed -i '/chmod 0755 \${D}\/usr\/bin\/\*\.dll/d' openssl.cygport
sed -i '/# install_runtime_libs mistakenly uses 0644/d' openssl.cygport

# 5. Skip doc/man page generation (pod2man) - cyginstall runs the full "make install",
# which is the slow part under Cygwin's fork/exec overhead. install_sw/install_ssldirs only.
sed -i 's|^\s*cyginstall\s*$|    make DESTDIR="${D}" install_sw install_ssldirs|' openssl.cygport

echo "==> Starting cygport static build pipeline with $CPU_CORES cores..."
cygport openssl.cygport fetch prep compile install

echo "==> Automatically installing files to /..."
cp -a openssl-*/inst/* /

echo "==> Success! OpenSSL built and installed locally."
