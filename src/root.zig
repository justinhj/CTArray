//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const CTArrayError = error {
    CannotReplacePreviousBeforeNextCalled,
    CannotReplaceAtEndOfIterator,
};

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

            // Replace the last item we delivered with next
            pub fn replace_previous(self: *Iterator, replacement: T) !void {
                if (self.current == 0) {
                    return CTArrayError.CannotReplacePreviousBeforeNextCalled;
                }
                else if (self.current <= self.cta.items.len) {
                    self.cta.items[self.current - 1] = replacement;
                }
            }

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

test "init with an int slice and iterate it" {
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

test "Init slice and replace middle element" {
    var test_slice = [_]u8{1,2,3,4,5};
    const cta = CTArray(u8);
    var test_cta = cta.init(&test_slice);
    var iter = test_cta.iterator();
    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try iter.replace_previous(6);
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(5, iter.next());
    try std.testing.expectEqual(null, iter.next());
    
    iter = test_cta.iterator();
    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(6, iter.next());
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(5, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

test "Init slice and replace single element" {
    var test_slice = [_]u8{1};
    const cta = CTArray(u8);
    var test_cta = cta.init(&test_slice);
    var iter = test_cta.iterator();
    try std.testing.expectEqual(1, iter.next());
    try iter.replace_previous(6);
    try std.testing.expectEqual(null, iter.next());
    
    iter = test_cta.iterator();
    try std.testing.expectEqual(6, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

test "init with an int slice and replace first and last elements" {
    var test_slice = [_]u8{1,2,3,4,5};
    const cta = CTArray(u8);
    const test_cta = cta.init(&test_slice);
    var iter = test_cta.iterator();
    try std.testing.expectEqual(1, iter.next());
    try iter.replace_previous(6);
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(5, iter.next());
    try iter.replace_previous(7);
    try std.testing.expectEqual(null, iter.next());

    iter = test_cta.iterator();
    try std.testing.expectEqual(6, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(7, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

// Uncomment to verify that this won't compile
// test "check you cannot init with a non int slice" {
//     var test_slice = [_][]const u8{"1","2","3","4","5"};
//     const cta = CTArray([] const u8);
//     const test_cta = cta.init(&test_slice);
//     _ = test_cta;
// }
