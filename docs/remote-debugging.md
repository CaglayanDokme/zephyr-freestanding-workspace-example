# Debugging a board over USB/IP

For when the workspace runs in a dev container on a remote machine, but the board is plugged into
the local machine in front of you.

USB/IP forwards the debug probe itself, so once it is attached the remote machine treats it as a
locally plugged device. `west flash`, `west debug` and the VS Code launch configurations then work
exactly as they do with a local board — nothing in the workspace needs changing.

```
  local machine (board)                             remote machine (workspace + container)
  ST-Link ──USB──> usbipd :3240  <═══ ssh -R ═══>  :3240 ──attach──> /dev/bus/usb/… ──> container
```

Throughout, **local machine** is the one the board is plugged into and **remote machine** is the
one running the dev container. Both must run Linux. Replace `<user>@<remote-host>` and `<busid>`
with your own values.

## One-time setup

### On the local machine

```bash
sudo apt install linux-tools-generic          # provides usbip and usbipd
sudo modprobe usbip-host
```

### On the remote machine

```bash
sudo apt install linux-tools-generic
sudo modprobe vhci-hcd
```

Install the OpenOCD udev rules **on the remote machine**, not on the local one:

```bash
sudo curl -fsSL -o /etc/udev/rules.d/60-openocd.rules \
    https://raw.githubusercontent.com/openocd-org/openocd/master/contrib/60-openocd.rules
sudo udevadm control --reload
```

This is the step people get wrong. With USB/IP the device node appears on the **remote** machine,
so that is where udev decides its ownership. Without the rules the node is `root:root` and the
container's unprivileged user cannot open it.

Check that the rules cover your probe. An older snapshot may only know ST-Link V2:

```bash
lsusb | grep 0483                                        # e.g. 0483:374e for an STLINK-V3
grep 374e /etc/udev/rules.d/60-openocd.rules             # must return a line
```

The rules grant group `plugdev`, matched numerically. Confirm the remote machine's `plugdev` gid
equals the one inside the container:

```bash
getent group plugdev                                     # on the remote machine
docker exec <container> id                               # must list the same gid
```

### Make the tunnel permanent (recommended)

In the local machine's `~/.ssh/config`:

```
Host <remote-host>
    User <user>
    RemoteForward 3240 localhost:3240
    ExitOnForwardFailure yes
    ServerAliveInterval 30
```

`ExitOnForwardFailure` is not optional. Without it, a forward that fails to bind leaves ssh
running as though nothing is wrong, and every later step fails for reasons that point elsewhere.

Note that this applies the forward to *every* connection to that host, so a second concurrent
session will fail to bind. That is intended: it now fails loudly instead of silently.

## Each session

**1. Export the probe (local machine).**

```bash
sudo usbipd -D                        # skip if already running
usbip list -l                         # note the busid, e.g. 3-3
sudo usbip bind -b <busid>
```

**2. Open the tunnel (local machine).** Skip if you added it to `~/.ssh/config` and are already
connected.

```bash
ssh -f -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 \
    -R 3240:localhost:3240 <user>@<remote-host>
```

**3. Attach (remote machine).**

```bash
usbip list -r 127.0.0.1               # should list your probe
sudo usbip attach -r 127.0.0.1 -b <busid>
```

The `127.0.0.1` is correct: from the remote machine's point of view, the local machine's daemon is
at the near end of the tunnel.

## Verify

Work outwards. Each command should succeed before you try the next.

```bash
# On the remote machine
usbip port                            # shows the imported device
lsusb | grep 0483                     # now a normal USB device
ls -l /dev/bus/usb/<bus>/<dev>        # expect: crw-rw---- root plugdev

# In the container
lsusb | grep 0483                     # visible through the /dev bind mount
openocd -f board/st_nucleo_g4.cfg -c "init; targets; shutdown"
```

A working OpenOCD run reports target voltage and detects the CPU, which means real SWD traffic
reached the chip:

```
Info : STLINK V3J9M3 (API v3) VID:PID 0483:374E
Info : Target voltage: 3.300000
Info : [stm32g4x.cpu] Cortex-M4 r0p1 processor detected
```

From there, `west flash --build-dir <build directory> --runner openocd` and the launch
configurations behave as they would with a local board.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `usbip: error: could not connect to 127.0.0.1:3240` on the remote machine | the tunnel's forward never bound | reconnect with `ExitOnForwardFailure=yes`; check `ss -lnt \| grep 3240` on the remote machine |
| Local machine reports `no exportable devices`, and `/sys/bus/usb/devices/<busid>/usbip_status` is `2` | stale attachment from a session that died without detaching | `sudo usbip unbind -b <busid>` then `sudo usbip bind -b <busid>` |
| Node is `root:root`, container cannot open it | udev rules missing on the remote machine, or they predate your probe | install the current rules there, `udevadm control --reload`, then detach and re-attach |
| Container sees the node but OpenOCD reports permission denied | container user not in the remote machine's `plugdev`, or the gids differ | compare `getent group plugdev` on the remote machine with `id` in the container |
| Everything worked, then stopped | the local machine slept or the link dropped, killing the tunnel and the attachment | re-run steps 2 and 3; use `autossh` to survive this |

`usbip port` printing `libusbip: error: fopen` alongside a correct listing is harmless. It only
means the client could not read its own bookkeeping file, so it cannot name the remote host.

## Teardown

```bash
sudo usbip detach -p 00               # on the remote machine, port number from "usbip port"
sudo usbip unbind -b <busid>          # on the local machine, returns the probe to local use
```

Unbinding matters if you want to use the board from the local machine again; while it is bound,
that machine's own tools cannot see it.
