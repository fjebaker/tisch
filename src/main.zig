const std = @import("std");

const Row = struct {
    const Self = @This();

    items: [][]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, items: [][]const u8) !Self {
        var copy = try std.ArrayList([]u8).initCapacity(allocator, items.len);
        errdefer copy.deinit();
        errdefer for (copy.items) |c| allocator.free(c);
        for (items) |item| {
            copy.appendAssumeCapacity(try allocator.dupe(u8, item));
        }
        return .{ .items = try copy.toOwnedSlice(), .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        for (self.items) |i| self.allocator.free(i);
        self.allocator.free(self.items);
    }

    pub fn longestLength(self: *const Self) usize {
        var max: usize = 0;
        for (self.items) |item| max = @max(item.len, max);
        return max;
    }

    pub fn insertColumn(self: *Self, item: []const u8, index: usize) !void {
        // allocator new storage and then copy over the pointers
        var new_items = try self.allocator.alloc([]u8, self.items.len + 1);
        errdefer self.allocator.free(new_items);

        var j: usize = 0;
        for (self.items, 0..) |old_item, i| {
            if (i == index) {
                new_items[j] = try self.allocator.dupe(u8, item);
                j += 1;
            }
            new_items[j] = old_item;
            j += 1;
        }

        // update
        self.allocator.free(self.items);
        self.items = new_items;
    }
};

pub const TableError = error{RowLengthMismatch};

const Table = struct {
    const Self = @This();

    pub const Alignment = enum { Left, Center, Right };

    headings: Row,
    rows: std.ArrayList(Row),
    allocator: std.mem.Allocator,
    pub fn addRow(self: *Self, row: [][]const u8) !void {
        // check number of items
        if (row.len != self.headings.items.len) {
            return TableError.RowLengthMismatch;
        }

        var new_row = try Row.init(self.allocator, row);
        errdefer new_row.deinit();
        try self.rows.append(new_row);
    }

    pub fn initWithHeadings(allocator: std.mem.Allocator, headings: [][]const u8) !Self {
        var rows = std.ArrayList(Row).init(allocator);
        var hrow = try Row.init(allocator, headings);
        return .{ .headings = hrow, .rows = rows, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        for (self.rows.items) |*row| row.deinit();
        self.rows.deinit();
        self.headings.deinit();
    }

    fn minCellWidth(self: *const Self, col: usize) usize {
        var max: usize = self.headings.items[col].len;
        for (self.rows.items) |row| {
            max = @max(row.items[col].len, max);
        }
        return max;
    }

    fn getColumnSpacings(self: *const Self) ![]usize {
        var spacings = try self.allocator.alloc(usize, self.headings.items.len);
        for (spacings, 0..) |*s, i| {
            s.* = self.minCellWidth(i);
        }
        return spacings;
    }

    pub const Padding = struct {
        l: usize = 0,
        r: usize = 0,
    };

    pub const PrintOptions = struct {
        alignment: Alignment = .Left,
        header_alignment: Alignment = .Center,
        even: bool = false,
        outline: bool = true,
        index: bool = false,
        index_str: []const u8 = "",
        padding: Padding = .{},
    };
    pub fn toString(self: *Self, opts: PrintOptions) ![]u8 {
        var list: std.ArrayList(u8) = std.ArrayList(u8).init(self.allocator);
        errdefer list.deinit();
        var writer = list.writer();

        // are we doing indexing?
        if (opts.index) {
            // insert a phony column into each row
            try self.headings.insertColumn(opts.index_str, 0);
            var buffer: [1024]u8 = undefined;
            for (self.rows.items, 1..) |*row, i| {
                const size = std.fmt.formatIntBuf(&buffer, i, 10, .lower, .{});
                const i_str = buffer[0..size];
                try row.insertColumn(i_str, 0);
            }
        }

        // print header column
        var spacings = try self.getColumnSpacings();
        defer self.allocator.free(spacings);

        if (opts.even) {
            // equalize all spacings
            var max: usize = 0;
            for (spacings) |s| max = @max(s, max);
            for (spacings) |*s| s.* = max;
        }

        const linelength = 1 + self.headings.items.len + blk: {
            var sum: usize = 0;
            for (spacings) |s| sum += s;
            break :blk sum;
        };

        if (opts.outline) {
            try self.writeTopCap(&writer, spacings, linelength, opts.padding);
            _ = try writer.write("\n");
        }

        const delimiter = if (opts.outline) "│" else "";

        // write the header
        try self.writeRow(
            &writer,
            self.headings,
            spacings,
            linelength,
            delimiter,
            opts.header_alignment,
            opts.padding,
        );
        _ = try writer.write("\n");

        if (opts.outline) {
            try self.writeSpacer(&writer, spacings, linelength, opts.padding);
            _ = try writer.write("\n");
        }

        for (self.rows.items) |row| {
            try self.writeRow(
                &writer,
                row,
                spacings,
                linelength,
                delimiter,
                opts.alignment,
                opts.padding,
            );
            _ = try writer.write("\n");
        }

        if (opts.outline) {
            try self.writeBottomCap(&writer, spacings, linelength, opts.padding);
            _ = try writer.write("\n");
        }

        return list.toOwnedSlice();
    }

    fn writeRow(
        _: *const Self,
        writer: anytype,
        row: Row,
        spacings: []const usize,
        linelength: usize,
        spacer: []const u8,
        alignment: Alignment,
        padding: Padding,
    ) !void {
        _ = linelength;
        _ = try writer.write(spacer);
        for (spacings, 0..) |spacing, i| {
            const entry = row.items[i];
            var diff = spacing - entry.len;

            // do left padding
            var p = padding.l;
            while (p > 0) : (p -= 1) _ = try writer.write(" ");

            switch (alignment) {
                .Left => {
                    _ = try writer.write(entry);
                    while (diff > 0) : (diff -= 1) {
                        _ = try writer.write(" ");
                    }
                },
                .Right => {
                    while (diff > 0) : (diff -= 1) {
                        _ = try writer.write(" ");
                    }
                    _ = try writer.write(entry);
                },
                .Center => {
                    const mid = try std.math.divFloor(usize, diff, 2);
                    while (diff > mid) : (diff -= 1) {
                        _ = try writer.write(" ");
                    }
                    _ = try writer.write(entry);
                    while (diff > 0) : (diff -= 1) {
                        _ = try writer.write(" ");
                    }
                },
            }

            // do right padding
            p = padding.r;
            while (p > 0) : (p -= 1) _ = try writer.write(" ");

            _ = try writer.write(spacer);
        }
    }

    fn writeSpacer(
        self: *const Self,
        writer: anytype,
        spacings: []const usize,
        linelength: usize,
        padding: Padding,
    ) !void {
        try self.writeDelimiters(writer, spacings, linelength, "├", "─", "┤", "┼", padding);
    }

    fn writeTopCap(
        self: *const Self,
        writer: anytype,
        spacings: []const usize,
        linelength: usize,
        padding: Padding,
    ) !void {
        try self.writeDelimiters(writer, spacings, linelength, "┌", "─", "┐", "┬", padding);
    }

    fn writeBottomCap(
        self: *const Self,
        writer: anytype,
        spacings: []const usize,
        linelength: usize,
        padding: Padding,
    ) !void {
        try self.writeDelimiters(writer, spacings, linelength, "└", "─", "┘", "┴", padding);
    }

    fn writeDelimiters(
        _: *const Self,
        writer: anytype,
        spacings: []const usize,
        linelength: usize,
        left: []const u8,
        mid: []const u8,
        right: []const u8,
        seperator: []const u8,
        padding: Padding,
    ) !void {
        _ = try writer.write(left);
        var i: usize = 0;
        for (spacings) |spacing| {
            const width = spacing + padding.l + padding.r;
            for (0..width) |_| {
                _ = try writer.write(mid);
            }
            i += spacing + 1;
            if (i == linelength - 1) {
                _ = try writer.write(right);
                break;
            }
            _ = try writer.write(seperator);
        }
    }
};

test "basic-operations" {
    const allocator = std.testing.allocator;

    var headings = [_][]const u8{ "Heading 1", "Head 2", "Heading 3" };
    var table = try Table.initWithHeadings(allocator, &headings);
    defer table.deinit();

    var row = [_][]const u8{ "a", "b", "c" };
    try table.addRow(&row);
    try table.addRow(&row);
    try table.addRow(&row);

    var str = try table.toString(
        .{
            .alignment = .Right,
            .even = false,
            .outline = false,
            .padding = .{ .r = 2, .l = 2 },
            .index = true,
        },
    );
    defer allocator.free(str);
    std.debug.print("Hello\n{s}", .{str});
}
