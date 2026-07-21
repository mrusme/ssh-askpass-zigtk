fn stub() callconv(.c) void {}

const symbols = [_][]const u8{
    "gtk_init",
    "gtk_window_new",
    "gtk_window_set_title",
    "gtk_window_set_resizable",
    "gtk_window_set_modal",
    "gtk_window_set_default_size",
    "gtk_window_set_child",
    "gtk_window_set_default_widget",
    "gtk_window_present",
    "gtk_box_new",
    "gtk_box_append",
    "gtk_label_new",
    "gtk_label_set_wrap",
    "gtk_password_entry_new",
    "gtk_editable_get_text",
    "gtk_editable_set_text",
    "gtk_button_new_with_label",
    "gtk_widget_set_margin_top",
    "gtk_widget_set_margin_bottom",
    "gtk_widget_set_margin_start",
    "gtk_widget_set_margin_end",
    "gtk_widget_set_hexpand",
    "gtk_widget_set_halign",
    "gtk_widget_grab_focus",
    "gtk_widget_add_controller",
    "gtk_event_controller_key_new",
    "gtk_css_provider_new",
    "gtk_css_provider_load_from_data",
    "gtk_style_context_add_provider_for_display",
    "gdk_display_get_default",
    "g_main_loop_new",
    "g_main_loop_run",
    "g_main_loop_quit",
    "g_signal_connect_data",
};

comptime {
    for (symbols) |name| {
        @export(&stub, .{ .name = name });
    }
}
