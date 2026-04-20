# slatedb-zig

`slatedb-zig` is a community Zig binding for
[SlateDB](https://github.com/slatedb/slatedb).

It is a handwritten Zig wrapper over the UniFFI C ABI exposed by upstream
`slatedb-uniffi`. It does not change SlateDB internals and it does not need a
custom UniFFI generator for Zig.

This is not an official SlateDB binding.

## Status

- community binding repo
- pinned to Zig `0.16.0`
- CI is pinned to upstream SlateDB commit `46543bff2c577440e2daf2315cf926671cb9cc5e`
- checked-in UniFFI header in `include/slatedb.h`
- async API built on Zig `std.Io.Future`
- blocking helpers for the same operations

## Current Coverage

The binding currently covers:

- object store resolve
- DB builder and reader builder
- get, put, delete, merge, write, flush, shutdown, and status
- scan and iterators
- reader API
- write batches
- transactions
- snapshots
- option structs and option-based methods
- typed call error details
- built-in metrics snapshot
- logging callback
- merge operator callback
- WAL reader

Still missing:

- custom metrics recorder callbacks

## Repo Layout

- `src/` has the Zig binding
- `include/slatedb.h` is the checked-in UniFFI C header
- `tests/` mirrors the upstream binding test shape
- `scripts/generate-header.sh` regenerates the checked-in header from an
  upstream SlateDB checkout

## Requirements

- Zig `0.16.0`
- Rust toolchain
- C toolchain
- `uniffi-bindgen-go` `v0.7.0+v0.31.0` if you want to regenerate the header
- a SlateDB checkout with the `slatedb-uniffi` crate

## Local Development

By default, this repo expects a SlateDB checkout at `../slatedb`.

Build the upstream shared library:

```bash
cargo build --manifest-path ../slatedb/Cargo.toml -p slatedb-uniffi
```

Regenerate the checked-in header:

```bash
./scripts/generate-header.sh ../slatedb
```

Run the Zig tests:

```bash
LD_LIBRARY_PATH=$(realpath ../slatedb/target/debug) zig build test -Dupstream_dir=../slatedb
```

On macOS, use `DYLD_LIBRARY_PATH` instead of `LD_LIBRARY_PATH`.

If your SlateDB checkout lives somewhere else, set the path explicitly:

```bash
zig build test -Dupstream_dir=/absolute/path/to/slatedb
```

You can also point straight at the compiled library directory:

```bash
zig build test -Dslatedb_lib_dir=/absolute/path/to/slatedb/target/debug
```

## Using The Package

The package exposes the module name `slatedb`.

Example `build.zig` snippet:

```zig
const dep = b.dependency("slatedb_zig", .{
    .target = target,
    .optimize = optimize,
    .upstream_dir = "/path/to/slatedb",
});

exe.root_module.addImport("slatedb", dep.module("slatedb"));
```

Your program still needs access to the upstream `libslatedb_uniffi` shared
library at build time and runtime.

## Example App

A checked-in smoke example lives in `examples/` and uses the same flow as the
basic package smoke test:

- resolve an in-memory object store
- build a DB
- put a key
- read it back
- shut the DB down cleanly

Run it with:

```bash
cargo build --manifest-path ../slatedb/Cargo.toml -p slatedb-uniffi
zig build example -Dupstream_dir=../slatedb
```

If your SlateDB checkout lives somewhere else, pass that path with
`-Dupstream_dir=/absolute/path/to/slatedb`.

## Header Regeneration

The header is generated from the upstream shared library with
`uniffi-bindgen-go`. The generated Go output is thrown away. Only the C header
is kept.

Install the generator with:

```bash
cargo install uniffi-bindgen-go --git https://github.com/NordSecurity/uniffi-bindgen-go --tag v0.7.0+v0.31.0
```

## CI

GitHub Actions checks:

- header regeneration stays clean
- Zig tests pass on Linux and macOS against a pinned upstream SlateDB commit

## Releases

GitHub releases are cut from `v*` tags after the same header and test checks
pass on Linux and macOS.

## License

Apache-2.0. See `LICENSE` and `NOTICE`.
