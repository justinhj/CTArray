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
