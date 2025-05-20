const std = @import("std");
const fd_t = std.posix.fd_t;
const termios = std.posix.termios;
const History = @import("history.zig").History;
const allocator = std.heap.page_allocator;

pub fn enableRawMode(fd: fd_t) !termios {
    const old_settings = try std.posix.tcgetattr(fd);
    var new_settings = old_settings;
    new_settings.lflag.ICANON = false;
    new_settings.lflag.ECHO = false;
    try std.posix.tcsetattr(fd, std.posix.TCSA.NOW, new_settings);

    return old_settings;
}

pub fn disableRawMode(fd: fd_t, original: termios) !void {
    try std.posix.tcsetattr(fd, std.posix.TCSA.NOW, original);
}

pub fn getInput(reader: anytype, writer: anytype, history: *History, should_exit: *bool) ![]const u8 {
    var i: usize = 0;
    var cursor_pos: usize = 0;
    var buf: [1024]u8 = undefined;
    var history_index = history.count;

    try writer.print("\x1b[34m>>>\x1b[0m ", .{});
    while (true) {
        const char = try reader.readByte();
        switch (char) {
            '\x04' => {
                should_exit.* = true;
                break;
            },
            '\x7f' => {
                if (i > 0 and cursor_pos > 0) {
                    i -= 1;
                    cursor_pos -= 1;

                    if (cursor_pos == i) {
                        try writer.print("\x08 \x08", .{});
                    } else if (cursor_pos < i) {
                        var n = cursor_pos;
                        while (n < i) : (n += 1) {
                            buf[n] = buf[n + 1];
                        }
                        try writer.print("\x08\x1b[K{s}", .{buf[cursor_pos..i]});
                        const cursor_shift = i - cursor_pos;

                        if (cursor_shift > 0)
                            try writer.print("\x1b[{d}D", .{cursor_shift});
                    }
                }
            },
            '\n' => {
                try history.add(buf[0..i]);
                break;
            },
            '\x1b' => {
                var seq: [2]u8 = undefined;
                try reader.readNoEof(&seq);
                switch (seq[1]) {
                    'A' => {
                        if (history_index > 0) {
                            history_index -= 1;

                            const line = history.get(history_index);
                            @memcpy(buf[0..line.?.len], line.?);
                            i = line.?.len;
                            cursor_pos = line.?.len;

                            try writer.print("\r\x1b[2K", .{});
                            try writer.print("\x1b[34m>>>\x1b[0m {?s}", .{line.?});
                        }
                    },
                    'B' => {
                        if (history_index + 1 <= history.count) {
                            history_index += 1;
                            if (history_index == history.count) {
                                try writer.print("\r\x1b[2K\x1b[34m>>>\x1b[0m ", .{});
                                // try writer.print("\r\x1b[2K", .{});
                                @memset(buf[0..buf.len], 0);
                                i = 0;
                                cursor_pos = 0;
                            } else {
                                const line = history.get(history_index);
                                @memcpy(buf[0..line.?.len], line.?);
                                i = line.?.len;
                                cursor_pos = line.?.len;
                                try writer.print("\r\x1b[2K", .{});
                                try writer.print("\x1b[34m>>>\x1b[0m {?s}", .{line.?});
                            }
                        }
                    },
                    'C' => {
                        if (cursor_pos < i) {
                            try writer.print("\x1b[C", .{});
                            cursor_pos += 1;
                        }
                    },
                    'D' => {
                        if (cursor_pos > 0) {
                            try writer.print("\x1b[D", .{});
                            cursor_pos -= 1;
                        }
                    },
                    else => {},
                }
            },
            else => {
                if (cursor_pos == i) {
                    try writer.print("{c}", .{char});
                    buf[i] = char;
                } else if (cursor_pos < i) {
                    var n = i;
                    while (n > cursor_pos) : (n -= 1) {
                        buf[n] = buf[n - 1];
                    }
                    buf[cursor_pos] = char;
                    try writer.print("\x1b[K{s}", .{buf[cursor_pos .. i + 1]});
                    const cursor_shift = i - cursor_pos;
                    try writer.print("\x1b[{d}D", .{cursor_shift});
                }
                i += 1;
                cursor_pos += 1;
            },
        }
    }
    return allocator.dupe(u8, buf[0..i]);
}
