const std = @import("std");

pub fn build(builder: *std.build.Builder) void {
    const target = builder.standardTargetOptions(.{});
    const mode = builder.standardReleaseOptions();

    const exe = builder.addExecutable("cidr", "src/main.zig");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const cmd = exe.run();
    cmd.step.dependOn(builder.getInstallStep());
    if (builder.args) |args| {
        cmd.addArgs(args);
    }

    const step = builder.step("run", "Run app");
    step.dependOn(&cmd.step);

    const tests = builder.addTest("src/main.zig");
    tests.setTarget(target);
    tests.setBuildMode(mode);

    const testStep = builder.step("test", "Run tests");
    testStep.dependOn(&tests.step);
}
