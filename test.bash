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

# 3. Switch build configuration to fully static and target /usr/local
sed -i 's/shared Cygwin/no-shared no-dso no-comp Cygwin/' openssl.cygport
sed -i 's|--prefix=/usr|--prefix=/usr/local|g' openssl.cygport

# 4. Remove libssl3 from PKG_NAMES and clean up any orphaned runtime blocks if present
sed -i 's/libssl3//g' openssl.cygport
sed -i '/^libssl3_/d' openssl.cygport
sed -i '/^_CATEGORY=/d' openssl.cygport
sed -i '/^_SUMMARY=/d' openssl.cygport
sed -i '/^_REQUIRES=/d' openssl.cygport
sed -i '/^_CONTENTS=/,/^"/d' openssl.cygport

# 5. Remove non-existent .dll.a files from libssl_devel_CONTENTS since no-shared is enabled
sed -i '/libcrypto\.dll\.a/d' openssl.cygport
sed -i '/libssl\.dll\.a/d' openssl.cygport

# 6. Adjust devel package contents paths to match /usr/local layout
sed -i 's|usr/include/openssl/|usr/local/include/openssl/\n  usr/local/lib/libcrypto.a\n  usr/local/lib/libssl.a|' openssl.cygport

# Fix other paths in devel package to point to usr/local
sed -i 's|usr/lib/cmake/\*|usr/local/lib/cmake/*|g' openssl.cygport
sed -i 's|usr/lib/pkgconfig/\*|usr/local/lib/pkgconfig/*|g' openssl.cygport
sed -i 's|usr/share/man/man3/|usr/local/share/man/man3/|g' openssl.cygport

# 7. Update main openssl binary path target to /usr/local/bin if applicable
sed -i 's|usr/bin/openssl\.exe|usr/local/bin/openssl.exe|g' openssl.cygport

# 8. Ensure static libraries are not deleted in src_install() and clean up any old dll chmod commands
sed -i 's|rm \${D}/usr/lib/lib{crypto,ssl}\.a|# &|' openssl.cygport
sed -i '/chmod 0755 \${D}\/usr\/bin\/\*\.dll/d' openssl.cygport
sed -i '/# install_runtime_libs mistakenly uses 0644/d' openssl.cygport

# 9. Skip doc/man page generation (pod2man) - cyginstall runs the full "make install",
# which is the slow part under Cygwin's fork/exec overhead. install_sw/install_ssldirs only.
sed -i 's|^\s*cyginstall\s*$|    make DESTDIR="${D}" install_sw install_ssldirs|' openssl.cygport

# 10. Man pages are no longer generated, so drop their now-dangling CONTENTS entries
# (tar treats these as required paths and fails the packaging step if they're missing).
sed -i '/usr\/share\/man\/man\[157\]/d' openssl.cygport
sed -i '/usr\/local\/share\/man\/man3\//d' openssl.cygport
sed -i '/usr\/share\/man\/man1\/\(CA\.pl\|c_rehash\|tsget\)\.1\*/d' openssl.cygport

# 11. Drop the openssl-perl subpackage - a Fedora patch skips installing CA.pl/tsget/c_rehash
# without docs (which we intentionally skip), so this subpackage can never be populated.
sed -i 's/openssl-perl//g' openssl.cygport
sed -i '/^openssl_perl_SUMMARY=/d' openssl.cygport
sed -i '/^openssl_perl_REQUIRES=/d' openssl.cygport
sed -i '/^openssl_perl_CONTENTS=/,/^"/d' openssl.cygport

echo "==> Starting cygport /usr/local static build pipeline with $CPU_CORES cores..."
cygport openssl.cygport fetch prep compile install package

echo "==> Automatically installing packages to /usr/local..."
tar -xvf libssl-devel-*.tar.xz -C /
tar -xvf openssl-*.tar.xz -C /

echo "==> Success! OpenSSL built, packaged, and installed locally to /usr/local."
