# Local kernel patches

Drop-in `.patch` files copied into `pkgs/kernel/build/patches/` at build time by the `patches-linux` Makefile target.  Filenames sort lexicographically; the kernel build script in `pkgs` applies them in that order with `patch -p1`.

## Current series — `0001`..`0003`-net-macb

Three patches addressing the silent TX stall on Raspberry Pi 5 (BCM2712 + RP1 PCIe south bridge, Cadence GEM via macb).  Same series posted to the Linux netdev mailing list as `[RFC PATCH net-next 0/3] net: macb: candidate fixes for silent TX stall on BCM2712/RP1`:

- lore thread: <https://lore.kernel.org/netdev/cover.1777064117.git.lukasz@raczylo.com/T/>
- related issues: [cilium/cilium#43198](https://github.com/cilium/cilium/issues/43198), [Ubuntu launchpad #2133877](https://bugs.launchpad.net/ubuntu/+source/linux-raspi/+bug/2133877)

| Patch | What it does |
|---|---|
| `0001-net-macb-flush-PCIe-posted-write-after-TSTART-doorbell.patch` | Read-back of `NCR` after each `TSTART` write so the doorbell reaches the MAC before the function returns. |
| `0002-net-macb-re-check-ISR-after-IER-re-enable-in-macb_tx_poll.patch` | Reads ISR after IER re-enable in `macb_tx_poll()` — both a direct pending-TCOMP check and a PCIe read barrier for in-flight descriptor TX_USED DMA writes. |
| `0003-net-macb-add-TX-stall-watchdog-to-recover-from-lost-TCOMP.patch` | Per-queue `delayed_work` safety net.  Calls the existing `macb_tx_restart()` if `tx_tail` hasn't advanced for ≥ 1 s while the ring is non-empty. |

### vs. the version posted to netdev

The bodies of patches 1 and 2 are byte-identical between this directory and the netdev submission.  Patch 3 has a 5-line variation in its `macb.h` hunk: this version is anchored against the `raspberrypi/linux` rpi-6.18.y vendor fork (which carries an extra `bool tx_pending` field on `struct macb_queue`); the netdev-submitted version is anchored against mainline (which doesn't).  The semantic change — adding `delayed_work tx_stall_watchdog_work` and `unsigned int tx_stall_last_tail` to `struct macb_queue` — is the same in both.

### License

The patches are derived works of the Linux kernel and inherit its license: **GPL-2.0-only**.  This is consistent with the upstream Linux kernel and supersedes the MIT license that covers the rest of this build harness.

### Author

Lukasz Raczylo <lukasz@raczylo.com>.

## Adding more patches

Just drop a `*.patch` file in this directory.  `patches-linux` copies anything matching `*.patch` into the kernel build's patch dir, and the build script applies them in sorted order.  Use `git format-patch` style or plain unified diffs — both work.

For patches that need to apply against the vendor fork specifically, anchor them on what's there (e.g. the extra `bool tx_pending` field).  For patches that should also be acceptable upstream, keep the diff minimal and avoid vendor-only context.
