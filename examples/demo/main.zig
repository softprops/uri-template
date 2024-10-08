const std = @import("std");
const uritemplate = @import("uritemplate");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var template = try uritemplate.parse(allocator, "https://foo.com/{path}");
    defer template.deinit();

    try template.render(std.io.getStdOut().writer(), .{ .path = "foo bar" }, .{});
}
