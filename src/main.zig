const std = @import("std");
const term = @import("terminal.zig");
const screen = @import("screen.zig");
const t_input = @import("input.zig");

// ====================== Global var ===============================
// Deinit in main to avoid leak

const timeout_ns = 3 * std.time.ns_per_s; // 3 seconds timeout

var stdout_buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
const writer = &stdout_writer.interface;

var buffer: [10000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buffer);
var arena = std.heap.ArenaAllocator.init(fba.allocator());
const allocator = arena.allocator();
var poller = std.Io.poll(
    allocator,
    enum { stdin },
    .{ .stdin = std.fs.File.stdin() },
);
const reader = poller.reader(.stdin);

// ========================= Main loop ==============================

/// Wait for a keypress and process. This is the main loop
pub fn mainLoop() !void {
    // First refresh when run
    try screen.editorRefreshScreen(writer);
    try writer.flush();

    // Wait for a keypress or timeout.
    while (try poller.pollTimeout(timeout_ns)) {
        const c = try t_input.editorReadKey(reader);
        if (c == comptime t_input.ctrlKey('q')) {
            return;
        }
        if (c == 0) {
            // Timeout waiting, can do something rendering here?
        } else {
            // Render something
            try screen.editorRefreshScreen(writer);
            if (std.ascii.isControl(c)) {
                try writer.print("{}\r\n", .{c});
            } else {
                try writer.print("{} ('{c}')\r\n", .{ c, c });
            }
            try writer.flush(); // Only flush once for every render.
        }
    }
}

pub fn main() !void {
    try term.enableRawmode();
    defer term.exitRawmode();
    term.initEditor();
    try mainLoop();
    defer arena.deinit();
    defer poller.deinit();
}
