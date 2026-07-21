//! Pure logic for ssh-askpass-zigtk, with no GTK or system dependencies so it
//! can be unit tested on its own. The GTK glue lives in `main.zig`.
const std = @import("std");

/// Dialog variants, selected by the `SSH_ASKPASS_PROMPT` environment variable,
/// matching gnome-ssh-askpass.
pub const PromptType = enum {
    /// Passphrase entry with OK and Cancel. This is the default.
    entry,
    /// Yes/No confirmation, no text entry.
    confirm,
    /// Message with a single Close button, no text entry.
    none,
};

/// Maps a `SSH_ASKPASS_PROMPT` value to a prompt type. `confirm` and `none` are
/// recognized case-insensitively; anything else, including a missing value, is
/// a passphrase entry.
pub fn promptTypeFromEnv(value: ?[]const u8) PromptType {
    const v = value orelse return .entry;
    if (std.ascii.eqlIgnoreCase(v, "confirm")) return .confirm;
    if (std.ascii.eqlIgnoreCase(v, "none")) return .none;
    return .entry;
}

/// Normalizes a hex color from `GNOME_SSH_ASKPASS_FG_COLOR` or
/// `GNOME_SSH_ASKPASS_BG_COLOR` into six lowercase hex digits (`rrggbb`). An
/// optional `#` or `0x` prefix is accepted, as are three-digit values, which
/// get each nibble doubled the way CSS shorthand does (`f00` becomes `ff0000`).
/// Returns null on any malformed input.
pub fn normalizeHexColor(input: []const u8) ?[6]u8 {
    var s = input;
    if (s.len >= 1 and s[0] == '#') {
        s = s[1..];
    } else if (s.len >= 2 and s[0] == '0' and (s[1] == 'x' or s[1] == 'X')) {
        s = s[2..];
    }

    if (s.len != 3 and s.len != 6) return null;
    for (s) |ch| {
        if (!std.ascii.isHex(ch)) return null;
    }

    var out: [6]u8 = undefined;
    if (s.len == 3) {
        for (0..3) |i| {
            const digit = std.ascii.toLower(s[i]);
            out[i * 2] = digit;
            out[i * 2 + 1] = digit;
        }
    } else {
        for (s, 0..) |ch, i| out[i] = std.ascii.toLower(ch);
    }
    return out;
}

test "promptTypeFromEnv defaults to entry" {
    try std.testing.expectEqual(PromptType.entry, promptTypeFromEnv(null));
    try std.testing.expectEqual(PromptType.entry, promptTypeFromEnv(""));
    try std.testing.expectEqual(PromptType.entry, promptTypeFromEnv("garbage"));
}

test "promptTypeFromEnv recognizes confirm and none case-insensitively" {
    try std.testing.expectEqual(PromptType.confirm, promptTypeFromEnv("confirm"));
    try std.testing.expectEqual(PromptType.confirm, promptTypeFromEnv("CONFIRM"));
    try std.testing.expectEqual(PromptType.confirm, promptTypeFromEnv("Confirm"));
    try std.testing.expectEqual(PromptType.none, promptTypeFromEnv("none"));
    try std.testing.expectEqual(PromptType.none, promptTypeFromEnv("NONE"));
}

test "normalizeHexColor accepts the documented forms" {
    try std.testing.expectEqualStrings("ffffff", &normalizeHexColor("#fff").?);
    try std.testing.expectEqualStrings("aabbcc", &normalizeHexColor("abc").?);
    try std.testing.expectEqualStrings("abcdef", &normalizeHexColor("0xABCDEF").?);
    try std.testing.expectEqualStrings("112233", &normalizeHexColor("#112233").?);
    try std.testing.expectEqualStrings("ff0000", &normalizeHexColor("f00").?);
}

test "normalizeHexColor rejects malformed input" {
    try std.testing.expectEqual(@as(?[6]u8, null), normalizeHexColor(""));
    try std.testing.expectEqual(@as(?[6]u8, null), normalizeHexColor("12"));
    try std.testing.expectEqual(@as(?[6]u8, null), normalizeHexColor("12345"));
    try std.testing.expectEqual(@as(?[6]u8, null), normalizeHexColor("ggg"));
    try std.testing.expectEqual(@as(?[6]u8, null), normalizeHexColor("#12g"));
}
