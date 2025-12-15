/// Utility input function
const std = @import("std");

/// Turn the ctrl+key to normal keycode (ctrl+q -> q)
pub fn ctrlKey(c: u8) u8 {
    return c & 0x1f; // 1-26 to corresponding key
}

var read_buf: [1]u8 = undefined; // Only read 1 char at a time

/// Read a key to the buffer in poll mode, this block until timeout.
pub fn editorReadKey(reader: *std.Io.Reader) !u8 {
    var counter: u32 = 0;
    var first_char: u8 = 0;
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
        counter += 1;
        const c: u8 = read_buf[0];
        if (counter == 1) {
            first_char = c;
        }
    }
    return first_char;
}
