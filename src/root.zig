//! By convention, root.zig is the root source file when making a library.
const std = @import("std");

const CTArrayError = error {
    CannotReplacePairUntilTwoItemsIterated,
    CannotReplacePairWthoutTwoPreviousItems,
    CannotReplaceAtEndOfIterator,
    CannotReplacePreviousBeforeNextCalled,
    ItemNotFound,
};

pub fn CTArray(comptime T: type) type {
    // Enforce some constraints on T
    if (@typeInfo(T) != .int and @typeInfo(T).int.signedness == .unsigned) {
        @compileError("CTArray can only be used with unsigned int types");
    }

    return struct {
        const Self = @This();

        const bits: usize = @typeInfo(T).int.bits;
        const tombstone_mask: T = 1 << (bits - 1);
        const value_mask: T = ~tombstone_mask;

        items: []T = undefined,

        pub fn init(items: []T) Self {
            return Self {
                .items = items,
            };
        }

        // Find the item index of the previous item
        // taking into account tombstones
        fn find_previous(self: Self, start: T) !T {
            var pos = start - 1;
            while (true) {
                if (pos >= 0 and self.items[pos] & tombstone_mask == 0) {
                    return pos;
                } else {
                    if (pos == 0) {
                        return CTArrayError.ItemNotFound;
                    }
                    pos = pos - 1;
                }
            }
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
                else {
                    self.cta.items[self.current - 1] = replacement;
                }
            }

            // Replace the last two items we delivered with next with a single replacement
            pub fn replace_previous_pair(self: *Iterator, replacement: T) !void {
                if (self.current < 2 ) {
                    return CTArrayError.CannotReplacePairUntilTwoItemsIterated;
                }
                else {
                    const previous = self.cta.find_previous(self.current) 
                        catch return CTArrayError.ItemNotFound;
                    self.cta.items[previous] = replacement;
                    const previous_previous = self.cta.find_previous(previous)
                        catch return CTArrayError.ItemNotFound;

                    self.cta.items[previous_previous] = tombstone_mask | (previous - previous_previous);
                    return;
                }
            }

            pub fn next(self: *Iterator) ?T {
                if (self.current < self.cta.items.len) {
                    while (self.current < self.cta.items.len) {
                        if (self.cta.items[self.current] & tombstone_mask == tombstone_mask) {
                            self.current += (self.cta.items[self.current] & value_mask);
                        }
                        if (self.current == self.cta.items.len) {
                            return null;
                        } else {
                            break;
                        }
                    }
                    const value_to_return = self.cta.items[self.current];

                    self.current += 1;

                    while (self.current < self.cta.items.len and self.cta.items[self.current] & tombstone_mask == tombstone_mask)  {
                        self.current += (self.cta.items[self.current] & value_mask);
                    }

                    return value_to_return & value_mask;
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

test "init with an int slice and replace pair" {
    var test_slice = [_]u8{1,2,3,4,5};
    const cta = CTArray(u8);
    const test_cta = cta.init(&test_slice);
    var iter = test_cta.iterator();
    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(2, iter.next());
    try std.testing.expectEqual(3, iter.next());
    try iter.replace_previous_pair(6);
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(5, iter.next());
    try std.testing.expectEqual(null, iter.next());

    iter = test_cta.iterator();
    try std.testing.expectEqual(1, iter.next());
    try std.testing.expectEqual(6, iter.next());
    try std.testing.expectEqual(4, iter.next());
    try std.testing.expectEqual(5, iter.next());
    try std.testing.expectEqual(null, iter.next());
}

// Uncomment to verify that this won't compile
// test "check you cannot init with a non int slice" {
//     var test_slice = [_][]const u8{"1","2","3","4","5"};
//     const cta = CTArray([] const u8);
//     const test_cta = cta.init(&test_slice);
//     _ = test_cta;
// }
