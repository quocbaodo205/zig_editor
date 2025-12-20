/// Utility functions that deals with terminal and editor
const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

// ======================= Data ====================

/// Hold data of a row
pub const EditorRow = struct {
    chars: []u8, // Editable bytes
};

pub const EditorConfig = struct {
    // Cursor
    cx: u16,
    cy: u16,
    // Screen
    screen_row: u16,
    screen_col: u16,
    // Original terminal to return upon exit
    orig_term: std.posix.termios,
    // Row related
    num_rows: u16,
    rows: std.ArrayList(EditorRow),
    row_offset: u16,
    col_offset: u16,
};

pub var E: EditorConfig = undefined;

// ========================= Terminal functions ==============

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

// ============================= Editor functions ================

pub fn initEditor(allocator: std.mem.Allocator) !void {
    E = EditorConfig{
        .cx = 0,
        .cy = 0,
        .orig_term = undefined,
        .screen_col = 0,
        .screen_row = 0,
        .num_rows = 0,
        .rows = try std.ArrayList(EditorRow).initCapacity(allocator, 10),
        .row_offset = 0,
        .col_offset = 0,
    };
    getWindowsSize(&E);
}

// ============================ Dealing with file ================

var file_buffer: [10000000]u8 = undefined;

/// Open a file + read all content.
/// This function open file in read-only, copy all content line by line to the editor.
pub fn editorOpen(allocator: std.mem.Allocator, file_name: []const u8) !void {
    // Open a file + read all lines
    const file = try std.fs.cwd().openFile(file_name, std.fs.File.OpenFlags{
        .mode = .read_only,
    });
    defer file.close();
    var rd = file.reader(&file_buffer);
    // For now, all write will just write the whole file from start to finish
    // var wr = file.writer(&file_buffer);
    // wr.interface.writeAll("insert text here lol");
    // wr.interface.flush();

    while (true) {
        // When reading, we already copy data into our file_buffer.
        // EOF return null data
        const data = rd.interface.takeDelimiter('\n') catch |err| {
            switch (err) {
                error.ReadFailed => {
                    break;
                },
                else => {
                    @panic("Shit happends while reading file");
                },
            }
        };
        if (data) |dt| {
            // TODO: Probably a good idea to copy out to our own data, but waste alloc and copy.
            const copy = try allocator.dupe(u8, dt);
            try E.rows.append(allocator, EditorRow{ .chars = copy });
            E.num_rows += 1;
        } else {
            break;
        }
    }
}
