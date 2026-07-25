# riscv-openocd (conda package)

Open On-Chip Debugger built from [riscv/riscv-openocd](https://github.com/riscv/riscv-openocd)
at commit `1449af5bd` ("0.10.0+dev", 2020-02-20) — the exact pin the
GreenWaves GAP SDK 5.21.7 Makefile uses — packaged with
[rattler-build](https://rattler.build) for `linux-64`, `linux-aarch64`,
`osx-arm64` and `osx-64`, published to
[prefix.dev/eliacereda](https://prefix.dev/channels/eliacereda).

Pure upstream source, zero patches, configured as the SDK does
(`--enable-jtag_dpi --disable-werror`). All GAP9-specific logic is Tcl inside
the SDK tree (`utils/openocd_tools/`), not compiled code.

**Why this exact 2020 commit:** the SDK's Tcl scripts use pre-0.12 deprecated
command spellings (`interface ftdi`, `ftdi_vid_pid`, `ftdi_layout_init`,
`adapter_khz`, `jtag_reset`) that modern OpenOCD removed. Do not upgrade the
pin without also patching the SDK Tcl — which is unverifiable without
hardware.

## Using with Pixi

```toml
[workspace]
channels = ["https://prefix.dev/eliacereda", "conda-forge"]
platforms = ["linux-64", "linux-aarch64", "osx-arm64", "osx-64"]

[dependencies]
riscv-openocd = "*"
```

Or globally: `pixi global install -c https://prefix.dev/eliacereda riscv-openocd`.

### Version numbering

Upstream identifies itself as `0.10.0+dev`; conda forbids `+`, so the package
version is `<base>.<commit-date>`: `0.10.0.20200220`. Recipe-only respins bump
`build.number`.

### How the source tree is assembled

```
$SRC_DIR/                     riscv/riscv-openocd @ 1449af5bd
├── jimtcl/                   msteveb/jimtcl @ 51f65c6d (= v0.76), the only
│                             git submodule at the pin, checked out by
│                             rattler-build so ./bootstrap runs "nosubmodule"
│                             (no network during the build)
└── src/jtag/drivers/
    └── libjaylink/           vendored in-tree at this commit (not a submodule)
```

## Building locally

```sh
pixi run build     # rattler-build build --recipe recipe/recipe.yaml
```

Builds in a few minutes. On Linux, uses conda-forge gcc 13 + sysroot 2.28
(see `recipe/variants.yaml`) so the only system requirement is
`__glibc >=2.28`, Pixi's default solve baseline; on macOS, conda-forge
clang 18 with deployment target 11.0. `libusb`/`libftdi` come from
conda-forge as host dependencies and stay as runtime dependencies of the
package.

Notable recipe details:

- jimtcl 0.76's bundled `autosetup/config.{guess,sub}` predate aarch64;
  `build.sh` refreshes every copy in the tree from the `gnuconfig` package.
- The FTDI (MPSSE) and J-Link adapter drivers are enabled by silent
  autodetection; `build.sh` greps configure's summary and hard-fails if
  either dropped out.
- Normal conda prefix relocation is used (the binary bakes in
  `$PREFIX/share/openocd/scripts` and rpaths to conda's libusb/libftdi).

## udev rules (real boards)

The package ships upstream's rules at
`$PREFIX/share/openocd/contrib/60-openocd.rules` (a plain `make install` does
not install them, and consumers have no source checkout):

```sh
sudo cp "$CONDA_PREFIX/share/openocd/contrib/60-openocd.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules && sudo udevadm trigger
```

## CI and publishing

GitHub Actions builds all four platforms natively (`ubuntu-24.04`,
`ubuntu-24.04-arm`, `macos-15`, `macos-15-intel`). On failure the tail of the build log is posted as a
commit comment. Uploads to prefix.dev are tag-gated and use OIDC trusted
publishing (no API key).

Release flow: bump `context.version`/`context.openocd_rev` (or
`build.number` for recipe-only respins), tag `v<version>` (e.g.
`v0.10.0.20200220`), push the tag.
