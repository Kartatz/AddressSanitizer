#!/bin/bash

set -eu

declare -r install_prefix='/tmp/libsanitizer'

declare -r workdir="${PWD}"

declare -r gcc_tarball='/tmp/gcc.tar.gz'
declare -r gcc_directory='/tmp/gcc-master'

declare -r libsanitizer_directory="${gcc_directory}/libsanitizer"

declare -r optflags='-w -O2'
declare -r linkflags='-Xlinker -s'

declare -r max_jobs='40'

declare -ra asan_libraries=(
	'libasan'
	'libhwasan'
	'liblsan'
	'libtsan'
	'libubsan'
)

if ! [ -f "${gcc_tarball}" ]; then
	curl \
		--url 'https://github.com/gcc-mirror/gcc/archive/refs/heads/master.tar.gz' \
		--retry '30' \
		--retry-all-errors \
		--retry-delay '0' \
		--retry-max-time '0' \
		--location \
		--silent \
		--output "${gcc_tarball}"
	
	tar \
		--directory="$(dirname "${gcc_directory}")" \
		--extract \
		--file="${gcc_tarball}"
	
	patch --directory="${gcc_directory}" --strip='1' --input="${workdir}/patches/0001-Fix-libsanitizer-build.patch"
fi

[ -d "${libsanitizer_directory}/build" ] || mkdir "${libsanitizer_directory}/build"

cd "${libsanitizer_directory}/build"

mkdir --parent "${libsanitizer_directory}/libstdc++-v3/src"

declare file="$(${CROSS_COMPILE_TRIPLET}-g++ --print-file-name='libstdc++.la')"
cp "${file}" "${libsanitizer_directory}/libstdc++-v3/src"

../configure \
	--disable-multilib \
	--with-gcc-major-version-only \
	--host="${CROSS_COMPILE_TRIPLET}" \
	--prefix="${install_prefix}" \
	CFLAGS="${optflags}" \
	CXXFLAGS="${optflags}" \
	LDFLAGS="${linkflags}"

make --jobs="${max_jobs}"
make install

if [ -d "${install_prefix}/lib64" ]; then
	mv "${install_prefix}/lib64/"* "${install_prefix}/lib"
	rmdir "${install_prefix}/lib64"
fi

