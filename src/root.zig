//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

pub fn CTArray(comptime T: type) type {
    // Enforce some constraints on T
    if (@typeInfo(T) != .int) {
        @compileError("CTArray can only be used with int types");
    }

    return struct {
        const Self = @This();

        items: []T = undefined,
        pub fn init(items: []T) Self {
            return Self {
                .items = items,
            };
        }

        pub fn iterator(self: Self) Iterator {
            return Iterator{
                .current = 0,
                .cta = self,
            };
        }

        pub const Iterator = struct {
            current: T,
            cta: Self,

            pub fn next(self: *Iterator) ?T {
                if (self.current < self.cta.items.len) {
                    const value_to_return = self.cta.items[self.current];
                    self.current += 1;
                    return value_to_return;
                } else {
                    return null;
                }
            }
        };
    };
}


pub fn bufferedPrint() !void {
    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try stdout.flush(); // Don't forget to flush!
}

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

test "check you can init with an int slice and iterate it" {
    var test_slice = [_]u8{1,2,3,4,5};
    const cta = CTArray(u8);
    const test_cta = cta.init(&test_slice);
    var iter = test_cta.iterator();
    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(5, iter.next());
    try std.testing.expectEqual(null, iter.next());
}
