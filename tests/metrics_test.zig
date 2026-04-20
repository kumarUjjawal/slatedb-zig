const std = @import("std");
const slatedb = @import("slatedb");

const SpinLock = struct {
    state: std.atomic.Value(u8) = .init(0),

    fn lock(self: *SpinLock) void {
        while (true) {
            if (self.state.cmpxchgWeak(0, 1, .acquire, .monotonic) == null) {
                return;
            }

            while (self.state.load(.monotonic) != 0) {
                std.atomic.spinLoopHint();
            }
        }
    }

    fn unlock(self: *SpinLock) void {
        const previous = self.state.swap(0, .release);
        std.debug.assert(previous != 0);
    }
};

const db_request_count_metric_name = "slatedb.db.request_count";
const db_write_ops_metric_name = "slatedb.db.write_ops";

const RecorderState = struct {
    mutex: SpinLock = .{},
    counters: std.AutoHashMapUnmanaged(u64, u64) = .empty,
    gauges: std.AutoHashMapUnmanaged(u64, i64) = .empty,
    up_down_counters: std.AutoHashMapUnmanaged(u64, i64) = .empty,
    histograms: std.AutoHashMapUnmanaged(u64, std.ArrayListUnmanaged(f64)) = .empty,

    fn deinit(self: *RecorderState, allocator: std.mem.Allocator) void {
        var histogram_iter = self.histograms.iterator();
        while (histogram_iter.next()) |entry| {
            entry.value_ptr.deinit(allocator);
        }

        self.counters.deinit(allocator);
        self.gauges.deinit(allocator);
        self.up_down_counters.deinit(allocator);
        self.histograms.deinit(allocator);
        self.* = .{};
    }

    fn ensureCounter(self: *RecorderState, allocator: std.mem.Allocator, key: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.counters.getOrPut(allocator, key) catch @panic("OOM");
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
    }

    fn ensureGauge(self: *RecorderState, allocator: std.mem.Allocator, key: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.gauges.getOrPut(allocator, key) catch @panic("OOM");
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
    }

    fn ensureUpDownCounter(self: *RecorderState, allocator: std.mem.Allocator, key: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.up_down_counters.getOrPut(allocator, key) catch @panic("OOM");
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
    }

    fn ensureHistogram(self: *RecorderState, allocator: std.mem.Allocator, key: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.histograms.getOrPut(allocator, key) catch @panic("OOM");
        if (!result.found_existing) {
            result.value_ptr.* = .empty;
        }
    }

    fn incrementCounter(self: *RecorderState, key: u64, value: u64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.counters.getOrPut(self.allocatorOrPanic(), key) catch @panic("OOM");
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* += value;
    }

    fn setGauge(self: *RecorderState, key: u64, value: i64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.gauges.getOrPut(self.allocatorOrPanic(), key) catch @panic("OOM");
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* = value;
    }

    fn incrementUpDownCounter(self: *RecorderState, key: u64, value: i64) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.up_down_counters.getOrPut(self.allocatorOrPanic(), key) catch @panic("OOM");
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        result.value_ptr.* += value;
    }

    fn recordHistogram(
        self: *RecorderState,
        allocator: std.mem.Allocator,
        key: u64,
        value: f64,
    ) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const result = self.histograms.getOrPut(allocator, key) catch @panic("OOM");
        if (!result.found_existing) {
            result.value_ptr.* = .empty;
        }
        result.value_ptr.append(allocator, value) catch @panic("OOM");
    }

    fn counterValue(self: *RecorderState, key: u64) ?u64 {
        self.mutex.lock();
        defer self.mutex.unlock();
        return self.counters.get(key);
    }

    fn allocatorOrPanic(_: *RecorderState) std.mem.Allocator {
        return std.heap.smp_allocator;
    }
};

const MetricHandleContext = struct {
    state: *RecorderState,
    key: u64,
    allocator: std.mem.Allocator,
};

const TestMetricsRecorder = struct {
    allocator: std.mem.Allocator = std.heap.smp_allocator,
    state: RecorderState = .{},
    handle_contexts: std.ArrayListUnmanaged(*MetricHandleContext) = .empty,

    fn deinit(self: *TestMetricsRecorder) void {
        for (self.handle_contexts.items) |context| {
            self.allocator.destroy(context);
        }
        self.handle_contexts.deinit(self.allocator);
        self.state.deinit(self.allocator);
        self.* = .{};
    }

    fn toRecorder(self: *TestMetricsRecorder) slatedb.MetricsRecorder {
        return .{
            .context = self,
            .register_counter_fn = registerCounter,
            .register_gauge_fn = registerGauge,
            .register_up_down_counter_fn = registerUpDownCounter,
            .register_histogram_fn = registerHistogram,
        };
    }

    fn counterValue(
        self: *TestMetricsRecorder,
        name: []const u8,
        labels: []const slatedb.MetricLabel,
    ) ?u64 {
        return self.state.counterValue(metricKey(name, labels));
    }

    fn registerCounter(
        context: *anyopaque,
        name: []const u8,
        description: []const u8,
        labels: []const slatedb.MetricLabel,
    ) slatedb.Counter {
        _ = description;

        const self: *TestMetricsRecorder = @ptrCast(@alignCast(context));
        const key = metricKey(name, labels);
        self.state.ensureCounter(self.allocator, key);
        const handle_context = self.newHandleContext(key);
        return slatedb.Counter.init(handle_context, counterIncrement);
    }

    fn registerGauge(
        context: *anyopaque,
        name: []const u8,
        description: []const u8,
        labels: []const slatedb.MetricLabel,
    ) slatedb.Gauge {
        _ = description;

        const self: *TestMetricsRecorder = @ptrCast(@alignCast(context));
        const key = metricKey(name, labels);
        self.state.ensureGauge(self.allocator, key);
        const handle_context = self.newHandleContext(key);
        return slatedb.Gauge.init(handle_context, gaugeSet);
    }

    fn registerUpDownCounter(
        context: *anyopaque,
        name: []const u8,
        description: []const u8,
        labels: []const slatedb.MetricLabel,
    ) slatedb.UpDownCounter {
        _ = description;

        const self: *TestMetricsRecorder = @ptrCast(@alignCast(context));
        const key = metricKey(name, labels);
        self.state.ensureUpDownCounter(self.allocator, key);
        const handle_context = self.newHandleContext(key);
        return slatedb.UpDownCounter.init(handle_context, upDownCounterIncrement);
    }

    fn registerHistogram(
        context: *anyopaque,
        name: []const u8,
        description: []const u8,
        labels: []const slatedb.MetricLabel,
        boundaries: []const f64,
    ) slatedb.Histogram {
        _ = description;
        _ = boundaries;

        const self: *TestMetricsRecorder = @ptrCast(@alignCast(context));
        const key = metricKey(name, labels);
        self.state.ensureHistogram(self.allocator, key);
        const handle_context = self.newHandleContext(key);
        return slatedb.Histogram.init(handle_context, histogramRecord);
    }

    fn newHandleContext(self: *TestMetricsRecorder, key: u64) *MetricHandleContext {
        const context = self.allocator.create(MetricHandleContext) catch @panic("OOM");
        context.* = .{
            .state = &self.state,
            .key = key,
            .allocator = self.allocator,
        };
        self.handle_contexts.append(self.allocator, context) catch @panic("OOM");
        return context;
    }
};

fn metricKey(name: []const u8, labels: []const slatedb.MetricLabel) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(name);
    hasher.update(&[_]u8{0});

    for (labels) |label| {
        hasher.update(label.key);
        hasher.update(&[_]u8{0});
        hasher.update(label.value);
        hasher.update(&[_]u8{0xff});
    }

    return hasher.final();
}

fn counterIncrement(context: *anyopaque, value: u64) void {
    const handle_context: *MetricHandleContext = @ptrCast(@alignCast(context));
    handle_context.state.incrementCounter(handle_context.key, value);
}

fn gaugeSet(context: *anyopaque, value: i64) void {
    const handle_context: *MetricHandleContext = @ptrCast(@alignCast(context));
    handle_context.state.setGauge(handle_context.key, value);
}

fn upDownCounterIncrement(context: *anyopaque, value: i64) void {
    const handle_context: *MetricHandleContext = @ptrCast(@alignCast(context));
    handle_context.state.incrementUpDownCounter(handle_context.key, value);
}

fn histogramRecord(context: *anyopaque, value: f64) void {
    const handle_context: *MetricHandleContext = @ptrCast(@alignCast(context));
    handle_context.state.recordHistogram(handle_context.allocator, handle_context.key, value);
}

fn expectCounterMetric(metric: *const slatedb.Metric, expected: u64) !void {
    switch (metric.value) {
        .counter => |value| try std.testing.expectEqual(expected, value),
        else => return error.TestUnexpectedResult,
    }
}

fn expectHistogramMetric(
    metric: *const slatedb.Metric,
    expected_count: u64,
    expected_sum: f64,
) !void {
    switch (metric.value) {
        .histogram => |histogram| {
            try std.testing.expectEqual(expected_count, histogram.count);
            try std.testing.expectEqual(expected_sum, histogram.sum);
        },
        else => return error.TestUnexpectedResult,
    }
}

fn seedReaderData(store: *slatedb.ObjectStore, path: []const u8) !void {
    var writer_builder = try slatedb.DbBuilder.init(path, store);
    defer writer_builder.deinit();

    var writer = try writer_builder.buildBlocking();
    defer writer.deinit();

    _ = try writer.putBlocking("key1", "value1");
    try writer.flushBlocking();
    try writer.shutdownBlocking();
}

test "DefaultMetricsRecorder snapshot" {
    var recorder = try slatedb.DefaultMetricsRecorder.init();
    defer recorder.deinit();

    const empty_labels = [_]slatedb.MetricLabel{};
    const histogram_boundaries = [_]f64{ 1.0, 2.0 };

    var counter = try recorder.registerCounter("test.counter", "counter", &empty_labels);
    defer counter.deinit();

    var gauge = try recorder.registerGauge("test.gauge", "gauge", &empty_labels);
    defer gauge.deinit();

    var up_down_counter = try recorder.registerUpDownCounter(
        "test.up_down_counter",
        "up/down counter",
        &empty_labels,
    );
    defer up_down_counter.deinit();

    var histogram = try recorder.registerHistogram(
        "test.histogram",
        "histogram",
        &empty_labels,
        &histogram_boundaries,
    );
    defer histogram.deinit();

    try counter.increment(3);
    try gauge.set(-7);
    try up_down_counter.increment(5);
    try up_down_counter.increment(-2);
    try histogram.record(1.5);
    try histogram.record(3.0);

    var metrics_by_name = try recorder.metricsByName(std.testing.allocator, "test.counter");
    defer metrics_by_name.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 1), metrics_by_name.count());

    const maybe_counter_metric = try recorder.metricByNameAndLabels(
        std.testing.allocator,
        "test.counter",
        &empty_labels,
    );
    try std.testing.expect(maybe_counter_metric != null);
    var counter_metric = maybe_counter_metric.?;
    defer counter_metric.deinit(std.testing.allocator);
    try expectCounterMetric(&counter_metric, 3);

    const maybe_histogram_metric = try recorder.metricByNameAndLabels(
        std.testing.allocator,
        "test.histogram",
        &empty_labels,
    );
    try std.testing.expect(maybe_histogram_metric != null);
    var histogram_metric = maybe_histogram_metric.?;
    defer histogram_metric.deinit(std.testing.allocator);
    try expectHistogramMetric(&histogram_metric, 2, 4.5);

    var snapshot = try recorder.snapshot(std.testing.allocator);
    defer snapshot.deinit(std.testing.allocator);
    try std.testing.expect(snapshot.count() >= 4);
}

test "DbBuilder accepts a custom metrics recorder" {
    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var recorder_state = TestMetricsRecorder{};
    defer recorder_state.deinit();
    var recorder = recorder_state.toRecorder();

    var builder = try slatedb.DbBuilder.init("metrics-custom-db", &store);
    defer builder.deinit();
    try builder.withMetricsRecorder(&recorder);

    var db = try builder.buildBlocking();
    defer db.deinit();

    _ = try db.putBlocking("k1", "v1");
    _ = try db.putBlocking("k2", "v2");

    const value = recorder_state.counterValue(db_write_ops_metric_name, &[_]slatedb.MetricLabel{});
    try std.testing.expect(value != null);
    try std.testing.expectEqual(@as(u64, 2), value.?);

    try db.shutdownBlocking();
}

test "DbBuilder accepts the default metrics recorder" {
    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    var recorder = try slatedb.DefaultMetricsRecorder.init();
    defer recorder.deinit();

    var builder = try slatedb.DbBuilder.init("metrics-default-db", &store);
    defer builder.deinit();
    try builder.withMetricsRecorder(&recorder);

    var db = try builder.buildBlocking();
    defer db.deinit();

    _ = try db.putBlocking("k1", "v1");
    _ = try db.putBlocking("k2", "v2");

    const maybe_metric = try recorder.metricByNameAndLabels(
        std.testing.allocator,
        db_write_ops_metric_name,
        &[_]slatedb.MetricLabel{},
    );
    try std.testing.expect(maybe_metric != null);
    var metric = maybe_metric.?;
    defer metric.deinit(std.testing.allocator);
    try expectCounterMetric(&metric, 2);

    try db.shutdownBlocking();
}

test "DbReaderBuilder accepts a custom metrics recorder" {
    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    try seedReaderData(&store, "metrics-custom-reader");

    var recorder_state = TestMetricsRecorder{};
    defer recorder_state.deinit();
    var recorder = recorder_state.toRecorder();

    var builder = try slatedb.DbReaderBuilder.init("metrics-custom-reader", &store);
    defer builder.deinit();
    try builder.withMetricsRecorder(&recorder);

    var reader = try builder.buildBlocking();
    defer reader.deinit();

    const value = try reader.getBlocking(std.testing.allocator, "key1");
    defer if (value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(value != null);
    try std.testing.expectEqualSlices(u8, "value1", value.?);

    const labels = [_]slatedb.MetricLabel{
        .{ .key = "op", .value = "get" },
    };
    const counter_value = recorder_state.counterValue(db_request_count_metric_name, &labels);
    try std.testing.expect(counter_value != null);
    try std.testing.expectEqual(@as(u64, 1), counter_value.?);

    try reader.shutdownBlocking();
}

test "DbReaderBuilder accepts the default metrics recorder" {
    var store = try slatedb.ObjectStore.resolve("memory:///");
    defer store.deinit();

    try seedReaderData(&store, "metrics-default-reader");

    var recorder = try slatedb.DefaultMetricsRecorder.init();
    defer recorder.deinit();

    var builder = try slatedb.DbReaderBuilder.init("metrics-default-reader", &store);
    defer builder.deinit();
    try builder.withMetricsRecorder(&recorder);

    var reader = try builder.buildBlocking();
    defer reader.deinit();

    const value = try reader.getBlocking(std.testing.allocator, "key1");
    defer if (value) |bytes| std.testing.allocator.free(bytes);
    try std.testing.expect(value != null);
    try std.testing.expectEqualSlices(u8, "value1", value.?);

    const labels = [_]slatedb.MetricLabel{
        .{ .key = "op", .value = "get" },
    };
    const maybe_metric = try recorder.metricByNameAndLabels(
        std.testing.allocator,
        db_request_count_metric_name,
        &labels,
    );
    try std.testing.expect(maybe_metric != null);
    var metric = maybe_metric.?;
    defer metric.deinit(std.testing.allocator);
    try expectCounterMetric(&metric, 1);

    try reader.shutdownBlocking();
}
