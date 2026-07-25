#!/bin/bash
set -euxo pipefail

# jimtcl 0.76's bundled autosetup config.guess/config.sub predate aarch64
# hosts; refresh every copy in the tree from gnuconfig.
find . -name config.sub -exec cp -f "$BUILD_PREFIX/share/gnuconfig/config.sub" {} \;
find . -name config.guess -exec cp -f "$BUILD_PREFIX/share/gnuconfig/config.guess" {} \;

# PKG_CONFIG_LIBDIR *replaces* the default search path, taking /usr out of
# consideration entirely: libusb/libftdi must come from the host prefix.
export PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig:$PREFIX/share/pkgconfig"

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

# udev rules for real boards; make install does not ship them and consumers
# have no source checkout to copy them from.
install -D -m 644 contrib/60-openocd.rules "$PREFIX/share/openocd/contrib/60-openocd.rules"
