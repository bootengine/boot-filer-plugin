const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{
        // if you're using WASI, change the .os_tag to .wasi
        .default_target = .{ .abi = .musl, .os_tag = .freestanding, .cpu_arch = .wasm32 },
    });
    const pdk_module = b.dependency("extism-pdk", .{ .target = target, .optimize = optimize }).module("extism-pdk");
    var plugin = b.addExecutable(.{
        .name = "zig-pdk-template",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    // plugin.wasi_exec_model = .reactor;
    plugin.rdynamic = true;
    plugin.entry = .disabled; // or add an empty `pub fn main() void {}` to your code
    plugin.root_module.addImport("extism-pdk", pdk_module);

    b.installArtifact(plugin);
    const plugin_example_step = b.step("zig-pdk-template", "Build plugin");
    plugin_example_step.dependOn(b.getInstallStep());

    // Run test using extism CLI
    const args = [_][]const u8{ "extism", "call", plugin.out_filename, "greet", "--input", "world" };
    var run_cmd = b.addSystemCommand(&args);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.cwd = plugin.getEmittedBinDirectory();

    const run_step = b.step("test", "Test the plugin");
    run_step.dependOn(&run_cmd.step);
}
