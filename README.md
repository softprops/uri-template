<h1 align="center">
    zig uri template
</h1>

<div align="center">
    Zig library for <a href="https://datatracker.ietf.org/doc/html/rfc6570">URI Templating</a>
</div>

---

[![Main](https://github.com/softprops/uri-template/actions/workflows/ci.yml/badge.svg)](https://github.com/softprops/uri-template/actions/workflows/ci.yml) ![License Info](https://img.shields.io/github/license/softprops/uri-template) ![Release](https://img.shields.io/github/v/release/softprops/uri-template) [![Zig Support](https://img.shields.io/badge/zig-0.13.0-black?logo=zig)](https://ziglang.org/documentation/0.13.0/)


## examples

See examples directory

## 📼 installing

Create a new exec project with `zig init` then update `build.zig.zon` by running.

```sh
zig fetch --save https://github.com/softprops/uri-template/archive/refs/tags/v0.1.1.tar.gz
```

> you can also depend any tag with `https://github.com/softprops/uri-template/archive/refs/tags/v{version}.tar.gz` or current main with `https://github.com/softprops/uri-template/archive/refs/heads/main/main.tar.gz`. to resolve a hash omit it and let zig tell you the expected value.

Add the following in your `build.zig` file

```diff
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});
    // 👇 de-reference dep from build.zig.zon
+    const uritemplate = b.dependency("uritemplate", .{
+        .target = target,
+        .optimize = optimize,
+    }).module("uritemplate");
    var exe = b.addExecutable(.{
        .name = "your-exe",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    // 👇 add the module to executable
+    exe.root_mode.addImport("uritemplate", uritemplate);

    b.installArtifact(exe);
}
```

## 🥹 for budding ziglings

Does this look interesting but you're new to zig and feel left out? No problem, zig is young so most us of our new are as well. Here are some resources to help get you up to speed on zig

- [the official zig website](https://ziglang.org/)
- [zig's one-page language documentation](https://ziglang.org/documentation/0.13.0/)
- [ziglearn](https://ziglearn.org/)
- [ziglings exercises](https://github.com/ratfactor/ziglings)


\- softprops 2024
