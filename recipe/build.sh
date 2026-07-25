#!/bin/bash
set -euxo pipefail

# jimtcl 0.76's bundled autosetup config.guess/config.sub predate aarch64
# hosts; refresh every copy in the tree from gnuconfig.
find . -name config.sub -exec cp -f "$BUILD_PREFIX/share/gnuconfig/config.sub" {} \;
find . -name config.guess -exec cp -f "$BUILD_PREFIX/share/gnuconfig/config.guess" {} \;

# PKG_CONFIG_LIBDIR *replaces* the default search path, taking /usr out of
# consideration entirely: libusb/libftdi must come from the host prefix.
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"

# clang >= 16 makes implicit function declarations (and friends) hard errors
# by default; downgrade them back to warnings for these 2020-era sources.
# --disable-werror does not cover these: they are default errors, not -Werror.
if [[ "$(uname)" == "Darwin" ]]; then
  export CFLAGS="${CFLAGS:-} -Wno-error=implicit-function-declaration -Wno-error=implicit-int -Wno-error=int-conversion"
  # libjaylink's autogen.sh hardcodes the Homebrew name glibtoolize on
  # Darwin; conda's libtool ships plain libtoolize.
  ln -sf "$BUILD_PREFIX/bin/libtoolize" "$BUILD_PREFIX/bin/glibtoolize"
fi

# "nosubmodule": jimtcl is provided as a pinned rattler-build source; the
# vendored libjaylink's autogen.sh still runs. No network.
./bootstrap nosubmodule

./configure --enable-jtag_dpi --disable-werror --prefix="$PREFIX" 2>&1 | tee configure.log

# The adapter drivers the GAP SDK relies on are enabled by silent
# autodetection — hard-fail the build if either dropped out of the summary.
grep -E "MPSSE mode of FTDI based devices.*yes" configure.log
grep -E "SEGGER J-Link Programmer.*yes" configure.log

make -j"$CPU_COUNT"
make install

# udev rules for real boards (Linux consumers); make install does not ship
# them and consumers have no source checkout to copy them from. Shipped on
# all platforms for a uniform layout. (No `install -D`: BSD install on macOS
# lacks it.)
mkdir -p "$PREFIX/share/openocd/contrib"
install -m 644 contrib/60-openocd.rules "$PREFIX/share/openocd/contrib/60-openocd.rules"
