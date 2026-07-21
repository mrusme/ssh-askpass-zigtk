//! Minimal hand-written bindings for the GTK4 and GLib functions this program
//! uses. Declaring the prototypes by hand, rather than through `@cImport`,
//! keeps the build free of X11 headers, as no symbol here comes from
//! `gdk/gdkx.h`, `X11/Xlib.h`, or any other X-specific interface, so the binary
//! builds and runs on systems compiled without X11 (e.g. Gentoo with `-X`).

/// Opaque handle covering every GTK widget the program touches. GObject uses
/// single inheritance with the parent struct as the first member, so a window,
/// box, label, entry, editable, or button pointer is layout-compatible with a
/// `GtkWidget *` and can share one type at the ABI boundary.
pub const Widget = opaque {};
pub const EventController = opaque {};
pub const CssProvider = opaque {};
pub const Display = opaque {};
pub const MainLoop = opaque {};

pub const ORIENTATION_HORIZONTAL: c_int = 0;
pub const ORIENTATION_VERTICAL: c_int = 1;

pub const ALIGN_FILL: c_int = 0;
pub const ALIGN_START: c_int = 1;
pub const ALIGN_END: c_int = 2;
pub const ALIGN_CENTER: c_int = 3;

pub const STYLE_PROVIDER_PRIORITY_APPLICATION: c_uint = 600;

/// GDK keysym for Escape, from `gdk/gdkkeysyms.h`. Hardcoded so the header
/// stays out.
pub const KEY_Escape: c_uint = 0xff1b;

pub extern fn gtk_init() void;

pub extern fn gtk_window_new() *Widget;
pub extern fn gtk_window_set_title(window: *Widget, title: [*:0]const u8) void;
pub extern fn gtk_window_set_resizable(window: *Widget, resizable: c_int) void;
pub extern fn gtk_window_set_modal(window: *Widget, modal: c_int) void;
pub extern fn gtk_window_set_default_size(window: *Widget, width: c_int, height: c_int) void;
pub extern fn gtk_window_set_child(window: *Widget, child: *Widget) void;
pub extern fn gtk_window_set_default_widget(window: *Widget, default_widget: *Widget) void;
pub extern fn gtk_window_present(window: *Widget) void;

pub extern fn gtk_box_new(orientation: c_int, spacing: c_int) *Widget;
pub extern fn gtk_box_append(box: *Widget, child: *Widget) void;

pub extern fn gtk_label_new(str: ?[*:0]const u8) *Widget;
pub extern fn gtk_label_set_wrap(label: *Widget, wrap: c_int) void;

pub extern fn gtk_password_entry_new() *Widget;
pub extern fn gtk_editable_get_text(editable: *Widget) [*:0]const u8;
pub extern fn gtk_editable_set_text(editable: *Widget, text: [*:0]const u8) void;

pub extern fn gtk_button_new_with_label(label: [*:0]const u8) *Widget;

pub extern fn gtk_widget_set_margin_top(widget: *Widget, margin: c_int) void;
pub extern fn gtk_widget_set_margin_bottom(widget: *Widget, margin: c_int) void;
pub extern fn gtk_widget_set_margin_start(widget: *Widget, margin: c_int) void;
pub extern fn gtk_widget_set_margin_end(widget: *Widget, margin: c_int) void;
pub extern fn gtk_widget_set_hexpand(widget: *Widget, expand: c_int) void;
pub extern fn gtk_widget_set_halign(widget: *Widget, alignment: c_int) void;
pub extern fn gtk_widget_grab_focus(widget: *Widget) c_int;
pub extern fn gtk_widget_add_controller(widget: *Widget, controller: *EventController) void;

pub extern fn gtk_event_controller_key_new() *EventController;

pub extern fn gtk_css_provider_new() *CssProvider;
pub extern fn gtk_css_provider_load_from_data(provider: *CssProvider, data: [*:0]const u8, length: isize) void;
pub extern fn gtk_style_context_add_provider_for_display(display: *Display, provider: *CssProvider, priority: c_uint) void;

pub extern fn gdk_display_get_default() ?*Display;

pub extern fn g_main_loop_new(context: ?*anyopaque, is_running: c_int) ?*MainLoop;
pub extern fn g_main_loop_run(loop: *MainLoop) void;
pub extern fn g_main_loop_quit(loop: *MainLoop) void;

const GCallback = *const fn () callconv(.c) void;
extern fn g_signal_connect_data(
    instance: *anyopaque,
    detailed_signal: [*:0]const u8,
    c_handler: GCallback,
    data: ?*anyopaque,
    destroy_data: ?*anyopaque,
    connect_flags: c_uint,
) c_ulong;

/// Wrapper over `g_signal_connect_data` that hides the GObject casts.
/// `instance` is any GTK object pointer and `handler` is a pointer to a
/// `callconv(.c)` function whose last argument receives `data`.
pub fn connect(instance: anytype, signal: [*:0]const u8, handler: anytype, data: ?*anyopaque) void {
    _ = g_signal_connect_data(@ptrCast(instance), signal, @ptrCast(handler), data, null, 0);
}
