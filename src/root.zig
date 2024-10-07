//! A level 1 implementation of [URI Templating](https://datatracker.ietf.org/doc/html/rfc6570)
//! commonly used with declarative REST api specification formats like [OpenAPI](https://spec.openapis.org/oas/v3.1.0.html#path-templating)
const std = @import("std");
const testing = std.testing;

// todo: add to https://github.com/uri-templates/uritemplate-spec/wiki/Implementations

/// A parsed uri template
///
pub const Template = struct {
    const Component = union(enum) {
        raw: []const u8,
        name: []const u8,
    };
    components: []const Component,
    allocator: std.mem.Allocator,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        for (self.components) |c| {
            switch (c) {
                .raw => |r| try writer.writeAll(r),
                .name => |n| {
                    try writer.writeAll("{");
                    try writer.writeAll(n);
                    try writer.writeAll("}");
                },
            }
        }
    }

    pub fn deinit(self: *@This()) void {
        self.allocator.free(self.components);
    }

    fn assertString(f: std.builtin.Type.StructField) void {
        // value must be slice or array of u8
        switch (@typeInfo(f.type)) {
            .Pointer => |p| {
                switch (p.size) {
                    .One => switch (@typeInfo(p.child)) {
                        .Array => |a| if (a.child != u8) {
                            @compileError(
                                "data values must be of type []const u8, '" ++ f.name ++ "' is an containing type " ++ @typeName(p.child),
                            );
                        },
                        else => @compileError(
                            "data values must be of type []const u8, '" ++ f.name ++ "' is of type " ++ @typeName(f.type),
                        ),
                    },
                    .Slice => if (p.child == 8)
                        @compileError(
                            "data values must be of type []const u8, '" ++ f.name ++ "' is of type " ++ @typeName(p.child),
                        ),
                    else => @compileError(
                        "data values must be of type []const u8, '" ++ f.name ++ "' is of type " ++ @typeName(p.child),
                    ),
                }
            },
            else => @compileError(
                "data values must be of type []const u8, '" ++ f.name ++ "' is of type " ++ @typeName(f.type),
            ),
        }
    }

    pub const RenderOptions = struct {
        pub const Encoding = union(enum) {
            /// performs no additional encoding
            none,
            /// percent-encodes reserved characters ALPHA / DIGIT / "-" / "." / "_" / "~"
            reserved,

            fn encode(self: @This(), writer: anytype, value: []const u8) !@TypeOf(writer).Error!void {
                switch (self) {
                    .none => try writer.writeAll(value),
                    .reserved => try std.Uri.Component.percentEncode(writer, value, isUnreserved),
                }
            }

            /// unreserved  = ALPHA / DIGIT / "-" / "." / "_" / "~"
            fn isUnreserved(c: u8) bool {
                return switch (c) {
                    'A'...'Z', 'a'...'z', '0'...'9', '-', '.', '_', '~' => true,
                    else => false,
                };
            }
        };
        /// The type of encoding applied to values when subsituting with placeholders
        encoding: Encoding = .reserved,
    };

    /// Render template to a string with a given struct containing
    /// fields whose names match those of the placeholders of this template
    pub fn render(
        self: @This(),
        writer: anytype,
        data: anytype,
        options: RenderOptions,
    ) !void {
        const T = @TypeOf(data);
        return switch (@typeInfo(T)) {
            .Struct => |s| {
                comptime var names: [s.fields.len]struct { []const u8, []const u8 } = undefined;

                inline for (s.fields, 0..) |f, i| {
                    assertString(f);
                    names[i] = .{ f.name, @field(data, f.name) };
                }
                const lookup = std.StaticStringMap([]const u8).initComptime(names);
                for (self.components) |component| {
                    try switch (component) {
                        .raw => |raw| try writer.writeAll(raw),
                        .name => |name| try if (lookup.get(name)) |value| options.encoding.encode(writer, value) else {
                            std.debug.print("missing data template field named '{s}'\n", .{name});
                            return error.NameMissing;
                        },
                    };
                }
            },
            else => @compileError("expected data to be a Struct but found a " ++ @typeName(@TypeOf(data))),
        };
    }

    /// Render template to a string with a given struct containing
    /// fields whose names match those of the placeholders of this template
    ///
    /// The returned value is expected to be freed by the caller
    pub fn renderAlloc(
        self: @This(),
        allocator: std.mem.Allocator,
        data: anytype,
        options: RenderOptions,
    ) ![]const u8 {
        var rendered = std.ArrayList(u8).init(allocator);
        defer rendered.deinit();
        try self.render(rendered.writer(), data, options);
        return rendered.toOwnedSlice();
    }
};

/// Parse a uri which includes named placeholders surrounded but `{` and `}`
/// into a `Template` which can later be rendered when provided a set of data
/// to fill in those placeholders.
///
/// Callers are expected to deinitialized memory held by that Template by calling `deinit()`
///
/// This function does not validate that the data passed conforms to a valid url.
///
/// This method fails when a `{` character is not matched with a closing `}` character
/// or likewise encouters a `}` character that was not paired with an opening `{` character
pub fn parse(
    allocator: std.mem.Allocator,
    raw: []const u8,
) !Template {
    var components = std.ArrayList(Template.Component).init(allocator);
    defer components.deinit();
    // use express lane if no placeholders are detected
    if (std.mem.indexOfScalar(u8, raw, '{') == null and std.mem.indexOfScalar(u8, raw, '}') == null) {
        try components.append(.{ .raw = raw });
        return .{ .allocator = allocator, .components = try components.toOwnedSlice() };
    }
    var start: usize = 0;
    while (start < raw.len) {
        const remaining = raw[start..];
        if (std.mem.indexOfScalar(u8, remaining, '{')) |open| {
            if (std.mem.indexOfScalar(u8, remaining, '}')) |close| {
                if (open != 0) {
                    try components.append(.{ .raw = remaining[0..open] });
                }
                try components.append(.{ .name = remaining[open + 1 .. close] });
                start += close + 1;
            } else {
                return error.MissingRightBracket;
            }
        } else {
            // no remaining placeholders but we still check for malformed template
            if (std.mem.indexOfScalar(u8, raw[start..], '}')) |_| {
                return error.MissingOpenBracket;
            } else {
                try components.append(.{ .raw = raw[start..] });
                start = raw.len;
            }
        }
    }
    return .{ .allocator = allocator, .components = try components.toOwnedSlice() };
}

test "format" {
    const allocator = std.testing.allocator;
    var template = try parse(allocator, "https://{username}.gigantic-server.com:{port}/{basePath}");
    defer template.deinit();
    try std.testing.expectFmt("https://{username}.gigantic-server.com:{port}/{basePath}", "{}", .{template});
}

test parse {
    const allocator = std.testing.allocator;
    for ([_]struct { template: []const u8, expectError: bool }{
        .{
            .template = "https://{username}.gigantic-server.com:{port}/{basePath}",
            .expectError = false,
        },
        .{
            .template = "{scheme}://{username}.gigantic-server.com:{port}/{basePath}",
            .expectError = false,
        },
        .{
            .template = "{incomplete",
            .expectError = true,
        },
        .{
            .template = "incomplete}",
            .expectError = true,
        },
    }) |case| {
        var result = parse(allocator, case.template);
        if (result) |*parsed| {
            defer parsed.deinit();
            if (case.expectError) {
                std.debug.print("expected '{s}' to return an error by parsed\n", .{case.template});
                return error.ExpectedError;
            }
        } else |err| {
            if (!case.expectError) {
                std.debug.print("not expect '{s}' to return an error failed with {any}\n", .{ case.template, err });
                return error.ExpectedNoError;
            }
        }
    }
}

test "render" {
    const allocator = std.testing.allocator;
    var template = try parse(
        allocator,
        "https://{username}.gigantic-server.com:{port}/{basePath}",
    );
    defer template.deinit();
    const rendered = try template.renderAlloc(allocator, .{
        .username = "foo",
        .port = "8080",
        .basePath = "foo/bar",
    }, .{
        .encoding = .none,
    });
    defer allocator.free(rendered);
    try std.testing.expectEqualStrings(
        "https://foo.gigantic-server.com:8080/foo/bar",
        rendered,
    );
}
