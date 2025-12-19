/// Utility to draw things on screen and deal with escape sequences
const std = @import("std");
const term = @import("terminal.zig");

pub fn editorDrawRow(writer: *std.Io.Writer) !void {
    for (0..term.E.screen_row) |i| {
        if (i == term.E.screen_row / 3) {
            // Print special hello message
            var st = try std.fmt.allocPrint(std.heap.page_allocator, "Kilo editor -- version {s}", .{"0.0.1"});
            if (st.len > term.E.screen_col) {
                st = st[0..term.E.screen_col];
            }
            // Padding with space and ~
            var padding = (term.E.screen_col - st.len) / 2;
            if (padding > 0) {
                try writer.print("~", .{});
                padding -= 1;
            }
            // Still fine since it's not flushed
            for (0..padding) |_| {
                try writer.print(" ", .{});
            }
            try writer.print("{s}", .{st});
        } else {
            try writer.print("~", .{});
        }
        try writer.print("\x1b[K", .{}); // Clear this line
        if (i < term.E.screen_row - 1) {
            try writer.print("\r\n", .{}); // Don't \r\n the last line to not scroll
        }
    }
}

/// Special write to clear the screen.
/// After that, the cursor is at the top right.
pub fn editorRefreshScreen(writer: *std.Io.Writer) !void {
    try writer.print("\x1b[?25l", .{}); // Hide the cursor
    // try writer.print("\x1b[2J", .{}); // Clear full screen, not use since not optimal
    try writer.print("\x1b[H", .{}); // Move top left again
    try editorDrawRow(writer);
    // Terminal use 1-index so convert 0-index to 1
    try writer.print("\x1b[{};{}H", .{ term.E.cy + 1, term.E.cx + 1 }); // Move to cursor position
    try writer.print("\x1b[?25h", .{}); // Show cursor
}
