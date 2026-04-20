const std = @import("std");

pub const SpinLock = struct {
    state: std.atomic.Value(u8) = .init(0),

    pub fn lock(self: *SpinLock) void {
        while (true) {
            if (self.state.cmpxchgWeak(0, 1, .acquire, .monotonic) == null) {
                return;
            }

            while (self.state.load(.monotonic) != 0) {
                std.atomic.spinLoopHint();
            }
        }
    }

    pub fn unlock(self: *SpinLock) void {
        const previous = self.state.swap(0, .release);
        std.debug.assert(previous != 0);
    }
};
