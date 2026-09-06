#!/usr/bin/env bash

HOME="$(pwd)"
with_openssl="${1:-no}"
if [[ ${2} =~ ^/ ]]; then
	cygwin_path="${2}"
else
	cygwin_path="${HOME}/${2:-cygwin}"
fi
source_repo="${3:-https://github.com/esnet/iperf.git}"
source_branch="${4:-master}"

printf '\n%b\n' " \e[93m\U25cf\e[0m With openssl = ${with_openssl}"
printf '%b\n' " \e[93m\U25cf\e[0m Build path = ${HOME}"
printf '%b\n' " \e[93m\U25cf\e[0m Cygwin path = ${cygwin_path}"

printf '\n%b\n' " \e[93m\U25cf\e[0m parameters = ${*}"

printf '\n%b\n' " \e[93m\U25cf\e[0m cygwin_path = ${cygwin_path}"
printf '\n%b\n' " \e[93m\U25cf\e[0m source_repo = ${source_repo}"
printf '\n%b\n' " \e[93m\U25cf\e[0m source_branch = ${source_branch}"

if [[ ${with_openssl} == 'yes' ]]; then
	# openssl via cygport
	REPO_DIR="$HOME/openssl"

	echo "==> Cloning Cygwin OpenSSL repository (with submodules)..."
	if [ ! -d "$REPO_DIR" ]; then
		git clone --recurse-submodules https://cygwin.com/git/cygwin-packages/openssl.git "$REPO_DIR"
		pushd "$REPO_DIR" || exit 1
	else
		echo "Directory $REPO_DIR already exists. Pulling latest changes..."
		pushd "$REPO_DIR" || exit 1
		git checkout -- .
		git pull
		git submodule update --init --recursive
	fi

	echo "==> Cleaning any previous builds..."

	# 1. Bootstrapping
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

	# openssl via github source + configure + make
	# printf '\n%b\n' " \e[94m\U25cf\e[0m Downloading zlib"
	# curl -sLO "https://github.com/userdocs/qbt-workflow-files/releases/latest/download/zlib.tar.xz"

	# openssl_version="$(git ls-remote -q -t --refs "https://github.com/openssl/openssl.git" | awk '/openssl-3\.5\./{sub("refs/tags/", "");sub("(.*)(v6|rc|alpha|beta)(.*)", ""); print $2 }' | awk '!/^$/' | sort -rV | head -n1)"

	# printf '\n%b\n' " \e[94m\U25cf\e[0m Downloading openssl ${openssl_version}"
	# curl -sLO "https://github.com/openssl/openssl/releases/download/${openssl_version}/${openssl_version}.tar.gz"

	# printf '\n%b\n' " \e[94m\U25cf\e[0m Extracting zlib"
	# rm -rf "zlib" && mkdir -p "zlib"
	# tar xf "zlib.tar.xz" --strip-components=1 -C "zlib"

	# printf '\n%b\n' " \e[94m\U25cf\e[0m Extracting openssl"
	# rm -rf "openssl" && mkdir -p "openssl"
	# tar xf "${openssl_version}.tar.gz" --strip-components=1 -C "openssl"

	# printf '\n%b\n\n' " \e[94m\U25cf\e[0m Configuring zlib"
	# pushd "zlib" || exit 1
	# ./configure --prefix="${cygwin_path}" --static

	# printf '\n%b\n\n' " \e[94m\U25cf\e[0m Building with zlib"
	# make -j"$(nproc)"
	# make install

	# popd || exit 1

	# printf '\n%b\n\n' " \e[94m\U25cf\e[0m Configuring openssl"
	# pushd "${HOME}/openssl" || exit 1
	# ./config --prefix="${cygwin_path}" --libdir=lib threads no-shared no-dso no-comp zlib \
	# 	--with-zlib-lib="${cygwin_path}/lib" --with-zlib-include="${cygwin_path}/include"

	# printf '\n%b\n\n' " \e[94m\U25cf\e[0m Building openssl"
	# make -j"$(nproc)"
	# make install_sw

	popd || exit 1
fi

printf '\n%b\n\n' " \e[94m\U25cf\e[0m Cloning iperf3 git repo"

[[ -d "$HOME/iperf3_build" ]] && rm -rf "$HOME/iperf3_build"
printf '%b\n\n' " \e[94m\U25cf\e[0m git clone --no-tags --single-branch --branch ${source_branch} --shallow-submodules --recurse-submodules -j$(nproc) --depth 1 ${source_repo} $HOME/iperf3_build"
git clone --no-tags --single-branch --branch "${source_branch}" --shallow-submodules --recurse-submodules -j"$(nproc)" --depth 1 "${source_repo}" "$HOME/iperf3_build"
cd "$HOME/iperf3_build" || exit 1

printf '%b\n\n' " \e[94m\U25cf\e[0m Repo Info"

git remote show origin

printf '\n%b\n' " \e[92m\U25cf\e[0m Setting iperf3 version to file iperf3_version"
sed -rn 's|(.*)\[(.*)],\[https://github.com/esnet/iperf],(.*)|\2|p' configure.ac >"$HOME/iperf3_version"

printf '\n%b\n\n' " \e[94m\U25cf\e[0m Bootstrapping iperf3"

./bootstrap.sh

printf '\n%b\n\n' " \e[94m\U25cf\e[0m Configuring iperf3"
if [[ ${with_openssl} == 'yes' ]]; then
	# AX_CHECK_OPENSSL prefers pkg-config over the OPENSSL_LIBS env var, dropping any
	# override, so the extra lib has to ride in via LIBS instead (it gets appended
	# after OPENSSL_LIBS by the macro: LIBS="$OPENSSL_LIBS $LIBS").
	# static openssl 3.5+ pulls in the windows cert store (winstore_store.c), which needs crypt32
	# static openssl was built with zlib support, so the static libz.a needs to ride along too
	LIBS="-lcrypt32 -lz" ./configure --disable-shared --enable-static --enable-static-bin --prefix="$HOME/iperf3"
else
	./configure --disable-shared --enable-static --enable-static-bin --prefix="$HOME/iperf3"
fi

cat config.log

printf '\n%b\n\n' " \e[94m\U25cf\e[0m make"
make -j"$(nproc)"

printf '\n%b\n\n' " \e[94m\U25cf\e[0m make install"
[[ -d "$HOME/iperf3" ]] && rm -rf "$HOME/iperf3"
make install

if [[ -d "$HOME/iperf3/bin" ]]; then
	printf '\n%b\n' " \e[94m\U25cf\e[0m Copy dll dependencies"
	[[ -f "${cygwin_path}/bin/cygwin1.dll" ]] && cp -f "${cygwin_path}/bin/cygwin1.dll" "$HOME/iperf3/bin"
	printf '\n%b\n' " \e[92m\U25cf\e[0m Copied the dll dependencies"
fi
