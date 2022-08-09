const std = @import("std");
const expectEqual = std.testing.expectEqual;

const NetInfo = struct {
    ip: [4]u8,
    mask: [4]u8,
    cidr: u8,
};

const Error = error{
    InvalidFormat,
    MaskOverflow,
};

fn parseNetMask(mask: u8) [4]u8 {
    var m = mask;
    var net_mask: [4]u8 = .{ 0, 0, 0, 0 };
    var index: usize = 0;
    while (index < 4) : (index += 1) {
        if (mask <= 0) {
            net_mask[index] = 0;
            m = 0;
        } else if (m < 8) {
            const max: u16 = 256 - std.math.pow(u16, 2, 8 - m);
            net_mask[index] = @intCast(u8, max);
            m = 0;
        } else {
            net_mask[index] = 255;
            m -= 8;
        }
    }
    return net_mask;
}

fn parseCIDR(input: []const u8) Error!NetInfo {
    const slash = std.mem.indexOf(u8, input, "/") orelse {
        return Error.InvalidFormat;
    };

    const cidr = std.fmt.parseInt(u8, input[(slash + 1)..], 10) catch {
        return Error.InvalidFormat;
    };
    if (cidr > 32 or cidr < 0) {
        return Error.MaskOverflow;
    }
    const mask = parseNetMask(cidr);
    var segments = std.mem.split(u8, input[0..slash], ".");
    var ip: [4]u8 = undefined;
    var index: usize = 0;

    while (segments.next()) |seg| {
        if (index > 3) {
            return Error.InvalidFormat;
        }
        var num = std.fmt.parseInt(u8, seg, 10) catch {
            return Error.InvalidFormat;
        };
        // IP must be masked
        ip[index] = num & mask[index];
        index += 1;
    }

    return NetInfo{
        .ip = ip,
        .mask = mask,
        .cidr = cidr,
    };
}

fn printHelp() anyerror!void {
    const stderr = std.io.getStdErr().writer();
    try stderr.print("Usage: cidr [cidr_input]\n", .{});
    try stderr.print("cidr_input: must be cidr format like 10.0.0.0/18\n", .{});
}

pub fn main() anyerror!void {
    var allocator = std.heap.page_allocator;

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var cidrMap = std.AutoHashMap(u8, u32).init(allocator);
    defer cidrMap.deinit();

    var cidr: u8 = 1;
    var max: u32 = 2147483648;
    try cidrMap.put(cidr, max);
    cidr += 1;
    while (cidr <= 32) : (cidr += 1) {
        max /= 2;
        try cidrMap.put(cidr, max);
    }

    // discard program arg
    _ = args.next();
    var input = args.next() orelse {
        try printHelp();
        std.os.exit(1);
    };

    var parsed = parseCIDR(input) catch |err| switch (err) {
        Error.InvalidFormat => {
            std.log.err("Invalid CIDR {s}", .{input});
            std.os.exit(1);
        },
        Error.MaskOverflow => {
            std.log.err("CIDR mask overflow: {s}", .{input});
            std.os.exit(1);
        },
        else => {
            std.log.err("Unexpected error: {any}", .{err});
            std.os.exit(1);
        },
    };

    const stdout = std.io.getStdOut().writer();
    try stdout.print("CIDR calculation result\n", .{});
    try stdout.print("{s:=<46}\n", .{""});
    try stdout.print("{s:<14}: {s}\n", .{ "Input", input });
    try stdout.print("{s:<14}: {d}.{d}.{d}.{d}/{d}\n", .{
        "CIDR",
        parsed.ip[0],
        parsed.ip[1],
        parsed.ip[2],
        parsed.ip[3],
        parsed.cidr,
    });
    try stdout.print("{s:<14}: {d}.{d}.{d}.{d}\n", .{
        "NetMask",
        parsed.mask[0],
        parsed.mask[1],
        parsed.mask[2],
        parsed.mask[3],
    });
    try stdout.print("{s:<14}: {d}.{d}.{d}.{d} - {d}.{d}.{d}.{d}\n", .{
        "IP Range",
        parsed.ip[0],
        parsed.ip[1],
        parsed.ip[2],
        parsed.ip[3],
        parsed.ip[0] + (parsed.mask[0] ^ 255),
        parsed.ip[1] + (parsed.mask[1] ^ 255),
        parsed.ip[2] + (parsed.mask[2] ^ 255),
        parsed.ip[3] + (parsed.mask[3] ^ 255),
    });
    try stdout.print("{s:<14}: {d}\n", .{
        "Available IPs",
        cidrMap.get(parsed.cidr).?,
    });
}

test "CIDR parse invalid format" {
    var input = "10.0.0.0.18";
    _ = parseCIDR(input) catch |err| {
        try expectEqual(err, Error.InvalidFormat);
    };
}

test "CIDR parse invalid format2" {
    var input = "10/0.0.0.18";
    _ = parseCIDR(input) catch |err| {
        try expectEqual(err, Error.InvalidFormat);
    };
}

test "CIDR parse mask overflow" {
    var input = "10.0.0.0/36";
    _ = parseCIDR(input) catch |err| {
        try expectEqual(err, Error.MaskOverflow);
    };
}

test "CIDR parse test" {
    var input = "10.0.0.0/18";
    const info = try parseCIDR(input);
    try expectEqual(info.ip, .{ 10, 0, 0, 0 });
    try expectEqual(info.mask, .{ 255, 255, 192, 0 });
}
