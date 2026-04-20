const std = @import("std");
const err = @import("error.zig");

pub const c = @cImport({
    @cInclude("slatedb.h");
});

pub const CallbackInterfaceFree = *const fn (u64) callconv(.c) void;
pub const CallbackInterfaceClone = *const fn (u64) callconv(.c) u64;
pub const CallbackInterfaceCounterMethod0 = *const fn (
    u64,
    u64,
    ?*anyopaque,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceLogCallbackMethod0 = *const fn (
    u64,
    c.RustBuffer,
    ?*anyopaque,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceGaugeMethod0 = *const fn (
    u64,
    i64,
    ?*anyopaque,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceMergeOperatorMethod0 = *const fn (
    u64,
    c.RustBuffer,
    c.RustBuffer,
    c.RustBuffer,
    *c.RustBuffer,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceHistogramMethod0 = *const fn (
    u64,
    f64,
    ?*anyopaque,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceMetricsRecorderMethod0 = *const fn (
    u64,
    c.RustBuffer,
    c.RustBuffer,
    c.RustBuffer,
    *u64,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceMetricsRecorderMethod1 = *const fn (
    u64,
    c.RustBuffer,
    c.RustBuffer,
    c.RustBuffer,
    *u64,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceMetricsRecorderMethod2 = *const fn (
    u64,
    c.RustBuffer,
    c.RustBuffer,
    c.RustBuffer,
    *u64,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceMetricsRecorderMethod3 = *const fn (
    u64,
    c.RustBuffer,
    c.RustBuffer,
    c.RustBuffer,
    c.RustBuffer,
    *u64,
    *c.RustCallStatus,
) callconv(.c) void;
pub const CallbackInterfaceUpDownCounterMethod0 = *const fn (
    u64,
    i64,
    ?*anyopaque,
    *c.RustCallStatus,
) callconv(.c) void;

pub const UniffiVTableCallbackInterfaceCounter = extern struct {
    uniffiFree: CallbackInterfaceFree,
    uniffiClone: CallbackInterfaceClone,
    increment: CallbackInterfaceCounterMethod0,
};

pub const UniffiVTableCallbackInterfaceGauge = extern struct {
    uniffiFree: CallbackInterfaceFree,
    uniffiClone: CallbackInterfaceClone,
    set: CallbackInterfaceGaugeMethod0,
};

pub const UniffiVTableCallbackInterfaceLogCallback = extern struct {
    uniffiFree: CallbackInterfaceFree,
    uniffiClone: CallbackInterfaceClone,
    log: CallbackInterfaceLogCallbackMethod0,
};

pub const UniffiVTableCallbackInterfaceHistogram = extern struct {
    uniffiFree: CallbackInterfaceFree,
    uniffiClone: CallbackInterfaceClone,
    record: CallbackInterfaceHistogramMethod0,
};

pub const UniffiVTableCallbackInterfaceMergeOperator = extern struct {
    uniffiFree: CallbackInterfaceFree,
    uniffiClone: CallbackInterfaceClone,
    merge: CallbackInterfaceMergeOperatorMethod0,
};

pub const UniffiVTableCallbackInterfaceMetricsRecorder = extern struct {
    uniffiFree: CallbackInterfaceFree,
    uniffiClone: CallbackInterfaceClone,
    registerCounter: CallbackInterfaceMetricsRecorderMethod0,
    registerGauge: CallbackInterfaceMetricsRecorderMethod1,
    registerUpDownCounter: CallbackInterfaceMetricsRecorderMethod2,
    registerHistogram: CallbackInterfaceMetricsRecorderMethod3,
};

pub const UniffiVTableCallbackInterfaceUpDownCounter = extern struct {
    uniffiFree: CallbackInterfaceFree,
    uniffiClone: CallbackInterfaceClone,
    increment: CallbackInterfaceUpDownCounterMethod0,
};

pub extern fn uniffi_slatedb_uniffi_fn_method_dbbuilder_with_metrics_recorder(
    ptr: u64,
    metrics_recorder: u64,
    out_status: *c.RustCallStatus,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_method_db_status(
    ptr: ?*anyopaque,
    out_status: *c.RustCallStatus,
) c.RustBuffer;
pub extern fn uniffi_slatedb_uniffi_fn_method_dbreaderbuilder_with_metrics_recorder(
    ptr: u64,
    metrics_recorder: u64,
    out_status: *c.RustCallStatus,
) void;

pub extern fn uniffi_slatedb_uniffi_fn_clone_counter(handle: u64, out_status: *c.RustCallStatus) u64;
pub extern fn uniffi_slatedb_uniffi_fn_free_counter(handle: u64, out_status: *c.RustCallStatus) void;
pub extern fn uniffi_slatedb_uniffi_fn_init_callback_vtable_counter(
    vtable: *UniffiVTableCallbackInterfaceCounter,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_method_counter_increment(
    ptr: u64,
    value: u64,
    out_status: *c.RustCallStatus,
) void;

pub extern fn uniffi_slatedb_uniffi_fn_clone_defaultmetricsrecorder(
    handle: u64,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_free_defaultmetricsrecorder(
    handle: u64,
    out_status: *c.RustCallStatus,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_constructor_defaultmetricsrecorder_new(
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_metric_by_name_and_labels(
    ptr: u64,
    name: c.RustBuffer,
    labels: c.RustBuffer,
    out_status: *c.RustCallStatus,
) c.RustBuffer;
pub extern fn uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_metrics_by_name(
    ptr: u64,
    name: c.RustBuffer,
    out_status: *c.RustCallStatus,
) c.RustBuffer;
pub extern fn uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_register_counter(
    ptr: u64,
    name: c.RustBuffer,
    description: c.RustBuffer,
    labels: c.RustBuffer,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_register_gauge(
    ptr: u64,
    name: c.RustBuffer,
    description: c.RustBuffer,
    labels: c.RustBuffer,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_register_histogram(
    ptr: u64,
    name: c.RustBuffer,
    description: c.RustBuffer,
    labels: c.RustBuffer,
    boundaries: c.RustBuffer,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_register_up_down_counter(
    ptr: u64,
    name: c.RustBuffer,
    description: c.RustBuffer,
    labels: c.RustBuffer,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_snapshot(
    ptr: u64,
    out_status: *c.RustCallStatus,
) c.RustBuffer;

pub extern fn uniffi_slatedb_uniffi_fn_clone_gauge(handle: u64, out_status: *c.RustCallStatus) u64;
pub extern fn uniffi_slatedb_uniffi_fn_free_gauge(handle: u64, out_status: *c.RustCallStatus) void;
pub extern fn uniffi_slatedb_uniffi_fn_init_callback_vtable_gauge(
    vtable: *UniffiVTableCallbackInterfaceGauge,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_init_callback_vtable_logcallback(
    vtable: *UniffiVTableCallbackInterfaceLogCallback,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_method_gauge_set(
    ptr: u64,
    value: i64,
    out_status: *c.RustCallStatus,
) void;

pub extern fn uniffi_slatedb_uniffi_fn_clone_histogram(handle: u64, out_status: *c.RustCallStatus) u64;
pub extern fn uniffi_slatedb_uniffi_fn_free_histogram(handle: u64, out_status: *c.RustCallStatus) void;
pub extern fn uniffi_slatedb_uniffi_fn_init_callback_vtable_histogram(
    vtable: *UniffiVTableCallbackInterfaceHistogram,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_init_callback_vtable_mergeoperator(
    vtable: *UniffiVTableCallbackInterfaceMergeOperator,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_method_histogram_record(
    ptr: u64,
    value: f64,
    out_status: *c.RustCallStatus,
) void;

pub extern fn uniffi_slatedb_uniffi_fn_clone_metricsrecorder(
    handle: u64,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_free_metricsrecorder(
    handle: u64,
    out_status: *c.RustCallStatus,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_init_callback_vtable_metricsrecorder(
    vtable: *UniffiVTableCallbackInterfaceMetricsRecorder,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_method_metricsrecorder_register_counter(
    ptr: u64,
    name: c.RustBuffer,
    description: c.RustBuffer,
    labels: c.RustBuffer,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_method_metricsrecorder_register_gauge(
    ptr: u64,
    name: c.RustBuffer,
    description: c.RustBuffer,
    labels: c.RustBuffer,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_method_metricsrecorder_register_up_down_counter(
    ptr: u64,
    name: c.RustBuffer,
    description: c.RustBuffer,
    labels: c.RustBuffer,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_method_metricsrecorder_register_histogram(
    ptr: u64,
    name: c.RustBuffer,
    description: c.RustBuffer,
    labels: c.RustBuffer,
    boundaries: c.RustBuffer,
    out_status: *c.RustCallStatus,
) u64;

pub extern fn uniffi_slatedb_uniffi_fn_clone_updowncounter(
    handle: u64,
    out_status: *c.RustCallStatus,
) u64;
pub extern fn uniffi_slatedb_uniffi_fn_free_updowncounter(
    handle: u64,
    out_status: *c.RustCallStatus,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_init_callback_vtable_updowncounter(
    vtable: *UniffiVTableCallbackInterfaceUpDownCounter,
) void;
pub extern fn uniffi_slatedb_uniffi_fn_method_updowncounter_increment(
    ptr: u64,
    value: i64,
    out_status: *c.RustCallStatus,
) void;

pub extern fn uniffi_slatedb_uniffi_checksum_method_dbbuilder_with_metrics_recorder() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_metrics_recorder() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_constructor_defaultmetricsrecorder_new() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_counter_increment() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_metric_by_name_and_labels() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_metrics_by_name() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_counter() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_gauge() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_histogram() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_up_down_counter() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_snapshot() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_gauge_set() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_histogram_record() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_counter() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_gauge() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_histogram() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_up_down_counter() u16;
pub extern fn uniffi_slatedb_uniffi_checksum_method_updowncounter_increment() u16;

const bindings_contract_version: u32 = 30;

var abi_checked = false;

const checksums = struct {
    const func_init_logging = 43029;
    const constructor_objectstore_resolve = 17196;
    const constructor_dbbuilder_new = 60260;
    const constructor_dbreaderbuilder_new = 20397;
    const constructor_defaultmetricsrecorder_new = 31165;
    const constructor_writebatch_new = 2056;
    const method_db_begin = 38869;
    const method_dbbuilder_build = 18005;
    const method_dbbuilder_with_metrics_recorder = 18128;
    const method_dbbuilder_with_merge_operator = 5839;
    const method_dbbuilder_with_wal_object_store = 4790;
    const method_db_delete = 4063;
    const method_db_delete_with_options = 44744;
    const method_db_flush = 42157;
    const method_db_flush_with_options = 27835;
    const method_db_get = 39474;
    const method_db_get_key_value = 35423;
    const method_db_get_key_value_with_options = 6898;
    const method_db_get_with_options = 20708;
    const method_db_merge = 28366;
    const method_db_merge_with_options = 15865;
    const method_db_put = 53275;
    const method_db_put_with_options = 37591;
    const method_dbreader_get = 53337;
    const method_dbreader_get_with_options = 22247;
    const method_dbreader_scan = 19340;
    const method_dbreader_scan_prefix = 2510;
    const method_dbreader_scan_prefix_with_options = 46251;
    const method_dbreader_scan_with_options = 27137;
    const method_dbreader_shutdown = 34395;
    const method_dbreaderbuilder_build = 11741;
    const method_dbreaderbuilder_with_metrics_recorder = 20032;
    const method_dbreaderbuilder_with_merge_operator = 63455;
    const method_dbreaderbuilder_with_options = 46155;
    const method_dbreaderbuilder_with_wal_object_store = 2290;
    const method_db_scan = 60557;
    const method_db_scan_prefix = 44288;
    const method_db_scan_prefix_with_options = 34774;
    const method_db_scan_with_options = 63326;
    const method_db_shutdown = 3032;
    const method_db_snapshot = 53137;
    const method_db_status = 33776;
    const method_db_write = 29016;
    const method_db_write_with_options = 13580;
    const method_dbiterator_next = 1225;
    const method_dbiterator_seek = 61052;
    const method_dbsnapshot_get = 52436;
    const method_dbtransaction_commit = 56467;
    const method_dbtransaction_get = 4279;
    const method_dbtransaction_id = 33247;
    const method_dbtransaction_merge = 16664;
    const method_dbtransaction_merge_with_options = 17753;
    const method_dbtransaction_put = 56350;
    const method_dbtransaction_rollback = 25213;
    const method_dbtransaction_seqnum = 63575;
    const method_counter_increment = 45426;
    const method_defaultmetricsrecorder_metric_by_name_and_labels = 45073;
    const method_defaultmetricsrecorder_metrics_by_name = 7602;
    const method_defaultmetricsrecorder_register_counter = 51600;
    const method_defaultmetricsrecorder_register_gauge = 34281;
    const method_defaultmetricsrecorder_register_histogram = 4383;
    const method_defaultmetricsrecorder_register_up_down_counter = 19270;
    const method_defaultmetricsrecorder_snapshot = 39221;
    const method_gauge_set = 19642;
    const method_histogram_record = 17863;
    const method_mergeoperator_merge = 48409;
    const method_metricsrecorder_register_counter = 40366;
    const method_metricsrecorder_register_gauge = 30425;
    const method_metricsrecorder_register_histogram = 26503;
    const method_metricsrecorder_register_up_down_counter = 64639;
    const method_updowncounter_increment = 34440;
    const method_walfile_id = 62512;
    const method_walfile_iterator = 46880;
    const method_walfile_metadata = 32912;
    const method_walfile_next_file = 56800;
    const method_walfile_next_id = 48353;
    const method_walfileiterator_next = 51490;
    const method_walreader_get = 11510;
    const method_walreader_list = 43661;
    const method_writebatch_delete = 58549;
    const method_writebatch_merge = 62067;
    const method_writebatch_merge_with_options = 24696;
    const method_writebatch_put = 48246;
    const method_writebatch_put_with_options = 31177;
    const constructor_walreader_new = 30537;
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
        "uniffi_slatedb_uniffi_checksum_constructor_defaultmetricsrecorder_new",
        checksums.constructor_defaultmetricsrecorder_new,
        uniffi_slatedb_uniffi_checksum_constructor_defaultmetricsrecorder_new(),
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
        "uniffi_slatedb_uniffi_checksum_method_dbbuilder_with_metrics_recorder",
        checksums.method_dbbuilder_with_metrics_recorder,
        uniffi_slatedb_uniffi_checksum_method_dbbuilder_with_metrics_recorder(),
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
        "uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_metrics_recorder",
        checksums.method_dbreaderbuilder_with_metrics_recorder,
        uniffi_slatedb_uniffi_checksum_method_dbreaderbuilder_with_metrics_recorder(),
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
        "uniffi_slatedb_uniffi_checksum_method_counter_increment",
        checksums.method_counter_increment,
        uniffi_slatedb_uniffi_checksum_method_counter_increment(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_metric_by_name_and_labels",
        checksums.method_defaultmetricsrecorder_metric_by_name_and_labels,
        uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_metric_by_name_and_labels(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_metrics_by_name",
        checksums.method_defaultmetricsrecorder_metrics_by_name,
        uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_metrics_by_name(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_counter",
        checksums.method_defaultmetricsrecorder_register_counter,
        uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_counter(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_gauge",
        checksums.method_defaultmetricsrecorder_register_gauge,
        uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_gauge(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_histogram",
        checksums.method_defaultmetricsrecorder_register_histogram,
        uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_histogram(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_up_down_counter",
        checksums.method_defaultmetricsrecorder_register_up_down_counter,
        uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_register_up_down_counter(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_snapshot",
        checksums.method_defaultmetricsrecorder_snapshot,
        uniffi_slatedb_uniffi_checksum_method_defaultmetricsrecorder_snapshot(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_gauge_set",
        checksums.method_gauge_set,
        uniffi_slatedb_uniffi_checksum_method_gauge_set(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_histogram_record",
        checksums.method_histogram_record,
        uniffi_slatedb_uniffi_checksum_method_histogram_record(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_mergeoperator_merge",
        checksums.method_mergeoperator_merge,
        c.uniffi_slatedb_uniffi_checksum_method_mergeoperator_merge(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_counter",
        checksums.method_metricsrecorder_register_counter,
        uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_counter(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_gauge",
        checksums.method_metricsrecorder_register_gauge,
        uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_gauge(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_histogram",
        checksums.method_metricsrecorder_register_histogram,
        uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_histogram(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_up_down_counter",
        checksums.method_metricsrecorder_register_up_down_counter,
        uniffi_slatedb_uniffi_checksum_method_metricsrecorder_register_up_down_counter(),
    );
    try expectChecksum(
        "uniffi_slatedb_uniffi_checksum_method_updowncounter_increment",
        checksums.method_updowncounter_increment,
        uniffi_slatedb_uniffi_checksum_method_updowncounter_increment(),
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
