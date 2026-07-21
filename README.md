# ssh-askpass-zigtk

[![SEGV 
LICENSE](https://img.shields.io/static/v1?label=SEGV%20LICENSE&message=1.0&labelColor=0060A8&color=ffffff)](https://xn--gckvb8fzb.com/segv/)

[<img src="https://xn--gckvb8fzb.com/images/chatroom.png"
width="275">](https://xn--gckvb8fzb.com/contact/)

A GTK4 `SSH_ASKPASS` helper written in Zig. OpenSSH runs it to prompt for a
passphrase or a yes/no confirmation when no controlling terminal is available,
for example under `ssh-add` from a desktop session or a `git` pull triggered by
a service. The prompt text is passed on the command line and the passphrase, if
any, is written to stdout.

The behavior follows `contrib/gnome-ssh-askpass` from OpenSSH, so the same
environment variables select the dialog and recolor it. Unlike the reference, it
uses no X11 features of GTK4, as the bindings in `src/gtk.zig` never name a
symbol from `gdk/gdkx.h` or `X11/Xlib.h`, so the binary builds and runs on a
GTK4 that was compiled without X11, such as Gentoo with the global `-X` use
flag.

## Build

You need Zig 0.16 and GTK4 with its development files. The build links GTK
through `pkg-config`.

```sh
zig build
```

It builds natively on Linux and the BSDs. Nothing in the source is OS-specific,
so FreeBSD, OpenBSD, and NetBSD build it the same way once Zig 0.16 and GTK4 are
installed.

## Install

Each tagged release includes prebuilt Linux binaries, one per CPU architecture
(x86_64, aarch64, armv7, riscv64, powerpc64le, i386, loongarch64, and s390x).
They link the system GTK4 at runtime, so GTK4 still has to be installed.
Download the archive for your architecture from the releases page, check it
against `SHA256SUMS`, and copy the binary onto your `PATH`.

```sh
tar -xzf ssh-askpass-zigtk-v1.0.0-x86_64-linux-gnu.tar.gz
install -Dm755 ssh-askpass-zigtk-v1.0.0-x86_64-linux-gnu/ssh-askpass-zigtk ~/.local/bin/ssh-askpass-zigtk
```

To build from source instead, compile in release mode and copy the binary out.

```sh
zig build -Doptimize=ReleaseSafe
install -Dm755 zig-out/bin/ssh-askpass-zigtk ~/.local/bin/ssh-askpass-zigtk
```

For all users, install it system-wide.

```sh
sudo install -Dm755 zig-out/bin/ssh-askpass-zigtk /usr/local/bin/ssh-askpass-zigtk
```

## Setup

OpenSSH runs the program named in `SSH_ASKPASS` whenever it needs a passphrase
and has no terminal to read from, provided a graphical session is present,
namely `DISPLAY` or `WAYLAND_DISPLAY` is set. On a normal desktop, X11 or
Wayland, pointing `SSH_ASKPASS` at the binary is enough.

`SSH_ASKPASS_REQUIRE`, from OpenSSH 8.4 onward, gives finer control:

- `prefer`: use the dialog even when a terminal is available, as long as a
  graphical session is present.
- `force`: use the dialog always, even when neither `DISPLAY` nor
  `WAYLAND_DISPLAY` is set.
- `never`: never use the dialog.

Set it to `prefer` if you want the dialog for `ssh-add` and `ssh` run from a
terminal too, not only for programs started without one.

For a terminal, put the variables in `~/.profile` or your shell's startup file:

```sh
export SSH_ASKPASS=~/.local/bin/ssh-askpass-zigtk
export SSH_ASKPASS_REQUIRE=prefer
```

For a systemd user session, put them in
`~/.config/environment.d/ssh-askpass.conf` instead. Use `KEY=VALUE` lines with
no `export`:

```
SSH_ASKPASS=/home/you/.local/bin/ssh-askpass-zigtk
SSH_ASKPASS_REQUIRE=prefer
```

> **Note:** `environment.d` doesn't expand `~` or run a shell, so give an
> absolute path.

Log out and back in so the session reads the new values, then add a key:

```sh
ssh-add < /dev/null
```

With stdin from `/dev/null`, `ssh-add` has no terminal to read from, so OpenSSH
uses the dialog. `git`, `rsync`, and other tools that call `ssh` use it the same
way when a key needs a passphrase and no terminal is available.

To check the dialog on its own, run the binary with a prompt as its argument:

```sh
ssh-askpass-zigtk "Unlock key id_ed25519:"
```

With no argument the prompt is `Enter your OpenSSH passphrase:`.

## Prompt types

The `SSH_ASKPASS_PROMPT` environment variable selects the dialog, matching
`gnome-ssh-askpass`. The value is compared case-insensitively.

- Unset or anything else: a passphrase entry with _OK_ and _Cancel_. This is the
  default. On _OK_ the passphrase is written to stdout.
- `confirm`: a _Yes_/_No_ question with no entry field.
- `none`: a message with a single _Close_ button and no entry field.

_Enter_ activates the default action and _Escape_ cancels.

## Colors

`GNOME_SSH_ASKPASS_FG_COLOR` and `GNOME_SSH_ASKPASS_BG_COLOR` set the foreground
and background. Each takes a hex color, optionally prefixed with `#` or `0x`, in
three-digit or six-digit form. A three-digit value has each nibble doubled, the
way CSS shorthand does, so `f00` becomes `ff0000`. A malformed value is ignored.
GTK4 removed `gtk_widget_modify_fg`/`_bg`, so the colors are applied through a
CSS provider.

## Exit status

The program returns `0` when you accept, namely _OK_ on a passphrase or _Yes_ on
a confirmation, and `1` otherwise, including _Cancel_, _Close_, _Escape_, and
closing the window. OpenSSH reads the passphrase only on a zero exit and treats
a nonzero exit of a confirmation as _No_.

## Input grabbing

The GTK3 helper grabs the keyboard through `gdk_seat_grab` so another client
can't read the passphrase as you type it. GTK4 seems to have dropped that
interface, however, and Wayland doesn't seem to permit a client to grab the
keyboard at all. Hence this program doesn't grab input, and
`GNOME_SSH_ASKPASS_GRAB_SERVER` and `GNOME_SSH_ASKPASS_GRAB_POINTER` have no
effect.

## Cross-compiling

Zig cross-compiles the binary for any Linux architecture without a GTK4
toolchain for the target. The bindings are hand-written externs rather than a
`@cImport`, so no GTK headers or libraries are needed at compile time, and
`-Dgtk-stub` links a stub `libgtk-4.so.1` so the target's real GTK4 resolves at
runtime.

```sh
zig build -Dtarget=aarch64-linux-gnu -Dgtk-stub -Dstrip -Doptimize=ReleaseSafe
```

The release workflow builds every supported architecture this way.

## Tests

The prompt-type and color parsing are in `src/root.zig`, apart from any GTK
dependency, and have unit tests.

```sh
zig build test
```
