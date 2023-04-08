# Tisch

> Using bad code saves you from writing bad code.

Table printing utilities for command line tools.

## Examples

Default with `tisch.Table`:

```zig
var str = try table.toString(.{});
```

```
┌─────────┬─────┬─────────┐
│Heading 1│  2  │Heading 3│
├─────────┼─────┼─────────┤
│a        │b    │c        │
│1        │2    │3        │
│hello    │world│!        │
└─────────┴─────┴─────────┘
```

With padding:

```zig
var str = try table.toString(.{
    .padding = .{ .l = 3, .r = 2 },
});
```

```
┌──────────────┬──────────┬──────────────┐
│   Heading 1  │     2    │   Heading 3  │
├──────────────┼──────────┼──────────────┤
│   a          │   b      │   c          │
│   1          │   2      │   3          │
│   hello      │   world  │   !          │
└──────────────┴──────────┴──────────────┘
```

Alignment:

```zig
var str = try table.toString(.{
    .padding = .{ .l = 1, .r = 1 },
    .alignment = .Right,
});
```

```
┌───────────┬───────┬───────────┐
│ Heading 1 │   2   │ Heading 3 │
├───────────┼───────┼───────────┤
│         a │     b │         c │
│         1 │     2 │         3 │
│     hello │ world │         ! │
└───────────┴───────┴───────────┘
```

Equal widths:

```zig
var str = try table.toString(.{
    .padding = .{ .l = 1, .r = 1 },
    .even = true,
});
```

```
┌───────────┬───────────┬───────────┐
│ Heading 1 │     2     │ Heading 3 │
├───────────┼───────────┼───────────┤
│ a         │ b         │ c         │
│ 1         │ 2         │ 3         │
│ hello     │ world     │ !         │
└───────────┴───────────┴───────────┘
```

Outlines:

```zig
var str = try table.toString(.{
    .padding = .{ .l = 1, .r = 1 },
    .even = true,
    .outline = false,
});
```

```
─────────────────────────────────────
  Heading 1       2       Heading 3
─────────────────────────────────────
  a           b           c
  1           2           3
  hello       world       !
─────────────────────────────────────
```

No rule lines at all:

```zig
var str = try table.toString(.{
    .padding = .{ .l = 1, .r = 1 },
    .outline = false,
    .rule = false,
});
```

```
  Heading 1     2     Heading 3
  a           b       c
  1           2       3
  hello       world   !
```

Add indexes:

```zig
var str = try table.toString(.{
    .padding = .{ .l = 1, .r = 1 },
    .index = true,
    .index_str = "Index",
});
```

```
┌───────┬───────────┬───────┬───────────┐
│ Index │ Heading 1 │   2   │ Heading 3 │
├───────┼───────────┼───────┼───────────┤
│ 1     │ a         │ b     │ c         │
│ 2     │ 1         │ 2     │ 3         │
│ 3     │ hello     │ world │ !         │
└───────┴───────────┴───────┴───────────┘
```

Pure ASCII:

```zig
var table = try AsciiTable.initWithHeadings(...)
// ...
var str = try table.toString(.{
    .padding = .{ .l = 1, .r = 1 },
});
```

```
+-------+-----------+-------+-----------+
| Index | Heading 1 |   2   | Heading 3 |
+-------+-----------+-------+-----------+
| 1     | a         | b     | c         |
| 2     | 1         | 2     | 3         |
| 3     | hello     | world | !         |
+-------+-----------+-------+-----------+
```

## Usage

Add the project as a zig dependency in your `build.zig.zon` and add the module to your project.

Initialize a table with some headings, and then add as many rows as you need. Rows are simply `[][]const u8`, which are copied by the table.

```zig
const tisch = @import("tisch");
const Table = tisch.Table;


var headings = [_][]const u8{ "Heading 1", "2", "Heading 3" };
var table = try Table.initWithHeadings(allocator, &headings);
defer table.deinit();

var row1 = [_][]const u8{ "a", "b", "c" };
try table.addRow(&row1);
var row2 = [_][]const u8{ "1", "2", "3" };
try table.addRow(&row2);
var row3 = [_][]const u8{ "hello", "world", "!" };
try table.addRow(&row3);

// print options
var str = try table.toString(
    .{
        .alignment = .Right,
        .even = false,
        .outline = true,
        .rule = true,
        .padding = .{ .r = 2, .l = 2 },
        .index = false,
    },
);
defer allocator.free(str);
```

