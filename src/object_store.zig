const std = @import("std");
const ffi = @import("ffi.zig");
const object_handle = @import("object_handle.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");

pub const ObjectStore = struct {
    handle: object_handle.ObjectHandle,

    pub fn resolve(url: []const u8) rust_call.CallError!ObjectStore {
        try ffi.ensureCompatible();

        const url_buffer = try rust_buffer.RustBuffer.fromBytes(url);
        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const raw = ffi.c.uniffi_slatedb_uniffi_fn_constructor_objectstore_resolve(
            url_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);

        return .{
            .handle = object_handle.ObjectHandle.init(
                raw,
                ffi.c.uniffi_slatedb_uniffi_fn_clone_objectstore,
                ffi.c.uniffi_slatedb_uniffi_fn_free_objectstore,
            ),
        };
    }

    pub fn deinit(self: *ObjectStore) void {
        self.handle.deinit();
    }
};
