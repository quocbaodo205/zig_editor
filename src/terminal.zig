/// Utility functions that deals with terminal
const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub const EditorConfig = struct {
    // Cursor
    cx: u16,
    cy: u16,
    // Screen
    screen_row: u16,
    screen_col: u16,
    // Original terminal to return upon exit
    orig_term: std.posix.termios,
};

pub var E: EditorConfig = undefined;

pub fn enableRawmode() !void {
    var info = try posix.tcgetattr(linux.STDIN_FILENO);
    E.orig_term = info;
    info.lflag.ECHO = false;
    info.lflag.ICANON = false;
    info.lflag.ISIG = false; // No more Ctrl+...
    info.oflag.OPOST = false; // No output processing
    info.lflag.IEXTEN = false;
    info.iflag.ICRNL = false;
    info.iflag.IXON = false;
    info.iflag.BRKINT = false;
    info.iflag.INPCK = false;
    info.iflag.ISTRIP = false;
    // TODO: Fix ctrl+i / ctrl+m
    try posix.tcsetattr(linux.STDIN_FILENO, posix.TCSA.FLUSH, info);
}

pub fn exitRawmode() void {
    posix.tcsetattr(linux.STDIN_FILENO, posix.TCSA.FLUSH, E.orig_term) catch |err| {
        std.debug.print("Err = {}", .{err}); // Basically ignore
    };
}

pub fn getWindowsSize(e: *EditorConfig) void {
    var wins: posix.winsize = undefined;
    // ioctl last argument is the address to a posix.winsize
    _ = linux.ioctl(linux.STDOUT_FILENO, linux.T.IOCGWINSZ, @intFromPtr(&wins));
    e.screen_col = wins.col;
    e.screen_row = wins.row;
}

pub fn initEditor() void {
    E = EditorConfig{
        .cx = 0,
        .cy = 0,
        .orig_term = undefined,
        .screen_col = 0,
        .screen_row = 0,
    };
    getWindowsSize(&E);
}
