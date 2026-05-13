# Raspberry Pi Talos Builder

This repository builds custom Talos Linux images for the **Raspberry Pi**. It patches the Kernel and Talos build process to use the Linux Kernel source provided by [raspberrypi/linux](https://github.com/raspberrypi/linux).

## What's not working?

* Booting from USB: USB is only available once LINUX has booted up but not in U-Boot.

## How to use?

Each release contains disk images and installer images for the Raspberry Pi platform.

### Examples

Initial:

```bash
# Raspberry Pi 5/ CM5
xz -d metal-arm64-rpi.raw.xz
dd if=metal-arm64-rpi.raw of=<disk> bs=4M status=progress
```

Upgrade:

```bash
# Raspberry Pi 5 / CM5
talosctl upgrade \
  --nodes <node IP> \
  --image ghcr.io/talos-rpi5/installer:<version>
```

## Building

### Local build

If you'd like to make modifications, it is possible to create your own build.

```bash
# Ensure you have docker and docker buildx with a cross platform builder installed and enabled.
sudo pacman -S docker-buildx
docker buildx create --name nubuilder
docker buildx use nubuilder
docker buildx inspect --bootstrap
# And to build locally you'll need a registry
docker run -d -p 5000 --restart always --name local registry:3
# Full local pipeline for Raspberry Pi 5
dotenv -f talos.env run make pi5
```

Or step by step:

```bash
# Clone dependencies and apply patches
dotenv -f talos.env run make checkouts patches

# Build the Linux Kernel (can take a while)
dotenv -f talos.env run make kernel

# Build the overlay (Pi5 only — Pi4 uses the stock siderolabs overlay)
dotenv -f talos.env run make overlay

# Build the installer and disk image
dotenv -f talos.env run make installer
```

### Extensions support

Talos [system extensions](https://www.talos.dev/latest/talos-guides/configuration/system-extensions/) can be baked into the installer image at build time.

**Makefile variables:**

```makefile
EXTENSIONS ?=
EXTENSION_ARGS = $(foreach ext,$(EXTENSIONS),--system-extension-image $(ext))
```

`EXTENSIONS` is a space-separated list of `image:tag@sha256:digest` references passed as a make variable at build time — no Makefile edits needed. Internally, the Makefile expands each entry into a `--system-extension-image` flag and passes them all to the Talos imager.

**Adding extensions to the local build:**

Simply add the package url and version to the talos.env file, you can look up the urls and versions here.

https://github.com/siderolabs/extensions#extension-catalog

The workflow resolves the digest for each at build time and assembles the full `EXTENSIONS` string automatically.

Pass multiple extensions as a space-separated string inside the quotes.

## License

See [LICENSE](LICENSE).
