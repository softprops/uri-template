const std = @import("std");
const urltemplate = @import("root.zig");
const benchmark = @import("benchmark");

test "bench" {
    try benchmark.main(.{}, struct {
        pub fn parse(b: *benchmark.B) !void {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            while (b.step()) {
                var template = try urltemplate.parse(
                    arena.allocator(),
                    "https://{username}.gigantic-server.com:{port}/{basePath}",
                );
                defer template.deinit();

                b.use(template);
            }
        }
        pub fn render(b: *benchmark.B) !void {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();
            var template = try urltemplate.parse(
                arena.allocator(),
                "https://{username}.gigantic-server.com:{port}/{basePath}",
            );
            defer template.deinit();

            while (b.step()) {
                const rendered = try template.renderAlloc(
                    arena.allocator(),
                    .{
                        .username = "test",
                        .port = "8080",
                        .basePath = "foo/bar",
                    },
                    .{},
                );
                defer arena.allocator().free(rendered);
                b.use(rendered);
            }
        }
    })();
}
