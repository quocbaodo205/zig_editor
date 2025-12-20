/// Utility input function
const std = @import("std");
const term = @import("terminal.zig");

/// Turn the ctrl+key to normal keycode (ctrl+q -> q)
pub fn ctrlKey(c: u8) u8 {
    return c & 0x1f; // 1-26 to corresponding key
}

const editorKey = enum(u16) {
    ArrowUp = 1000,
    ArrowDown,
    ArrowLeft,
    ArrowRight,
    // TODO: Add usage for PU and PD
    PageUp,
    PageDown,
    // TODO: Add usage for home and end
    Home,
    End,
    // TODO: Add usage for del key
    Del,
};

var read_buf: [1]u8 = undefined; // Only read 1 char at a time
pub var input_buf: [10]u8 = [_]u8{0} ** 10;

/// Convert a bunch of input into a key
pub fn convertKey() u16 {
    if (input_buf[0] == '\x1b') {
        if (input_buf[1] == '[') {
            // Page up and page down key: <esc>[5~ and <esc>[6~
            if (input_buf[2] >= '0' and input_buf[2] <= '9') {
                if (input_buf[3] == '~') {
                    switch (input_buf[2]) {
                        '1' => {
                            return @intFromEnum(editorKey.Home);
                        },
                        '3' => {
                            return @intFromEnum(editorKey.Del);
                        },
                        '4' => {
                            return @intFromEnum(editorKey.End);
                        },
                        '5' => {
                            return @intFromEnum(editorKey.PageUp);
                        },
                        '6' => {
                            return @intFromEnum(editorKey.PageDown);
                        },
                        // Some system map home and end to 7 and 8 as well
                        '7' => {
                            return @intFromEnum(editorKey.Home);
                        },
                        '8' => {
                            return @intFromEnum(editorKey.End);
                        },
                        else => {
                            return 0;
                        },
                    }
                }
            }
            // Convert arrow key
            switch (input_buf[2]) {
                'A' => {
                    return @intFromEnum(editorKey.ArrowUp);
                },
                'B' => {
                    return @intFromEnum(editorKey.ArrowDown);
                },
                'C' => {
                    return @intFromEnum(editorKey.ArrowRight);
                },
                'D' => {
                    return @intFromEnum(editorKey.ArrowLeft);
                },
                else => {
                    return 0;
                },
            }
        }
    }
    return input_buf[0];
}

/// Read a key to the buffer in poll mode, this block until timeout.
pub fn editorReadKey(reader: *std.Io.Reader) !u16 {
    var counter: usize = 0;
    input_buf[0] = 0;
    // Read byte by byte until either:
    // ReadFailed: Timeout happens
    // EndOfStream: Cannot read anymore
    // counter keep track of which is which.
    while (true) {
        reader.readSliceAll(read_buf[0..]) catch |err| {
            switch (err) {
                error.ReadFailed => {
                    break;
                },
                error.EndOfStream => {
                    break;
                },
            }
        };
        const c: u8 = read_buf[0];
        input_buf[counter] = c;
        counter += 1;
    }
    return convertKey();
}

/// Move cursor using wasd
pub fn editorMoveCursor(c: u16) void {
    switch (c) {
        @intFromEnum(editorKey.ArrowUp) => {
            if (term.E.cy > 0) {
                term.E.cy -= 1;
            } else {
                // Allow scrolling
                if (term.E.row_offset > 0) {
                    term.E.row_offset -= 1;
                }
            }
        },
        @intFromEnum(editorKey.ArrowDown) => {
            if (term.E.cy < term.E.screen_row - 1) {
                term.E.cy += 1;
            } else {
                // Allow scrolling
                if (term.E.row_offset + term.E.cy + 1 < term.E.num_rows) {
                    term.E.row_offset += 1;
                }
            }
        },
        @intFromEnum(editorKey.ArrowLeft) => {
            if (term.E.cx > 0) {
                term.E.cx -= 1;
            } else {
                // Allow scrolling
                if (term.E.col_offset > 0) {
                    term.E.col_offset -= 1;
                }
            }
        },
        @intFromEnum(editorKey.ArrowRight) => {
            if (term.E.cx < term.E.screen_col - 1) {
                term.E.cx += 1;
            } else {
                // Allow scrolling
                // TODO: Currently scroll to inf lol
                term.E.col_offset += 1;
            }
        },
        else => {},
    }
}
