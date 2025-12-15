const std = @import("std");
const zig_editor = @import("zig_editor");

var old_info: std.posix.termios = undefined;

pub fn enableRawmode() !void {
    // var info: std.os.linux.termios = undefined;
    var info = try std.posix.tcgetattr(std.os.linux.STDIN_FILENO);
    old_info = info;
    info.lflag.ECHO = false;
    info.lflag.ICANON = false;
    info.lflag.ISIG = false; // No more Ctrl+...
    info.oflag.OPOST = false; // No output processing
    // TODO: Fix ctrl+i / ctrl+m
    try std.posix.tcsetattr(std.os.linux.STDIN_FILENO, std.posix.TCSA.FLUSH, info);
}

pub fn exitRawmode() void {
    std.posix.tcsetattr(std.os.linux.STDIN_FILENO, std.posix.TCSA.FLUSH, old_info) catch |err| {
        std.debug.print("Err = {}", .{err}); // Basically ignore
    };
}

pub fn main() !void {
    try enableRawmode();
    defer exitRawmode();

    // Step 1: My own echo with raw mode. Q to exit.
    var read_buf: [1]u8 = undefined; // Only read 1 char at a time
    // Output stdout + flush
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    // Poller stuff: Poll a char
    // Init an FBA and Arena
    var buffer: [10000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var arena = std.heap.ArenaAllocator.init(fba.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var poller = std.Io.poll(
        allocator,
        enum { stdin },
        .{ .stdin = std.fs.File.stdin() },
    );
    defer poller.deinit();

    const timeout_ns = 3 * std.time.ns_per_s; // 3 seconds timeout
    var reader = poller.reader(.stdin);

    outer: while (try poller.pollTimeout(timeout_ns)) {
        var counter: u32 = 0;
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
            if (std.ascii.isControl(c)) {
                try stdout.print("{}\r\n", .{c});
            } else {
                try stdout.print("{} ('{c}')\r\n", .{ c, c });
            }
            try stdout.flush(); // Don't forget to flush!
            if (c == 'q') {
                break :outer;
            }
        }
        if (counter == 0) {
            try stdout.print("Timeout\r\n", .{});
            try stdout.flush(); // Don't forget to flush!

        }
    }
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
