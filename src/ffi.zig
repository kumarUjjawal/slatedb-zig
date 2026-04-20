const std = @import("std");
const err = @import("error.zig");

pub const c = @cImport({
    @cInclude("slatedb.h");
});

const bindings_contract_version: u32 = 29;

var abi_checked = false;

const checksums = struct {
    const func_init_logging = 20973;
    const constructor_objectstore_resolve = 27737;
    const constructor_dbbuilder_new = 20774;
    const constructor_dbreaderbuilder_new = 63705;
    const constructor_writebatch_new = 25201;
    const method_db_begin = 51275;
    const method_dbbuilder_build = 57780;
    const method_dbbuilder_with_merge_operator = 26367;
    const method_dbbuilder_with_wal_object_store = 59224;
    const method_db_delete = 34129;
    const method_db_delete_with_options = 42509;
    const method_db_flush = 18130;
    const method_db_flush_with_options = 63293;
    const method_db_get = 50068;
    const method_db_get_key_value = 57684;
    const method_db_get_key_value_with_options = 20648;
    const method_db_get_with_options = 20501;
    const method_db_merge = 17999;
    const method_db_merge_with_options = 61231;
    const method_db_metrics = 63278;
    const method_db_put = 59996;
    const method_db_put_with_options = 58268;
    const method_dbreader_get = 22886;
    const method_dbreader_get_with_options = 9133;
    const method_dbreader_scan = 19575;
    const method_dbreader_scan_prefix = 51732;
    const method_dbreader_scan_prefix_with_options = 24990;
    const method_dbreader_scan_with_options = 33406;
    const method_dbreader_shutdown = 33391;
    const method_dbreaderbuilder_build = 3383;
    const method_dbreaderbuilder_with_merge_operator = 54971;
    const method_dbreaderbuilder_with_options = 5765;
    const method_dbreaderbuilder_with_wal_object_store = 15471;
    const method_db_scan = 38146;
    const method_db_scan_prefix = 16589;
    const method_db_scan_prefix_with_options = 37166;
    const method_db_scan_with_options = 57778;
    const method_db_shutdown = 43377;
    const method_db_snapshot = 13313;
    const method_db_status = 55824;
    const method_db_write = 13969;
    const method_db_write_with_options = 34167;
    const method_dbiterator_next = 49160;
    const method_dbiterator_seek = 43547;
    const method_dbsnapshot_get = 37663;
    const method_dbtransaction_commit = 17358;
    const method_dbtransaction_get = 27661;
    const method_dbtransaction_id = 16876;
    const method_dbtransaction_merge = 28294;
    const method_dbtransaction_merge_with_options = 63505;
    const method_dbtransaction_put = 30341;
    const method_dbtransaction_rollback = 23348;
    const method_dbtransaction_seqnum = 60506;
    const method_mergeoperator_merge = 9511;
    const method_walfile_id = 51355;
    const method_walfile_iterator = 50239;
    const method_walfile_metadata = 30832;
    const method_walfile_next_file = 52353;
    const method_walfile_next_id = 60587;
    const method_walfileiterator_next = 18233;
    const method_walreader_get = 40699;
    const method_walreader_list = 62366;
    const method_writebatch_delete = 37032;
    const method_writebatch_merge = 51939;
    const method_writebatch_merge_with_options = 30105;
    const method_writebatch_put = 35694;
    const method_writebatch_put_with_options = 23639;
    const constructor_walreader_new = 791;
};

pub fn ensureCompatible() err.CallError!void {
    if (abi_checked) {
        err.clearLastCallErrorDetail();
        return;
    }

    const contract_version = c.ffi_slatedb_uniffi_uniffi_contract_version();
    if (contract_version != bindings_contract_version) {
        err.rememberContractVersionMismatch(bindings_contract_version, contract_version);
        std.log.err(
            "SlateDB UniFFI contract version mismatch: Zig expects {d}, dylib has {d}",
            .{ bindings_contract_version, contract_version },
        );
        return error.ContractVersionMismatch;
    }

    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_func_init_logging",
        checksums.func_init_logging,
        c.uniffi_slatedb_uniffi_checksum_func_init_logging(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_constructor_objectstore_resolve",
        checksums.constructor_objectstore_resolve,
        c.uniffi_slatedb_uniffi_checksum_constructor_objectstore_resolve(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_constructor_dbbuilder_new",
        checksums.constructor_dbbuilder_new,
        c.uniffi_slatedb_uniffi_checksum_constructor_dbbuilder_new(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_constructor_dbreaderbuilder_new",
        checksums.constructor_dbreaderbuilder_new,
        c.uniffi_slatedb_uniffi_checksum_constructor_dbreaderbuilder_new(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_constructor_writebatch_new",
        checksums.constructor_writebatch_new,
        c.uniffi_slatedb_uniffi_checksum_constructor_writebatch_new(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_begin",
        checksums.method_db_begin,
        c.uniffi_slatedb_uniffi_checksum_method_db_begin(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbbuilder_build",
        checksums.method_dbbuilder_build,
        c.uniffi_slatedb_uniffi_checksum_method_dbbuilder_build(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbbuilder_with_merge_operator",
        checksums.method_dbbuilder_with_merge_operator,
        c.uniffi_slatedb_uniffi_checksum_method_dbbuilder_with_merge_operator(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbbuilder_with_wal_object_store",
        checksums.method_dbbuilder_with_wal_object_store,
        c.uniffi_slatedb_uniffi_checksum_method_dbbuilder_with_wal_object_store(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_delete",
        checksums.method_db_delete,
        c.uniffi_slatedb_uniffi_checksum_method_db_delete(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_delete_with_options",
        checksums.method_db_delete_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_delete_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_flush",
        checksums.method_db_flush,
        c.uniffi_slatedb_uniffi_checksum_method_db_flush(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_flush_with_options",
        checksums.method_db_flush_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_flush_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_get",
        checksums.method_db_get,
        c.uniffi_slatedb_uniffi_checksum_method_db_get(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_get_key_value",
        checksums.method_db_get_key_value,
        c.uniffi_slatedb_uniffi_checksum_method_db_get_key_value(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_get_key_value_with_options",
        checksums.method_db_get_key_value_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_get_key_value_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_get_with_options",
        checksums.method_db_get_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_get_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_merge",
        checksums.method_db_merge,
        c.uniffi_slatedb_uniffi_checksum_method_db_merge(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_merge_with_options",
        checksums.method_db_merge_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_merge_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_metrics",
        checksums.method_db_metrics,
        c.uniffi_slatedb_uniffi_checksum_method_db_metrics(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_put",
        checksums.method_db_put,
        c.uniffi_slatedb_uniffi_checksum_method_db_put(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_put_with_options",
        checksums.method_db_put_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_put_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreader_get",
        checksums.method_dbreader_get,
        c.uniffi_slatedb_uniffi_checksum_method_dbreader_get(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreader_get_with_options",
        checksums.method_dbreader_get_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_dbreader_get_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreader_scan",
        checksums.method_dbreader_scan,
        c.uniffi_slatedb_uniffi_checksum_method_dbreader_scan(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreader_scan_prefix",
        checksums.method_dbreader_scan_prefix,
        c.uniffi_slatedb_uniffi_checksum_method_dbreader_scan_prefix(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreader_scan_prefix_with_options",
        checksums.method_dbreader_scan_prefix_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_dbreader_scan_prefix_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreader_scan_with_options",
        checksums.method_dbreader_scan_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_dbreader_scan_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreader_shutdown",
        checksums.method_dbreader_shutdown,
        c.uniffi_slatedb_uniffi_checksum_method_dbreader_shutdown(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_build",
        checksums.method_dbreaderbuilder_build,
        c.uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_build(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_merge_operator",
        checksums.method_dbreaderbuilder_with_merge_operator,
        c.uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_merge_operator(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_options",
        checksums.method_dbreaderbuilder_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_wal_object_store",
        checksums.method_dbreaderbuilder_with_wal_object_store,
        c.uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_wal_object_store(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_scan",
        checksums.method_db_scan,
        c.uniffi_slatedb_uniffi_checksum_method_db_scan(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_scan_prefix",
        checksums.method_db_scan_prefix,
        c.uniffi_slatedb_uniffi_checksum_method_db_scan_prefix(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_scan_prefix_with_options",
        checksums.method_db_scan_prefix_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_scan_prefix_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_scan_with_options",
        checksums.method_db_scan_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_scan_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_shutdown",
        checksums.method_db_shutdown,
        c.uniffi_slatedb_uniffi_checksum_method_db_shutdown(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_snapshot",
        checksums.method_db_snapshot,
        c.uniffi_slatedb_uniffi_checksum_method_db_snapshot(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_status",
        checksums.method_db_status,
        c.uniffi_slatedb_uniffi_checksum_method_db_status(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_write",
        checksums.method_db_write,
        c.uniffi_slatedb_uniffi_checksum_method_db_write(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_db_write_with_options",
        checksums.method_db_write_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_db_write_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbsnapshot_get",
        checksums.method_dbsnapshot_get,
        c.uniffi_slatedb_uniffi_checksum_method_dbsnapshot_get(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbiterator_next",
        checksums.method_dbiterator_next,
        c.uniffi_slatedb_uniffi_checksum_method_dbiterator_next(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbiterator_seek",
        checksums.method_dbiterator_seek,
        c.uniffi_slatedb_uniffi_checksum_method_dbiterator_seek(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbtransaction_commit",
        checksums.method_dbtransaction_commit,
        c.uniffi_slatedb_uniffi_checksum_method_dbtransaction_commit(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbtransaction_get",
        checksums.method_dbtransaction_get,
        c.uniffi_slatedb_uniffi_checksum_method_dbtransaction_get(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbtransaction_id",
        checksums.method_dbtransaction_id,
        c.uniffi_slatedb_uniffi_checksum_method_dbtransaction_id(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbtransaction_merge",
        checksums.method_dbtransaction_merge,
        c.uniffi_slatedb_uniffi_checksum_method_dbtransaction_merge(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbtransaction_merge_with_options",
        checksums.method_dbtransaction_merge_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_dbtransaction_merge_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbtransaction_put",
        checksums.method_dbtransaction_put,
        c.uniffi_slatedb_uniffi_checksum_method_dbtransaction_put(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbtransaction_rollback",
        checksums.method_dbtransaction_rollback,
        c.uniffi_slatedb_uniffi_checksum_method_dbtransaction_rollback(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_dbtransaction_seqnum",
        checksums.method_dbtransaction_seqnum,
        c.uniffi_slatedb_uniffi_checksum_method_dbtransaction_seqnum(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_mergeoperator_merge",
        checksums.method_mergeoperator_merge,
        c.uniffi_slatedb_uniffi_checksum_method_mergeoperator_merge(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_constructor_walreader_new",
        checksums.constructor_walreader_new,
        c.uniffi_slatedb_uniffi_checksum_constructor_walreader_new(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_walfile_id",
        checksums.method_walfile_id,
        c.uniffi_slatedb_uniffi_checksum_method_walfile_id(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_walfile_iterator",
        checksums.method_walfile_iterator,
        c.uniffi_slatedb_uniffi_checksum_method_walfile_iterator(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_walfile_metadata",
        checksums.method_walfile_metadata,
        c.uniffi_slatedb_uniffi_checksum_method_walfile_metadata(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_walfile_next_file",
        checksums.method_walfile_next_file,
        c.uniffi_slatedb_uniffi_checksum_method_walfile_next_file(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_walfile_next_id",
        checksums.method_walfile_next_id,
        c.uniffi_slatedb_uniffi_checksum_method_walfile_next_id(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_walfileiterator_next",
        checksums.method_walfileiterator_next,
        c.uniffi_slatedb_uniffi_checksum_method_walfileiterator_next(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_walreader_get",
        checksums.method_walreader_get,
        c.uniffi_slatedb_uniffi_checksum_method_walreader_get(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_walreader_list",
        checksums.method_walreader_list,
        c.uniffi_slatedb_uniffi_checksum_method_walreader_list(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_writebatch_delete",
        checksums.method_writebatch_delete,
        c.uniffi_slatedb_uniffi_checksum_method_writebatch_delete(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_writebatch_merge",
        checksums.method_writebatch_merge,
        c.uniffi_slatedb_uniffi_checksum_method_writebatch_merge(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_writebatch_merge_with_options",
        checksums.method_writebatch_merge_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_writebatch_merge_with_options(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_writebatch_put",
        checksums.method_writebatch_put,
        c.uniffi_slatedb_uniffi_checksum_method_writebatch_put(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_writebatch_put_with_options",
        checksums.method_writebatch_put_with_options,
        c.uniffi_slatedb_uniffi_checksum_method_writebatch_put_with_options(),
    );

    abi_checked = true;
    err.clearLastCallErrorDetail();
}

fn expectChecksum(name: []const u8, expected: u16, actual: anytype) err.CallError!void {
    const actual_value: u16 = @intCast(actual);
    if (actual_value != expected) {
        err.rememberApiChecksumMismatch(name, expected, actual_value);
        std.log.err(
            "{s} mismatch: Zig expects {d}, dylib has {d}",
            .{ name, expected, actual_value },
        );
        return error.ApiChecksumMismatch;
    }
}
