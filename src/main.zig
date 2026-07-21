//! ssh-askpass-zigtk: a GTK4 SSH_ASKPASS helper.
//!
//! OpenSSH runs this program to collect a passphrase or a yes/no confirmation
//! when no controlling terminal is available. The prompt text is passed on the
//! command line and the passphrase, if any, is written to stdout. The behavior
//! follows contrib/gnome-ssh-askpass from OpenSSH. The `SSH_ASKPASS_PROMPT`
//! environment variable selects the dialog, and `GNOME_SSH_ASKPASS_FG_COLOR`
//! and `GNOME_SSH_ASKPASS_BG_COLOR` recolor it.
//!
//! Input grabbing is not implemented. GTK4 dropped the `gdk_seat_grab`
//! interface of GTK3, and Wayland does not seem to permit a client to grab the
//! keyboard, so there is no way (?) to do it without X11.
const std = @import("std");
const gtk = @import("gtk.zig");
const lib = @import("ssh_askpass_zigtk");

const default_message = "Enter your OpenSSH passphrase:";

const Response = enum { cancel, ok };

const App = struct {
    loop: *gtk.MainLoop,
    response: Response = .cancel,
};

fn onOk(_: *gtk.Widget, app: *App) callconv(.c) void {
    app.response = .ok;
    gtk.g_main_loop_quit(app.loop);
}

fn onCancel(_: *gtk.Widget, app: *App) callconv(.c) void {
    app.response = .cancel;
    gtk.g_main_loop_quit(app.loop);
}

fn onCloseRequest(_: *gtk.Widget, app: *App) callconv(.c) c_int {
    app.response = .cancel;
    gtk.g_main_loop_quit(app.loop);
    // Stop the default handler from tearing the window down. The process exits
    // right after the loop returns and reclaims it.
    return 1;
}

fn onKeyPressed(
    _: *gtk.EventController,
    keyval: c_uint,
    _: c_uint,
    _: c_uint,
    app: *App,
) callconv(.c) c_int {
    if (keyval == gtk.KEY_Escape) {
        app.response = .cancel;
        gtk.g_main_loop_quit(app.loop);
        return 1;
    }
    return 0;
}

pub fn main(init: std.process.Init) !u8 {
    const arena = init.arena.allocator();
    const env = init.environ_map;

    const args = try init.minimal.args.toSlice(arena);
    const message: [:0]const u8 = if (args.len > 1) blk: {
        const parts = try arena.alloc([]const u8, args.len - 1);
        for (args[1..], 0..) |arg, i| parts[i] = arg;
        break :blk try std.mem.joinZ(arena, " ", parts);
    } else default_message;

    const prompt_type = lib.promptTypeFromEnv(env.get("SSH_ASKPASS_PROMPT"));
    const fg = parseColor(env.get("GNOME_SSH_ASKPASS_FG_COLOR"));
    const bg = parseColor(env.get("GNOME_SSH_ASKPASS_BG_COLOR"));

    gtk.gtk_init();
    applyColors(fg, bg);

    const loop = gtk.g_main_loop_new(null, 0) orelse return error.OutOfMemory;
    var app: App = .{ .loop = loop };

    const window = gtk.gtk_window_new();
    gtk.gtk_window_set_title(window, "OpenSSH");
    gtk.gtk_window_set_resizable(window, 0);
    gtk.gtk_window_set_modal(window, 1);
    gtk.gtk_window_set_default_size(window, 360, -1);
    gtk.connect(window, "close-request", &onCloseRequest, &app);

    const box = gtk.gtk_box_new(gtk.ORIENTATION_VERTICAL, 12);
    gtk.gtk_widget_set_margin_top(box, 16);
    gtk.gtk_widget_set_margin_bottom(box, 16);
    gtk.gtk_widget_set_margin_start(box, 16);
    gtk.gtk_widget_set_margin_end(box, 16);
    gtk.gtk_window_set_child(window, box);

    const label = gtk.gtk_label_new(message.ptr);
    gtk.gtk_label_set_wrap(label, 1);
    gtk.gtk_widget_set_halign(label, gtk.ALIGN_START);
    gtk.gtk_box_append(box, label);

    var entry: ?*gtk.Widget = null;
    const button_row = gtk.gtk_box_new(gtk.ORIENTATION_HORIZONTAL, 8);
    gtk.gtk_widget_set_halign(button_row, gtk.ALIGN_END);

    switch (prompt_type) {
        .entry => {
            const e = gtk.gtk_password_entry_new();
            gtk.gtk_widget_set_hexpand(e, 1);
            gtk.connect(e, "activate", &onOk, &app);
            gtk.gtk_box_append(box, e);
            entry = e;

            const cancel = gtk.gtk_button_new_with_label("Cancel");
            const ok = gtk.gtk_button_new_with_label("OK");
            gtk.connect(cancel, "clicked", &onCancel, &app);
            gtk.connect(ok, "clicked", &onOk, &app);
            gtk.gtk_box_append(button_row, cancel);
            gtk.gtk_box_append(button_row, ok);
            gtk.gtk_window_set_default_widget(window, ok);
            _ = gtk.gtk_widget_grab_focus(e);
        },
        .confirm => {
            const no = gtk.gtk_button_new_with_label("No");
            const yes = gtk.gtk_button_new_with_label("Yes");
            gtk.connect(no, "clicked", &onCancel, &app);
            gtk.connect(yes, "clicked", &onOk, &app);
            gtk.gtk_box_append(button_row, no);
            gtk.gtk_box_append(button_row, yes);
            gtk.gtk_window_set_default_widget(window, yes);
            _ = gtk.gtk_widget_grab_focus(yes);
        },
        .none => {
            const close = gtk.gtk_button_new_with_label("Close");
            gtk.connect(close, "clicked", &onCancel, &app);
            gtk.gtk_box_append(button_row, close);
            gtk.gtk_window_set_default_widget(window, close);
            _ = gtk.gtk_widget_grab_focus(close);
        },
    }
    gtk.gtk_box_append(box, button_row);

    const key = gtk.gtk_event_controller_key_new();
    gtk.connect(key, "key-pressed", &onKeyPressed, &app);
    gtk.gtk_widget_add_controller(window, key);

    gtk.gtk_window_present(window);
    gtk.g_main_loop_run(loop);

    if (app.response == .ok) {
        if (entry) |e| {
            const text = std.mem.span(gtk.gtk_editable_get_text(e));
            writeAll(text);
            writeAll("\n");
            // Clear the widget's copy of the passphrase.
            gtk.gtk_editable_set_text(e, "");
        }
        return 0;
    }
    return 1;
}

fn parseColor(value: ?[]const u8) ?[6]u8 {
    return lib.normalizeHexColor(value orelse return null);
}

/// Installs a CSS provider recoloring the window and entry when either color is
/// set. GTK4 removed `gtk_widget_modify_fg`/`_bg`, so styling goes through CSS.
fn applyColors(fg: ?[6]u8, bg: ?[6]u8) void {
    if (fg == null and bg == null) return;

    var buf: [256]u8 = undefined;
    var len: usize = 0;
    const put = struct {
        fn f(b: []u8, n: *usize, s: []const u8) void {
            @memcpy(b[n.*..][0..s.len], s);
            n.* += s.len;
        }
    }.f;

    put(&buf, &len, "window, entry, entry > text, label, button {");
    if (fg) |color| {
        put(&buf, &len, "color:#");
        put(&buf, &len, &color);
        put(&buf, &len, ";");
    }
    if (bg) |color| {
        put(&buf, &len, "background-color:#");
        put(&buf, &len, &color);
        put(&buf, &len, ";");
    }
    put(&buf, &len, "}");
    buf[len] = 0;

    const provider = gtk.gtk_css_provider_new();
    gtk.gtk_css_provider_load_from_data(provider, @ptrCast(&buf), @intCast(len));
    const display = gtk.gdk_display_get_default() orelse return;
    gtk.gtk_style_context_add_provider_for_display(display, provider, gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
}

/// Writes all of `bytes` to stdout with a direct, unbuffered libc `write`,
/// matching the `setvbuf(stdout, 0, _IONBF, 0)` the C helpers use so OpenSSH
/// gets the passphrase immediately.
fn writeAll(bytes: []const u8) void {
    var written: usize = 0;
    while (written < bytes.len) {
        const rc = std.c.write(std.posix.STDOUT_FILENO, bytes.ptr + written, bytes.len - written);
        if (rc <= 0) return;
        written += @intCast(rc);
    }
}
