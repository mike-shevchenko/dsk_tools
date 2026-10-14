#!/bin/bash

# Builds dsk_tools, the library with fddconv, aim2hfe and the tests, from the source tree that
# holds this script into the sibling directory of its name and "-build": with the MSVC of the
# newest Visual Studio on Windows (MSYS2 or Git Bash), with the system compiler elsewhere.
#
# Usage: build.sh [cmake-option...]
#
# The options go to the CMake configuration, as -DCMAKE_BUILD_TYPE=Debug. BUILD_DIR=... builds
# elsewhere. The tests run by "ctest --test-dir <build directory>".

set -o pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# The compiler needs the environment of vcvars64.bat, which only cmd takes in, so a batch file
# in the build directory configures and builds; Visual Studio brings CMake and Ninja too.
build_msvc() {
  local src_dir="$1"
  local build_dir="$2"
  shift 2
  local vswhere="/c/Program Files (x86)/Microsoft Visual Studio/Installer/vswhere.exe"
  local vs_dir
  vs_dir="$("${vswhere}" -latest -property installationPath)" && [[ -n "${vs_dir}" ]] \
      || fail "No Visual Studio found."
  local bat="${build_dir}/build.bat"
  cat > "${bat}" <<EOF
@set "PATH=$(cygpath -w "$(dirname "${vswhere}")");%PATH%"
@call "$(cygpath -w "${vs_dir}/VC/Auxiliary/Build/vcvars64.bat")" >nul || exit /b 1
cmake -S "$(cygpath -w "${src_dir}")" -B "$(cygpath -w "${build_dir}")" -G Ninja $* || exit /b 1
cmake --build "$(cygpath -w "${build_dir}")" -j $(nproc) || exit /b 1
EOF
  # cmd.exe itself: MSYS2's cmd is a wrapper that needs COMSPEC, which a login shell lacks
  cmd.exe //c "$(cygpath -w "${bat}")" || fail "The build failed."
}

build_native() {
  local src_dir="$1"
  local build_dir="$2"
  shift 2
  command -v cmake > /dev/null || fail "No cmake found."
  local -a generator=()
  if command -v ninja > /dev/null; then
    generator=(-G Ninja)
  fi
  cmake -S "${src_dir}" -B "${build_dir}" "${generator[@]}" "$@" \
      || fail "The configuration failed."
  cmake --build "${build_dir}" -j "$(nproc)" || fail "The build failed."
}

main() {
  local src_dir
  src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" \
      || fail "Cannot locate the source tree."
  local build_dir="${BUILD_DIR:-${src_dir}-build}"
  mkdir -p "${build_dir}" || fail "Cannot create ${build_dir}/."
  local -a options=(-DCMAKE_BUILD_TYPE=Release -DENABLE_DSK_TESTS=ON "$@")

  echo "Building ${src_dir}/ in ${build_dir}/"
  case "$(uname -o)" in
    Msys|Cygwin) build_msvc "${src_dir}" "${build_dir}" "${options[@]}" ;;
    *) build_native "${src_dir}" "${build_dir}" "${options[@]}" ;;
  esac
}

main "$@"
