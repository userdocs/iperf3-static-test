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
sed -i 's/\<shared\>/no-shared no-dso no-comp/g' openssl.cygport
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
sed -i 's|usr/lib/libcrypto\.a|# &|' openssl.cygport 
sed -i 's|usr/lib/libssl\.a|# &|' openssl.cygport
sed -i 's|usr/lib/cmake/\*|usr/local/lib/cmake/*|g' openssl.cygport
sed -i 's|usr/lib/pkgconfig/\*|usr/local/lib/pkgconfig/*|g' openssl.cygport
sed -i 's|usr/share/man/man3/|usr/local/share/man/man3/|g' openssl.cygport

# 7. Update main openssl binary path target to /usr/local/bin
sed -i 's|usr/bin/openssl\.exe|usr/local/bin/openssl.exe|g' openssl.cygport

# 8. Fix Perl package contents paths to match /usr/local layout
sed -i 's|usr/bin/CA\.pl|usr/local/bin/CA.pl|g' openssl.cygport
sed -i 's|usr/bin/c_rehash|usr/local/bin/c_rehash|g' openssl.cygport
sed -i 's|usr/bin/tsget|usr/local/bin/tsget|g' openssl.cygport
sed -i 's|usr/share/man/man1/|usr/local/share/man/man1/|g' openssl.cygport

# 9. Fix src_install() moving Perl scripts to /usr/local/bin instead of /usr/bin
sed -i 's|\$\{D\}/usr/bin/|\$\{D\}/usr/local/bin/|g' openssl.cygport

# 10. Ensure static libraries are not deleted in src_install() and clean up any old dll chmod commands
sed -i 's|rm \${D}/usr/lib/lib{crypto,ssl}\.a|# &|' openssl.cygport
sed -i '/chmod 0755 \${D}\/usr\/bin\/\*\.dll/d' openssl.cygport

# 11. Fix man paths in openssl_CONTENTS to match /usr/local/share/man
sed -i 's|usr/share/man/man\[157\]|usr/local/share/man/man[157]|g' openssl.cygport

echo "==> Starting cygport /usr/local static build pipeline with $CPU_CORES cores..."
cygport openssl.cygport fetch prep compile install package

echo "==> Automatically installing packages to /usr/local..."
tar -xvf libssl-devel-*.tar.xz -C /
tar -xvf openssl-*.tar.xz -C /
tar -xvf openssl-perl-*.tar.xz -C /

echo "==> Success! OpenSSL built, packaged, and installed locally to /usr/local."