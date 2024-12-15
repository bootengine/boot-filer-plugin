const std = @import("std");
const fs = std.fs;
const extism_pdk = @import("extism-pdk");
const Plugin = extism_pdk.Plugin;

const allocator = std.heap.wasm_allocator;

export fn create_file() i32 {
    const plugin = Plugin.init(allocator);
    const filename = plugin.getInput() catch unreachable;
    defer allocator.free(filename);

    const file = fs.cwd().createFile(filename, .{ .read = true }) catch |err| {
        const out = std.fmt.allocPrint(allocator, "Failed to create file '{s}': {s}", .{ filename, @errorName(err) }) catch unreachable;
        plugin.setError(out);
        return 1;
    };
    defer file.close();

    return 0;
}

export fn write_file() i32 {
    const plugin = Plugin.init(allocator);
    const Input = struct {
        filename: []u8,
        content: []u8,
    };

    const input = plugin.getJson(Input) catch unreachable;

    fs.cwd().writeFile(fs.Dir.WriteFileOptions{ .sub_path = input.filename, .data = input.content }) catch |err| {
        const out = std.fmt.allocPrint(allocator, "Failed to write file '{s}': {s}", .{ input.filename, @errorName(err) }) catch unreachable;
        plugin.setError(out);
        return 1;
    };
    return 0;
}

export fn create_folder() i32 {
    const plugin = Plugin.init(allocator);
    const foldername = plugin.getInput() catch unreachable;
    defer allocator.free(foldername);
    fs.cwd().makeDir(foldername) catch |err| {
        const out = std.fmt.allocPrint(allocator, "Failed to create folder '{s}': {s}", .{ foldername, @errorName(err) }) catch unreachable;
        plugin.setError(out);
        return 1;
    };

    return 0;
}

export fn create_folder_struct() i32 {
    const plugin = Plugin.init(allocator);
    const conf = plugin.getConfig("folder_struct") catch unreachable orelse {
        plugin.setError("this action requires a folder_struct to be defined");
        return 1;
    };
    plugin.log(.Info, conf);

    // _ = std.json.parseFromSlice(i32, allocator, conf, std.json.ParseOptions{}) catch |err| {
    //     const out = std.fmt.allocPrint(allocator, "Failed to parse config: {s}", .{@errorName(err)}) catch unreachable;
    //     plugin.setError(out);
    //     return 1;
    // };

    return 0;
}
