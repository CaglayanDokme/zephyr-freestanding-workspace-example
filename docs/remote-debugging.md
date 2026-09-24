# Debugging a board plugged into another machine

For when the workspace runs in a dev container on a remote machine, but the board is plugged into
the local machine in front of you, typically a Windows laptop.

Throughout, **local machine** is the one the board is plugged into and **remote machine** is the
one running the dev container. Replace `<user>@<remote-host>` with your own values.

```
  local machine (board)                              remote machine (workspace + container)
  ST-Link ──USB──> openocd :3333  <═══ ssh -R ═══>  :3333 <──── gdb (container, host network)
```

OpenOCD runs next to the board, so the many small USB transactions a debug session generates stay
on that machine. GDB stays in the container with the ELF and the sources, and speaks OpenOCD's GDB
remote protocol through an SSH reverse forward, one network round trip per GDB packet. The forward
lands on the remote machine's loopback interface; the container reaches it because
[.devcontainer/devcontainer.json](../.devcontainer/devcontainer.json) starts it with
`--network=host`.

Flashing goes through GDB's `load` on the same connection. `west flash` and `west debug` cannot use
this path: their runner starts its own OpenOCD in the container and needs the probe there.

## One-time setup

**On the local machine**, install OpenOCD 0.12 or newer. On Windows the
[xPack OpenOCD](https://xpack-dev-tools.github.io/openocd-xpack/) archive needs no installer:
extract it and run `bin\openocd.exe` from there; it finds its own `scripts` directory. Windows 11
installs the ST-Link's WinUSB driver from Windows Update on first plug-in; if OpenOCD reports
`open failed`, install ST's driver package STSW-LINK009. On Linux, install the distribution's
`openocd` and the udev rules from the [README](../README.md#probe-access).

Then add the forward to the remote machine's entry in `~/.ssh/config` (`%USERPROFILE%\.ssh\config`
on Windows):

```
Host <remote-host>
    User <user>
    RemoteForward 3333 127.0.0.1:3333
    ServerAliveInterval 30
```

VS Code Remote-SSH reads the same file, so its own connection to the host carries the forward and
the only thing left to start by hand each session is OpenOCD. Two details are deliberate. The
target is `127.0.0.1`, not `localhost`: OpenOCD listens on IPv4 only, and on Windows `localhost`
resolves to the IPv6 loopback first, which ssh then fails to connect to; from the container that
looks like every connection closing after two seconds with no data. And there is no
`ExitOnForwardFailure`: the forward applies to every connection to that host, so a second VS Code
window cannot bind 3333 and logs a warning, whereas `ExitOnForwardFailure yes` would stop that
window from connecting at all.

**In the workspace**, the container has to share the remote machine's network namespace. That is
set in `devcontainer.json`, but a container created before the setting was added keeps its bridge
network: run **Dev Containers: Rebuild Container** once. Afterwards `ip addr` in a container
terminal lists the remote machine's interfaces, `docker0` among them, instead of a lone `eth0` on
`172.17.x.x`.

## Each session

**1. Start OpenOCD (local machine).** Leave it running; it serves GDB on `localhost:3333`. The
`-rtos auto` makes OpenOCD look for the thread list a Debug preset exports
(`CONFIG_DEBUG_THREAD_INFO=y` from `debug.conf`), so the debugger shows Zephyr's threads; with a
Release ELF nothing is found and OpenOCD carries on without them.

```
openocd -f board/st_nucleo_g4.cfg -c "stm32g4x.cpu configure -rtos auto"
```

**2. Connect (local machine).** Open the remote in VS Code Remote-SSH as usual; the forward comes
with it. Without the `~/.ssh/config` entry, open the tunnel in a terminal instead and leave it open
for the session. Windows 11 ships this `ssh`:

```
ssh -N -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -R 3333:127.0.0.1:3333 <user>@<remote-host>
```

**3. Debug (VS Code).** Run **Debug (Nucleo G474RE, probe on your local machine via SSH)**. It
builds the active CMake preset, loads its ELF into flash, resets, and stops at `main`. To flash
without debugging, run the task **Flash (Nucleo G474RE, probe on your local machine via SSH)** from
Terminal > Run Task; it is this command:

```bash
/opt/toolchains/zephyr-sdk/gnu/arm-zephyr-eabi/bin/arm-zephyr-eabi-gdb -batch \
    -ex "target extended-remote localhost:3333" -ex load -ex "monitor reset run" \
    build/nucleo_g474re/zephyr/zephyr.elf
```

## Verify

```bash
# On the remote machine
ss -lnt | grep 3333                   # the forward: 127.0.0.1:3333 LISTEN

# In the container
ip addr | grep -c docker0             # 1 with host networking; 0 means rebuild the container
/opt/toolchains/zephyr-sdk/gnu/arm-zephyr-eabi/bin/arm-zephyr-eabi-gdb -batch \
    -ex "target extended-remote localhost:3333" -ex "monitor targets"
```

The last command makes OpenOCD on the local machine print `accepting 'gdb' connection`, and GDB
prints OpenOCD's target table with `stm32g4x.cpu` in state `halted`.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `localhost:3333: Connection refused` in the container | no forward, or the container is still on the bridge network | `ss -lnt \| grep 3333` on the remote machine must show a listener; `ip addr` in the container must show `docker0`, otherwise rebuild the container |
| `remote port forwarding failed for listen port 3333` in the terminal or in the Remote-SSH output log | port 3333 on the remote machine is taken: a stale forward, a second VS Code window, or `west debug` running in a host-networked container | `ss -lntp \| grep 3333` there and stop the holder |
| Every connection to `localhost:3333` closes after ~2 s with no data, and OpenOCD never logs `accepting 'gdb' connection` | the forward's target is `localhost`, which the Windows ssh client resolves to IPv6 first | spell it `127.0.0.1`, as above |
| OpenOCD on the local machine exits with `open failed` or `claim interface failed` | another program holds the probe: a second OpenOCD, STM32CubeIDE, STM32CubeProgrammer | close it, replug the board |
| CALL STACK shows a single thread and RTOS Views is empty | the ELF comes from a Release preset, or OpenOCD was started without `-rtos auto` | build a Debug preset; restart OpenOCD with the command in step 1 |

## Why not USB/IP

Forwarding the probe itself with USB/IP was tried first. It keeps `west flash` working, but every
ST-Link command becomes a network round trip: measured through a laptop-to-VM link, one 32-bit
memory read took ~0.4 s, OpenOCD needed ~10 s to start and up to ~11 s to answer GDB's first
packet, and loading a 17 KB image took ~50 s, with GDB kept alive only by `set remotetimeout 60`.
The procedure is in this file's history: `git show 2715de4:docs/remote-debugging.md`.
