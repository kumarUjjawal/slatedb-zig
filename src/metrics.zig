const std = @import("std");
const callback_handle_map = @import("callback_handle_map.zig");
const codec = @import("codec.zig");
const ffi = @import("ffi.zig");
const rust_buffer = @import("rust_buffer.zig");
const rust_call = @import("rust_call.zig");
const spin_lock = @import("spin_lock.zig");
const u64_handle = @import("u64_handle.zig");

pub const IntMetric = struct {
    name: []u8,
    value: i64,
};

pub const IntMetricsSnapshot = struct {
    entries: []IntMetric = &.{},

    pub fn count(self: *const IntMetricsSnapshot) usize {
        return self.entries.len;
    }

    pub fn get(self: *const IntMetricsSnapshot, name: []const u8) ?i64 {
        for (self.entries) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry.value;
            }
        }
        return null;
    }

    pub fn deinit(self: *IntMetricsSnapshot, allocator: std.mem.Allocator) void {
        for (self.entries) |entry| {
            allocator.free(entry.name);
        }
        if (self.entries.len > 0) {
            allocator.free(self.entries);
        }
        self.* = .{};
    }
};

pub const MetricLabel = struct {
    key: []const u8,
    value: []const u8,

    pub fn deinit(self: *MetricLabel, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        allocator.free(self.value);
        self.* = undefined;
    }
};

pub const HistogramMetricValue = struct {
    count: u64,
    sum: f64,
    min: f64,
    max: f64,
    boundaries: []f64 = &.{},
    bucket_counts: []u64 = &.{},

    pub fn deinit(self: *HistogramMetricValue, allocator: std.mem.Allocator) void {
        if (self.boundaries.len > 0) {
            allocator.free(self.boundaries);
        }
        if (self.bucket_counts.len > 0) {
            allocator.free(self.bucket_counts);
        }
        self.* = undefined;
    }
};

pub const MetricValue = union(enum) {
    counter: u64,
    gauge: i64,
    up_down_counter: i64,
    histogram: HistogramMetricValue,

    pub fn deinit(self: *MetricValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .counter, .gauge, .up_down_counter => {},
            .histogram => |*value| value.deinit(allocator),
        }
        self.* = undefined;
    }
};

pub const Metric = struct {
    name: []const u8,
    labels: []MetricLabel = &.{},
    description: []const u8,
    value: MetricValue,

    pub fn deinit(self: *Metric, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.labels) |*label| {
            label.deinit(allocator);
        }
        if (self.labels.len > 0) {
            allocator.free(self.labels);
        }
        allocator.free(self.description);
        self.value.deinit(allocator);
        self.* = undefined;
    }
};

pub const MetricList = struct {
    entries: []Metric = &.{},

    pub fn count(self: *const MetricList) usize {
        return self.entries.len;
    }

    pub fn deinit(self: *MetricList, allocator: std.mem.Allocator) void {
        for (self.entries) |*metric| {
            metric.deinit(allocator);
        }
        if (self.entries.len > 0) {
            allocator.free(self.entries);
        }
        self.* = .{};
    }
};

const LoweredHandle = struct {
    raw: u64,
    rust_free_fn: ?u64_handle.FreeFn = null,
    callback_discard_fn: ?*const fn (u64) void = null,

    pub fn discard(self: LoweredHandle) void {
        if (self.callback_discard_fn) |discard_fn| {
            discard_fn(self.raw);
            return;
        }

        if (self.rust_free_fn) |free_fn| {
            var status = std.mem.zeroes(ffi.c.RustCallStatus);
            free_fn(self.raw, &status);
            rust_call.checkStatusSilent(status) catch |call_err| {
                std.log.err("failed to free transferred SlateDB handle: {s}", .{@errorName(call_err)});
            };
        }
    }
};

const RustCounter = struct {
    handle: u64_handle.U64Handle,

    fn increment(self: *const RustCounter, value: u64) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const raw = try @constCast(&self.handle).beginRustCall();
        defer @constCast(&self.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.uniffi_slatedb_uniffi_fn_method_counter_increment(raw, value, &status);
        try rust_call.checkStatus(status);
    }
};

const CounterCallback = struct {
    context: *anyopaque,
    increment_fn: *const fn (context: *anyopaque, value: u64) void,

    fn increment(self: *const CounterCallback, value: u64) void {
        self.increment_fn(self.context, value);
    }
};

pub const Counter = union(enum) {
    callback: CounterCallback,
    rust: RustCounter,

    pub fn init(
        context: *anyopaque,
        increment_fn: *const fn (context: *anyopaque, value: u64) void,
    ) Counter {
        return .{
            .callback = .{
                .context = context,
                .increment_fn = increment_fn,
            },
        };
    }

    pub fn increment(self: *const Counter, value: u64) rust_call.CallError!void {
        switch (self.*) {
            .callback => |callback| callback.increment(value),
            .rust => |*rust_handle| try rust_handle.increment(value),
        }
    }

    pub fn deinit(self: *Counter) void {
        switch (self.*) {
            .callback => {},
            .rust => |*rust_handle| rust_handle.handle.deinit(),
        }
        self.* = undefined;
    }
};

const RustGauge = struct {
    handle: u64_handle.U64Handle,

    fn set(self: *const RustGauge, value: i64) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const raw = try @constCast(&self.handle).beginRustCall();
        defer @constCast(&self.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.uniffi_slatedb_uniffi_fn_method_gauge_set(raw, value, &status);
        try rust_call.checkStatus(status);
    }
};

const GaugeCallback = struct {
    context: *anyopaque,
    set_fn: *const fn (context: *anyopaque, value: i64) void,

    fn set(self: *const GaugeCallback, value: i64) void {
        self.set_fn(self.context, value);
    }
};

pub const Gauge = union(enum) {
    callback: GaugeCallback,
    rust: RustGauge,

    pub fn init(
        context: *anyopaque,
        set_fn: *const fn (context: *anyopaque, value: i64) void,
    ) Gauge {
        return .{
            .callback = .{
                .context = context,
                .set_fn = set_fn,
            },
        };
    }

    pub fn set(self: *const Gauge, value: i64) rust_call.CallError!void {
        switch (self.*) {
            .callback => |callback| callback.set(value),
            .rust => |*rust_handle| try rust_handle.set(value),
        }
    }

    pub fn deinit(self: *Gauge) void {
        switch (self.*) {
            .callback => {},
            .rust => |*rust_handle| rust_handle.handle.deinit(),
        }
        self.* = undefined;
    }
};

const RustUpDownCounter = struct {
    handle: u64_handle.U64Handle,

    fn increment(self: *const RustUpDownCounter, value: i64) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const raw = try @constCast(&self.handle).beginRustCall();
        defer @constCast(&self.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.uniffi_slatedb_uniffi_fn_method_updowncounter_increment(raw, value, &status);
        try rust_call.checkStatus(status);
    }
};

const UpDownCounterCallback = struct {
    context: *anyopaque,
    increment_fn: *const fn (context: *anyopaque, value: i64) void,

    fn increment(self: *const UpDownCounterCallback, value: i64) void {
        self.increment_fn(self.context, value);
    }
};

pub const UpDownCounter = union(enum) {
    callback: UpDownCounterCallback,
    rust: RustUpDownCounter,

    pub fn init(
        context: *anyopaque,
        increment_fn: *const fn (context: *anyopaque, value: i64) void,
    ) UpDownCounter {
        return .{
            .callback = .{
                .context = context,
                .increment_fn = increment_fn,
            },
        };
    }

    pub fn increment(self: *const UpDownCounter, value: i64) rust_call.CallError!void {
        switch (self.*) {
            .callback => |callback| callback.increment(value),
            .rust => |*rust_handle| try rust_handle.increment(value),
        }
    }

    pub fn deinit(self: *UpDownCounter) void {
        switch (self.*) {
            .callback => {},
            .rust => |*rust_handle| rust_handle.handle.deinit(),
        }
        self.* = undefined;
    }
};

const RustHistogram = struct {
    handle: u64_handle.U64Handle,

    fn record(self: *const RustHistogram, value: f64) rust_call.CallError!void {
        try ffi.ensureCompatible();

        const raw = try @constCast(&self.handle).beginRustCall();
        defer @constCast(&self.handle).finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        ffi.uniffi_slatedb_uniffi_fn_method_histogram_record(raw, value, &status);
        try rust_call.checkStatus(status);
    }
};

const HistogramCallback = struct {
    context: *anyopaque,
    record_fn: *const fn (context: *anyopaque, value: f64) void,

    fn record(self: *const HistogramCallback, value: f64) void {
        self.record_fn(self.context, value);
    }
};

pub const Histogram = union(enum) {
    callback: HistogramCallback,
    rust: RustHistogram,

    pub fn init(
        context: *anyopaque,
        record_fn: *const fn (context: *anyopaque, value: f64) void,
    ) Histogram {
        return .{
            .callback = .{
                .context = context,
                .record_fn = record_fn,
            },
        };
    }

    pub fn record(self: *const Histogram, value: f64) rust_call.CallError!void {
        switch (self.*) {
            .callback => |callback| callback.record(value),
            .rust => |*rust_handle| try rust_handle.record(value),
        }
    }

    pub fn deinit(self: *Histogram) void {
        switch (self.*) {
            .callback => {},
            .rust => |*rust_handle| rust_handle.handle.deinit(),
        }
        self.* = undefined;
    }
};

pub const MetricsRecorder = struct {
    // `context` must stay valid for as long as Rust may hold metric handles and
    // invoke recorder callbacks. Rust can call these callbacks from worker
    // threads, so shared state behind `context` must be thread-safe.
    context: *anyopaque,
    register_counter_fn: *const fn (
        context: *anyopaque,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) Counter,
    register_gauge_fn: *const fn (
        context: *anyopaque,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) Gauge,
    register_up_down_counter_fn: *const fn (
        context: *anyopaque,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) UpDownCounter,
    register_histogram_fn: *const fn (
        context: *anyopaque,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
        boundaries: []const f64,
    ) Histogram,

    fn registerCounter(
        self: *const MetricsRecorder,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) Counter {
        return self.register_counter_fn(self.context, name, description, labels);
    }

    fn registerGauge(
        self: *const MetricsRecorder,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) Gauge {
        return self.register_gauge_fn(self.context, name, description, labels);
    }

    fn registerUpDownCounter(
        self: *const MetricsRecorder,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) UpDownCounter {
        return self.register_up_down_counter_fn(self.context, name, description, labels);
    }

    fn registerHistogram(
        self: *const MetricsRecorder,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
        boundaries: []const f64,
    ) Histogram {
        return self.register_histogram_fn(
            self.context,
            name,
            description,
            labels,
            boundaries,
        );
    }
};

pub const DefaultMetricsRecorder = struct {
    handle: u64_handle.U64Handle,

    pub fn init() rust_call.CallError!DefaultMetricsRecorder {
        try ffi.ensureCompatible();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const raw = ffi.uniffi_slatedb_uniffi_fn_constructor_defaultmetricsrecorder_new(&status);
        try rust_call.checkStatus(status);

        return .{
            .handle = u64_handle.U64Handle.init(
                raw,
                ffi.uniffi_slatedb_uniffi_fn_clone_defaultmetricsrecorder,
                ffi.uniffi_slatedb_uniffi_fn_free_defaultmetricsrecorder,
            ),
        };
    }

    pub fn snapshot(
        self: *DefaultMetricsRecorder,
        allocator: std.mem.Allocator,
    ) (std.mem.Allocator.Error || rust_call.CallError)!MetricList {
        try ffi.ensureCompatible();

        const raw = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        var result_buffer = rust_buffer.RustBuffer{
            .raw = ffi.uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_snapshot(
                raw,
                &status,
            ),
        };
        defer result_buffer.deinit();
        try rust_call.checkStatus(status);

        var reader = codec.BufferReader.init(result_buffer.bytes());
        var metrics = try decodeMetricList(allocator, &reader);
        errdefer metrics.deinit(allocator);
        try reader.finish();
        return metrics;
    }

    pub fn metricsByName(
        self: *DefaultMetricsRecorder,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) (std.mem.Allocator.Error || rust_call.CallError)!MetricList {
        try ffi.ensureCompatible();

        const raw = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const name_buffer = try rust_buffer.RustBuffer.fromBytes(name);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        var result_buffer = rust_buffer.RustBuffer{
            .raw = ffi.uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_metrics_by_name(
                raw,
                name_buffer.raw,
                &status,
            ),
        };
        defer result_buffer.deinit();
        try rust_call.checkStatus(status);

        var reader = codec.BufferReader.init(result_buffer.bytes());
        var metrics = try decodeMetricList(allocator, &reader);
        errdefer metrics.deinit(allocator);
        try reader.finish();
        return metrics;
    }

    pub fn metricByNameAndLabels(
        self: *DefaultMetricsRecorder,
        allocator: std.mem.Allocator,
        name: []const u8,
        labels: []const MetricLabel,
    ) (std.mem.Allocator.Error || rust_call.CallError)!?Metric {
        try ffi.ensureCompatible();

        const raw = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const name_buffer = try rust_buffer.RustBuffer.fromBytes(name);
        const labels_buffer = try encodeMetricLabels(labels);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        var result_buffer = rust_buffer.RustBuffer{
            .raw = ffi.uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_metric_by_name_and_labels(
                raw,
                name_buffer.raw,
                labels_buffer.raw,
                &status,
            ),
        };
        defer result_buffer.deinit();
        try rust_call.checkStatus(status);

        var reader = codec.BufferReader.init(result_buffer.bytes());
        const metric = try decodeOptionalMetric(allocator, &reader);
        if (metric) |value| {
            errdefer {
                var owned_metric = value;
                owned_metric.deinit(allocator);
            }
        }
        try reader.finish();
        return metric;
    }

    pub fn registerCounter(
        self: *DefaultMetricsRecorder,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) (std.mem.Allocator.Error || rust_call.CallError)!Counter {
        try ffi.ensureCompatible();

        const raw = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const name_buffer = try rust_buffer.RustBuffer.fromBytes(name);
        const description_buffer = try rust_buffer.RustBuffer.fromBytes(description);
        const labels_buffer = try encodeMetricLabels(labels);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const handle = ffi.uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_register_counter(
            raw,
            name_buffer.raw,
            description_buffer.raw,
            labels_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
        return counterFromRaw(handle);
    }

    pub fn registerGauge(
        self: *DefaultMetricsRecorder,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) (std.mem.Allocator.Error || rust_call.CallError)!Gauge {
        try ffi.ensureCompatible();

        const raw = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const name_buffer = try rust_buffer.RustBuffer.fromBytes(name);
        const description_buffer = try rust_buffer.RustBuffer.fromBytes(description);
        const labels_buffer = try encodeMetricLabels(labels);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const handle = ffi.uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_register_gauge(
            raw,
            name_buffer.raw,
            description_buffer.raw,
            labels_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
        return gaugeFromRaw(handle);
    }

    pub fn registerUpDownCounter(
        self: *DefaultMetricsRecorder,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) (std.mem.Allocator.Error || rust_call.CallError)!UpDownCounter {
        try ffi.ensureCompatible();

        const raw = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const name_buffer = try rust_buffer.RustBuffer.fromBytes(name);
        const description_buffer = try rust_buffer.RustBuffer.fromBytes(description);
        const labels_buffer = try encodeMetricLabels(labels);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const handle = ffi.uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_register_up_down_counter(
            raw,
            name_buffer.raw,
            description_buffer.raw,
            labels_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
        return upDownCounterFromRaw(handle);
    }

    pub fn registerHistogram(
        self: *DefaultMetricsRecorder,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
        boundaries: []const f64,
    ) (std.mem.Allocator.Error || rust_call.CallError)!Histogram {
        try ffi.ensureCompatible();

        const raw = try self.handle.beginRustCall();
        defer self.handle.finishRustCall();

        const name_buffer = try rust_buffer.RustBuffer.fromBytes(name);
        const description_buffer = try rust_buffer.RustBuffer.fromBytes(description);
        const labels_buffer = try encodeMetricLabels(labels);
        const boundaries_buffer = try encodeF64Slice(boundaries);

        var status = std.mem.zeroes(ffi.c.RustCallStatus);
        const handle = ffi.uniffi_slatedb_uniffi_fn_method_defaultmetricsrecorder_register_histogram(
            raw,
            name_buffer.raw,
            description_buffer.raw,
            labels_buffer.raw,
            boundaries_buffer.raw,
            &status,
        );
        try rust_call.checkStatus(status);
        return histogramFromRaw(handle);
    }

    pub fn deinit(self: *DefaultMetricsRecorder) void {
        self.handle.deinit();
    }
};

var metrics_recorder_handles: callback_handle_map.HandleMap(MetricsRecorderHandle) = .{};
var counter_handles: callback_handle_map.HandleMap(CounterCallback) = .{};
var gauge_handles: callback_handle_map.HandleMap(GaugeCallback) = .{};
var up_down_counter_handles: callback_handle_map.HandleMap(UpDownCounterCallback) = .{};
var histogram_handles: callback_handle_map.HandleMap(HistogramCallback) = .{};

var metrics_recorder_vtable_registered = false;
var counter_vtable_registered = false;
var gauge_vtable_registered = false;
var up_down_counter_vtable_registered = false;
var histogram_vtable_registered = false;

var metrics_recorder_vtable_mutex: spin_lock.SpinLock = .{};
var counter_vtable_mutex: spin_lock.SpinLock = .{};
var gauge_vtable_mutex: spin_lock.SpinLock = .{};
var up_down_counter_vtable_mutex: spin_lock.SpinLock = .{};
var histogram_vtable_mutex: spin_lock.SpinLock = .{};

var metrics_recorder_vtable = ffi.UniffiVTableCallbackInterfaceMetricsRecorder{
    .uniffiFree = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderFree),
    .uniffiClone = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderClone),
    .registerCounter = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderMethod0),
    .registerGauge = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderMethod1),
    .registerUpDownCounter = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderMethod2),
    .registerHistogram = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderMethod3),
};

var counter_vtable = ffi.UniffiVTableCallbackInterfaceCounter{
    .uniffiFree = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceCounterFree),
    .uniffiClone = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceCounterClone),
    .increment = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceCounterMethod0),
};

var gauge_vtable = ffi.UniffiVTableCallbackInterfaceGauge{
    .uniffiFree = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceGaugeFree),
    .uniffiClone = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceGaugeClone),
    .set = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceGaugeMethod0),
};

var up_down_counter_vtable = ffi.UniffiVTableCallbackInterfaceUpDownCounter{
    .uniffiFree = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceUpDownCounterFree),
    .uniffiClone = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceUpDownCounterClone),
    .increment = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceUpDownCounterMethod0),
};

var histogram_vtable = ffi.UniffiVTableCallbackInterfaceHistogram{
    .uniffiFree = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceHistogramFree),
    .uniffiClone = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceHistogramClone),
    .record = @ptrCast(&slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceHistogramMethod0),
};

const MetricsRecorderHandle = union(enum) {
    callback: MetricsRecorder,
    default_recorder: *DefaultMetricsRecorder,

    fn registerCounter(
        self: MetricsRecorderHandle,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) (std.mem.Allocator.Error || rust_call.CallError)!Counter {
        return switch (self) {
            .callback => |recorder| recorder.registerCounter(name, description, labels),
            .default_recorder => |recorder| recorder.registerCounter(name, description, labels),
        };
    }

    fn registerGauge(
        self: MetricsRecorderHandle,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) (std.mem.Allocator.Error || rust_call.CallError)!Gauge {
        return switch (self) {
            .callback => |recorder| recorder.registerGauge(name, description, labels),
            .default_recorder => |recorder| recorder.registerGauge(name, description, labels),
        };
    }

    fn registerUpDownCounter(
        self: MetricsRecorderHandle,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
    ) (std.mem.Allocator.Error || rust_call.CallError)!UpDownCounter {
        return switch (self) {
            .callback => |recorder| recorder.registerUpDownCounter(name, description, labels),
            .default_recorder => |recorder| recorder.registerUpDownCounter(name, description, labels),
        };
    }

    fn registerHistogram(
        self: MetricsRecorderHandle,
        name: []const u8,
        description: []const u8,
        labels: []const MetricLabel,
        boundaries: []const f64,
    ) (std.mem.Allocator.Error || rust_call.CallError)!Histogram {
        return switch (self) {
            .callback => |recorder| recorder.registerHistogram(
                name,
                description,
                labels,
                boundaries,
            ),
            .default_recorder => |recorder| recorder.registerHistogram(
                name,
                description,
                labels,
                boundaries,
            ),
        };
    }
};

pub fn lowerMetricsRecorder(
    recorder: anytype,
) (std.mem.Allocator.Error || rust_call.CallError)!LoweredHandle {
    const T = @TypeOf(recorder);
    if (T == *MetricsRecorder or T == *const MetricsRecorder) {
        return lowerCallbackMetricsRecorder(recorder);
    }
    if (T == *DefaultMetricsRecorder or T == *const DefaultMetricsRecorder) {
        return lowerDefaultMetricsRecorder(recorder);
    }
    @compileError("withMetricsRecorder expects *MetricsRecorder or *DefaultMetricsRecorder");
}

fn lowerCallbackMetricsRecorder(
    recorder: anytype,
) std.mem.Allocator.Error!LoweredHandle {
    ensureMetricsRecorderVTableRegistered();
    const handle = try metrics_recorder_handles.insert(
        std.heap.smp_allocator,
        .{ .callback = recorder.* },
    );
    return .{
        .raw = handle,
        .callback_discard_fn = discardLoweredMetricsRecorder,
    };
}

fn lowerDefaultMetricsRecorder(
    recorder: anytype,
) std.mem.Allocator.Error!LoweredHandle {
    ensureMetricsRecorderVTableRegistered();
    const handle = try metrics_recorder_handles.insert(
        std.heap.smp_allocator,
        .{ .default_recorder = @constCast(recorder) },
    );
    return .{
        .raw = handle,
        .callback_discard_fn = discardLoweredMetricsRecorder,
    };
}

fn lowerCounter(counter: Counter) (std.mem.Allocator.Error || rust_call.CallError)!LoweredHandle {
    return switch (counter) {
        .callback => |callback| blk: {
            ensureCounterVTableRegistered();
            const handle = try counter_handles.insert(std.heap.smp_allocator, callback);
            break :blk .{
                .raw = handle,
                .callback_discard_fn = discardLoweredCounter,
            };
        },
        .rust => |rust_handle| .{
            .raw = try @constCast(&rust_handle.handle).cloneForTransfer(),
            .rust_free_fn = ffi.uniffi_slatedb_uniffi_fn_free_counter,
        },
    };
}

fn lowerGauge(gauge: Gauge) (std.mem.Allocator.Error || rust_call.CallError)!LoweredHandle {
    return switch (gauge) {
        .callback => |callback| blk: {
            ensureGaugeVTableRegistered();
            const handle = try gauge_handles.insert(std.heap.smp_allocator, callback);
            break :blk .{
                .raw = handle,
                .callback_discard_fn = discardLoweredGauge,
            };
        },
        .rust => |rust_handle| .{
            .raw = try @constCast(&rust_handle.handle).cloneForTransfer(),
            .rust_free_fn = ffi.uniffi_slatedb_uniffi_fn_free_gauge,
        },
    };
}

fn lowerUpDownCounter(
    counter: UpDownCounter,
) (std.mem.Allocator.Error || rust_call.CallError)!LoweredHandle {
    return switch (counter) {
        .callback => |callback| blk: {
            ensureUpDownCounterVTableRegistered();
            const handle = try up_down_counter_handles.insert(std.heap.smp_allocator, callback);
            break :blk .{
                .raw = handle,
                .callback_discard_fn = discardLoweredUpDownCounter,
            };
        },
        .rust => |rust_handle| .{
            .raw = try @constCast(&rust_handle.handle).cloneForTransfer(),
            .rust_free_fn = ffi.uniffi_slatedb_uniffi_fn_free_updowncounter,
        },
    };
}

fn lowerHistogram(
    histogram: Histogram,
) (std.mem.Allocator.Error || rust_call.CallError)!LoweredHandle {
    return switch (histogram) {
        .callback => |callback| blk: {
            ensureHistogramVTableRegistered();
            const handle = try histogram_handles.insert(std.heap.smp_allocator, callback);
            break :blk .{
                .raw = handle,
                .callback_discard_fn = discardLoweredHistogram,
            };
        },
        .rust => |rust_handle| .{
            .raw = try @constCast(&rust_handle.handle).cloneForTransfer(),
            .rust_free_fn = ffi.uniffi_slatedb_uniffi_fn_free_histogram,
        },
    };
}

fn discardLoweredMetricsRecorder(handle: u64) void {
    metrics_recorder_handles.remove(handle);
}

fn discardLoweredCounter(handle: u64) void {
    counter_handles.remove(handle);
}

fn discardLoweredGauge(handle: u64) void {
    gauge_handles.remove(handle);
}

fn discardLoweredUpDownCounter(handle: u64) void {
    up_down_counter_handles.remove(handle);
}

fn discardLoweredHistogram(handle: u64) void {
    histogram_handles.remove(handle);
}

fn ensureMetricsRecorderVTableRegistered() void {
    metrics_recorder_vtable_mutex.lock();
    defer metrics_recorder_vtable_mutex.unlock();

    if (metrics_recorder_vtable_registered) {
        return;
    }

    ffi.uniffi_slatedb_uniffi_fn_init_callback_vtable_metricsrecorder(&metrics_recorder_vtable);
    metrics_recorder_vtable_registered = true;
}

fn ensureCounterVTableRegistered() void {
    counter_vtable_mutex.lock();
    defer counter_vtable_mutex.unlock();

    if (counter_vtable_registered) {
        return;
    }

    ffi.uniffi_slatedb_uniffi_fn_init_callback_vtable_counter(&counter_vtable);
    counter_vtable_registered = true;
}

fn ensureGaugeVTableRegistered() void {
    gauge_vtable_mutex.lock();
    defer gauge_vtable_mutex.unlock();

    if (gauge_vtable_registered) {
        return;
    }

    ffi.uniffi_slatedb_uniffi_fn_init_callback_vtable_gauge(&gauge_vtable);
    gauge_vtable_registered = true;
}

fn ensureUpDownCounterVTableRegistered() void {
    up_down_counter_vtable_mutex.lock();
    defer up_down_counter_vtable_mutex.unlock();

    if (up_down_counter_vtable_registered) {
        return;
    }

    ffi.uniffi_slatedb_uniffi_fn_init_callback_vtable_updowncounter(&up_down_counter_vtable);
    up_down_counter_vtable_registered = true;
}

fn ensureHistogramVTableRegistered() void {
    histogram_vtable_mutex.lock();
    defer histogram_vtable_mutex.unlock();

    if (histogram_vtable_registered) {
        return;
    }

    ffi.uniffi_slatedb_uniffi_fn_init_callback_vtable_histogram(&histogram_vtable);
    histogram_vtable_registered = true;
}

fn decodeMetricLabel(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!MetricLabel {
    const key = try codec.decodeOwnedString(allocator, reader);
    errdefer allocator.free(key);

    const value = try codec.decodeOwnedString(allocator, reader);
    errdefer allocator.free(value);

    return .{
        .key = key,
        .value = value,
    };
}

fn decodeMetricLabels(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)![]MetricLabel {
    const len = try reader.readI32();
    if (len < 0) {
        return unexpectedRustBufferData();
    }

    const count: usize = @intCast(len);
    var labels: []MetricLabel = &.{};
    if (count > 0) {
        labels = try allocator.alloc(MetricLabel, count);
    }
    errdefer if (labels.len > 0) allocator.free(labels);

    var initialized: usize = 0;
    errdefer {
        for (labels[0..initialized]) |*label| {
            label.deinit(allocator);
        }
    }

    while (initialized < count) {
        labels[initialized] = try decodeMetricLabel(allocator, reader);
        initialized += 1;
    }

    return labels;
}

fn decodeF64Slice(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)![]f64 {
    const len = try reader.readI32();
    if (len < 0) {
        return unexpectedRustBufferData();
    }

    const count: usize = @intCast(len);
    var values: []f64 = &.{};
    if (count > 0) {
        values = try allocator.alloc(f64, count);
    }

    for (values, 0..) |*value, index| {
        _ = index;
        value.* = try reader.readF64();
    }
    return values;
}

fn decodeU64Slice(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)![]u64 {
    const len = try reader.readI32();
    if (len < 0) {
        return unexpectedRustBufferData();
    }

    const count: usize = @intCast(len);
    var values: []u64 = &.{};
    if (count > 0) {
        values = try allocator.alloc(u64, count);
    }

    for (values, 0..) |*value, index| {
        _ = index;
        value.* = try reader.readU64();
    }
    return values;
}

fn decodeHistogramMetricValue(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!HistogramMetricValue {
    const count = try reader.readU64();
    const sum = try reader.readF64();
    const min = try reader.readF64();
    const max = try reader.readF64();

    const boundaries = try decodeF64Slice(allocator, reader);
    errdefer if (boundaries.len > 0) allocator.free(boundaries);

    const bucket_counts = try decodeU64Slice(allocator, reader);
    errdefer if (bucket_counts.len > 0) allocator.free(bucket_counts);

    return .{
        .count = count,
        .sum = sum,
        .min = min,
        .max = max,
        .boundaries = boundaries,
        .bucket_counts = bucket_counts,
    };
}

fn decodeMetricValue(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!MetricValue {
    return switch (try reader.readI32()) {
        1 => .{ .counter = try reader.readU64() },
        2 => .{ .gauge = try reader.readI64() },
        3 => .{ .up_down_counter = try reader.readI64() },
        4 => .{ .histogram = try decodeHistogramMetricValue(allocator, reader) },
        else => unexpectedEnumTag(),
    };
}

fn decodeMetric(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!Metric {
    const name = try codec.decodeOwnedString(allocator, reader);
    errdefer allocator.free(name);

    const labels = try decodeMetricLabels(allocator, reader);
    errdefer {
        for (labels) |*label| {
            label.deinit(allocator);
        }
        if (labels.len > 0) {
            allocator.free(labels);
        }
    }

    const description = try codec.decodeOwnedString(allocator, reader);
    errdefer allocator.free(description);

    const value = try decodeMetricValue(allocator, reader);
    var value_needs_free = true;
    errdefer if (value_needs_free) {
        var owned_value = value;
        owned_value.deinit(allocator);
    };

    value_needs_free = false;
    return .{
        .name = name,
        .labels = labels,
        .description = description,
        .value = value,
    };
}

fn decodeMetricList(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!MetricList {
    const len = try reader.readI32();
    if (len < 0) {
        return unexpectedRustBufferData();
    }

    const count: usize = @intCast(len);
    var entries: []Metric = &.{};
    if (count > 0) {
        entries = try allocator.alloc(Metric, count);
    }
    errdefer if (entries.len > 0) allocator.free(entries);

    var initialized: usize = 0;
    errdefer {
        for (entries[0..initialized]) |*metric| {
            metric.deinit(allocator);
        }
    }

    while (initialized < count) {
        entries[initialized] = try decodeMetric(allocator, reader);
        initialized += 1;
    }

    return .{ .entries = entries };
}

fn decodeOptionalMetric(
    allocator: std.mem.Allocator,
    reader: *codec.BufferReader,
) (std.mem.Allocator.Error || rust_call.CallError)!?Metric {
    return switch (try reader.readInt8()) {
        0 => null,
        1 => @as(?Metric, try decodeMetric(allocator, reader)),
        else => unexpectedEnumTag(),
    };
}

const EncodingWriter = struct {
    bytes: []u8,
    pos: usize = 0,

    fn init(bytes: []u8) EncodingWriter {
        return .{ .bytes = bytes };
    }

    fn writeI32(self: *EncodingWriter, value: i32) void {
        var encoded: [4]u8 = undefined;
        std.mem.writeInt(i32, &encoded, value, .big);
        @memcpy(self.bytes[self.pos .. self.pos + 4], &encoded);
        self.pos += 4;
    }

    fn writeU64(self: *EncodingWriter, value: u64) void {
        var encoded: [8]u8 = undefined;
        std.mem.writeInt(u64, &encoded, value, .big);
        @memcpy(self.bytes[self.pos .. self.pos + 8], &encoded);
        self.pos += 8;
    }

    fn writeF64(self: *EncodingWriter, value: f64) void {
        self.writeU64(@bitCast(value));
    }

    fn writeString(self: *EncodingWriter, value: []const u8) rust_call.CallError!void {
        if (value.len > std.math.maxInt(i32)) {
            return bufferTooLarge(value.len);
        }

        self.writeI32(@intCast(value.len));
        @memcpy(self.bytes[self.pos .. self.pos + value.len], value);
        self.pos += value.len;
    }
};

fn metricLabelEncodedLen(label: MetricLabel) rust_call.CallError!usize {
    var total: usize = 0;
    total += try stringEncodedLen(label.key);
    total += try stringEncodedLen(label.value);
    return total;
}

fn stringEncodedLen(value: []const u8) rust_call.CallError!usize {
    if (value.len > std.math.maxInt(i32)) {
        return bufferTooLarge(value.len);
    }
    return 4 + value.len;
}

fn encodeMetricLabels(
    labels: []const MetricLabel,
) (std.mem.Allocator.Error || rust_call.CallError)!rust_buffer.RustBuffer {
    if (labels.len > std.math.maxInt(i32)) {
        return bufferTooLarge(labels.len);
    }

    var total_len: usize = 4;
    for (labels) |label| {
        total_len += try metricLabelEncodedLen(label);
    }

    const encoded = try std.heap.page_allocator.alloc(u8, total_len);
    defer std.heap.page_allocator.free(encoded);

    var writer = EncodingWriter.init(encoded);
    writer.writeI32(@intCast(labels.len));
    for (labels) |label| {
        try writer.writeString(label.key);
        try writer.writeString(label.value);
    }

    if (writer.pos != encoded.len) {
        return error.Internal;
    }

    return rust_buffer.RustBuffer.fromBytes(encoded);
}

fn encodeF64Slice(
    values: []const f64,
) (std.mem.Allocator.Error || rust_call.CallError)!rust_buffer.RustBuffer {
    if (values.len > std.math.maxInt(i32)) {
        return bufferTooLarge(values.len);
    }

    const total_len = 4 + (values.len * 8);
    const encoded = try std.heap.page_allocator.alloc(u8, total_len);
    defer std.heap.page_allocator.free(encoded);

    var writer = EncodingWriter.init(encoded);
    writer.writeI32(@intCast(values.len));
    for (values) |value| {
        writer.writeF64(value);
    }

    return rust_buffer.RustBuffer.fromBytes(encoded);
}

fn counterFromRaw(raw: u64) Counter {
    return .{
        .rust = .{
            .handle = u64_handle.U64Handle.init(
                raw,
                ffi.uniffi_slatedb_uniffi_fn_clone_counter,
                ffi.uniffi_slatedb_uniffi_fn_free_counter,
            ),
        },
    };
}

fn gaugeFromRaw(raw: u64) Gauge {
    return .{
        .rust = .{
            .handle = u64_handle.U64Handle.init(
                raw,
                ffi.uniffi_slatedb_uniffi_fn_clone_gauge,
                ffi.uniffi_slatedb_uniffi_fn_free_gauge,
            ),
        },
    };
}

fn upDownCounterFromRaw(raw: u64) UpDownCounter {
    return .{
        .rust = .{
            .handle = u64_handle.U64Handle.init(
                raw,
                ffi.uniffi_slatedb_uniffi_fn_clone_updowncounter,
                ffi.uniffi_slatedb_uniffi_fn_free_updowncounter,
            ),
        },
    };
}

fn histogramFromRaw(raw: u64) Histogram {
    return .{
        .rust = .{
            .handle = u64_handle.U64Handle.init(
                raw,
                ffi.uniffi_slatedb_uniffi_fn_clone_histogram,
                ffi.uniffi_slatedb_uniffi_fn_free_histogram,
            ),
        },
    };
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceCounterMethod0(
    uniffi_handle: u64,
    value: u64,
    uniffi_out_return: ?*anyopaque,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    _ = uniffi_out_return;
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);

    const counter = counter_handles.get(uniffi_handle) orelse {
        std.log.err("missing SlateDB counter handle {d}", .{uniffi_handle});
        call_status.code = 2;
        return;
    };
    counter.increment(value);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceCounterFree(
    handle: u64,
) callconv(.c) void {
    counter_handles.remove(handle);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceCounterClone(
    handle: u64,
) callconv(.c) u64 {
    const counter = counter_handles.get(handle) orelse {
        std.log.err("missing SlateDB counter handle {d}", .{handle});
        return 0;
    };
    return counter_handles.insert(std.heap.smp_allocator, counter) catch 0;
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceGaugeMethod0(
    uniffi_handle: u64,
    value: i64,
    uniffi_out_return: ?*anyopaque,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    _ = uniffi_out_return;
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);

    const gauge = gauge_handles.get(uniffi_handle) orelse {
        std.log.err("missing SlateDB gauge handle {d}", .{uniffi_handle});
        call_status.code = 2;
        return;
    };
    gauge.set(value);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceGaugeFree(
    handle: u64,
) callconv(.c) void {
    gauge_handles.remove(handle);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceGaugeClone(
    handle: u64,
) callconv(.c) u64 {
    const gauge = gauge_handles.get(handle) orelse {
        std.log.err("missing SlateDB gauge handle {d}", .{handle});
        return 0;
    };
    return gauge_handles.insert(std.heap.smp_allocator, gauge) catch 0;
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceUpDownCounterMethod0(
    uniffi_handle: u64,
    value: i64,
    uniffi_out_return: ?*anyopaque,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    _ = uniffi_out_return;
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);

    const counter = up_down_counter_handles.get(uniffi_handle) orelse {
        std.log.err("missing SlateDB up/down counter handle {d}", .{uniffi_handle});
        call_status.code = 2;
        return;
    };
    counter.increment(value);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceUpDownCounterFree(
    handle: u64,
) callconv(.c) void {
    up_down_counter_handles.remove(handle);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceUpDownCounterClone(
    handle: u64,
) callconv(.c) u64 {
    const counter = up_down_counter_handles.get(handle) orelse {
        std.log.err("missing SlateDB up/down counter handle {d}", .{handle});
        return 0;
    };
    return up_down_counter_handles.insert(std.heap.smp_allocator, counter) catch 0;
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceHistogramMethod0(
    uniffi_handle: u64,
    value: f64,
    uniffi_out_return: ?*anyopaque,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    _ = uniffi_out_return;
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);

    const histogram = histogram_handles.get(uniffi_handle) orelse {
        std.log.err("missing SlateDB histogram handle {d}", .{uniffi_handle});
        call_status.code = 2;
        return;
    };
    histogram.record(value);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceHistogramFree(
    handle: u64,
) callconv(.c) void {
    histogram_handles.remove(handle);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceHistogramClone(
    handle: u64,
) callconv(.c) u64 {
    const histogram = histogram_handles.get(handle) orelse {
        std.log.err("missing SlateDB histogram handle {d}", .{handle});
        return 0;
    };
    return histogram_handles.insert(std.heap.smp_allocator, histogram) catch 0;
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderMethod0(
    uniffi_handle: u64,
    name: ffi.c.RustBuffer,
    description: ffi.c.RustBuffer,
    labels: ffi.c.RustBuffer,
    uniffi_out_return: *u64,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);
    dispatchMetricsRecorderCallback(
        uniffi_handle,
        name,
        description,
        labels,
        null,
        uniffi_out_return,
        call_status,
        .counter,
    );
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderMethod1(
    uniffi_handle: u64,
    name: ffi.c.RustBuffer,
    description: ffi.c.RustBuffer,
    labels: ffi.c.RustBuffer,
    uniffi_out_return: *u64,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);
    dispatchMetricsRecorderCallback(
        uniffi_handle,
        name,
        description,
        labels,
        null,
        uniffi_out_return,
        call_status,
        .gauge,
    );
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderMethod2(
    uniffi_handle: u64,
    name: ffi.c.RustBuffer,
    description: ffi.c.RustBuffer,
    labels: ffi.c.RustBuffer,
    uniffi_out_return: *u64,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);
    dispatchMetricsRecorderCallback(
        uniffi_handle,
        name,
        description,
        labels,
        null,
        uniffi_out_return,
        call_status,
        .up_down_counter,
    );
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderMethod3(
    uniffi_handle: u64,
    name: ffi.c.RustBuffer,
    description: ffi.c.RustBuffer,
    labels: ffi.c.RustBuffer,
    boundaries: ffi.c.RustBuffer,
    uniffi_out_return: *u64,
    call_status: *ffi.c.RustCallStatus,
) callconv(.c) void {
    call_status.* = std.mem.zeroes(ffi.c.RustCallStatus);
    dispatchMetricsRecorderCallback(
        uniffi_handle,
        name,
        description,
        labels,
        boundaries,
        uniffi_out_return,
        call_status,
        .histogram,
    );
}

const MetricsRecorderMethod = enum {
    counter,
    gauge,
    up_down_counter,
    histogram,
};

fn dispatchMetricsRecorderCallback(
    uniffi_handle: u64,
    name: ffi.c.RustBuffer,
    description: ffi.c.RustBuffer,
    labels: ffi.c.RustBuffer,
    maybe_boundaries: ?ffi.c.RustBuffer,
    uniffi_out_return: *u64,
    call_status: *ffi.c.RustCallStatus,
    method: MetricsRecorderMethod,
) void {
    const recorder = metrics_recorder_handles.get(uniffi_handle) orelse {
        std.log.err("missing SlateDB metrics recorder handle {d}", .{uniffi_handle});
        call_status.code = 2;
        return;
    };

    var name_buffer = rust_buffer.RustBuffer{ .raw = name };
    defer name_buffer.deinit();
    const decoded_name = name_buffer.bytes();

    var description_buffer = rust_buffer.RustBuffer{ .raw = description };
    defer description_buffer.deinit();
    const decoded_description = description_buffer.bytes();

    var labels_buffer = rust_buffer.RustBuffer{ .raw = labels };
    defer labels_buffer.deinit();
    var labels_reader = codec.BufferReader.init(labels_buffer.bytes());
    const decoded_labels = decodeMetricLabels(std.heap.smp_allocator, &labels_reader) catch |decode_err| {
        std.log.err("failed to decode SlateDB metric labels: {s}", .{@errorName(decode_err)});
        call_status.code = 2;
        return;
    };
    defer {
        for (decoded_labels) |*label| {
            label.deinit(std.heap.smp_allocator);
        }
        if (decoded_labels.len > 0) {
            std.heap.smp_allocator.free(decoded_labels);
        }
    }
    labels_reader.finish() catch |decode_err| {
        std.log.err("SlateDB metric labels had trailing data: {s}", .{@errorName(decode_err)});
        call_status.code = 2;
        return;
    };

    switch (method) {
        .counter => {
            var counter = recorder.registerCounter(
                decoded_name,
                decoded_description,
                decoded_labels,
            ) catch |call_err| {
                std.log.err("failed to create SlateDB counter callback handle: {s}", .{@errorName(call_err)});
                call_status.code = 2;
                return;
            };
            defer counter.deinit();

            const lowered = lowerCounter(counter) catch |lower_err| {
                std.log.err("failed to lower SlateDB counter callback handle: {s}", .{@errorName(lower_err)});
                call_status.code = 2;
                return;
            };
            uniffi_out_return.* = lowered.raw;
        },
        .gauge => {
            var gauge = recorder.registerGauge(
                decoded_name,
                decoded_description,
                decoded_labels,
            ) catch |call_err| {
                std.log.err("failed to create SlateDB gauge callback handle: {s}", .{@errorName(call_err)});
                call_status.code = 2;
                return;
            };
            defer gauge.deinit();

            const lowered = lowerGauge(gauge) catch |lower_err| {
                std.log.err("failed to lower SlateDB gauge callback handle: {s}", .{@errorName(lower_err)});
                call_status.code = 2;
                return;
            };
            uniffi_out_return.* = lowered.raw;
        },
        .up_down_counter => {
            var counter = recorder.registerUpDownCounter(
                decoded_name,
                decoded_description,
                decoded_labels,
            ) catch |call_err| {
                std.log.err("failed to create SlateDB up/down counter callback handle: {s}", .{@errorName(call_err)});
                call_status.code = 2;
                return;
            };
            defer counter.deinit();

            const lowered = lowerUpDownCounter(counter) catch |lower_err| {
                std.log.err("failed to lower SlateDB up/down counter callback handle: {s}", .{@errorName(lower_err)});
                call_status.code = 2;
                return;
            };
            uniffi_out_return.* = lowered.raw;
        },
        .histogram => {
            const boundaries = decodeBoundaries(maybe_boundaries.?) catch |decode_err| {
                std.log.err("failed to decode SlateDB histogram boundaries: {s}", .{@errorName(decode_err)});
                call_status.code = 2;
                return;
            };
            defer if (boundaries.len > 0) std.heap.smp_allocator.free(boundaries);

            var histogram = recorder.registerHistogram(
                decoded_name,
                decoded_description,
                decoded_labels,
                boundaries,
            ) catch |call_err| {
                std.log.err("failed to create SlateDB histogram callback handle: {s}", .{@errorName(call_err)});
                call_status.code = 2;
                return;
            };
            defer histogram.deinit();

            const lowered = lowerHistogram(histogram) catch |lower_err| {
                std.log.err("failed to lower SlateDB histogram callback handle: {s}", .{@errorName(lower_err)});
                call_status.code = 2;
                return;
            };
            uniffi_out_return.* = lowered.raw;
        },
    }
}

fn decodeBoundaries(
    boundaries: ffi.c.RustBuffer,
) (std.mem.Allocator.Error || rust_call.CallError)![]f64 {
    var boundaries_buffer = rust_buffer.RustBuffer{ .raw = boundaries };
    defer boundaries_buffer.deinit();

    var reader = codec.BufferReader.init(boundaries_buffer.bytes());
    const decoded = try decodeF64Slice(std.heap.smp_allocator, &reader);
    errdefer if (decoded.len > 0) std.heap.smp_allocator.free(decoded);
    try reader.finish();
    return decoded;
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderFree(
    handle: u64,
) callconv(.c) void {
    metrics_recorder_handles.remove(handle);
}

pub export fn slatedb_uniffi_metrics_cgo_dispatchCallbackInterfaceMetricsRecorderClone(
    handle: u64,
) callconv(.c) u64 {
    const recorder = metrics_recorder_handles.get(handle) orelse {
        std.log.err("missing SlateDB metrics recorder handle {d}", .{handle});
        return 0;
    };
    return metrics_recorder_handles.insert(std.heap.smp_allocator, recorder) catch 0;
}

fn bufferTooLarge(len: usize) rust_call.CallError {
    const max_len = std.math.maxInt(i32);
    @import("error.zig").rememberBufferTooLarge(len, max_len);
    return error.BufferTooLarge;
}

fn unexpectedEnumTag() rust_call.CallError {
    @import("error.zig").rememberUnexpectedEnumTag();
    return error.UnexpectedEnumTag;
}

fn unexpectedRustBufferData() rust_call.CallError {
    @import("error.zig").rememberUnexpectedRustBufferData();
    return error.UnexpectedRustBufferData;
}
