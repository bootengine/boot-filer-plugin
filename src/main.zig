const std = @import("std");
const fs = std.fs;
const os = std.os;
const extism_pdk = @import("extism-pdk");
const Plugin = extism_pdk.Plugin;

const allocator = std.heap.wasm_allocator;
const cwd = fs.Dir{ .fd = fs.defaultWasiCwd() };

const typeEnum = enum {
    file,
    folder,
};

const Spec = union(enum) {
    content: []u8,
    children: []Filer,
};

const Filer = struct {
    name: []u8,
    type: typeEnum,
    spec: ?Spec = null,
};

export fn createFile() i32 {
    const plugin = Plugin.init(allocator);
    const filename = plugin.getInput() catch unreachable;
    defer allocator.free(filename);

    const file = cwd.createFile(filename, .{ .read = true }) catch |err| {
        const out = std.fmt.allocPrint(allocator, "Failed to create file '{s}': {s}", .{ filename, @errorName(err) }) catch unreachable;
        plugin.setError(out);
        return 1;
    };
    defer file.close();

    return 0;
}

export fn writeFile() i32 {
    const plugin = Plugin.init(allocator);
    const Input = struct {
        filename: []u8,
        content: []u8,
    };

    const input = plugin.getJson(Input) catch unreachable;

    cwd.writeFile(fs.Dir.WriteFileOptions{ .sub_path = input.filename, .data = input.content }) catch |err| {
        const out = std.fmt.allocPrint(allocator, "Failed to write file '{s}': {s}", .{ input.filename, @errorName(err) }) catch unreachable;
        plugin.setError(out);
        return 1;
    };
    return 0;
}

export fn createFolder() i32 {
    const plugin = Plugin.init(allocator);
    const foldername = plugin.getInput() catch unreachable;
    defer allocator.free(foldername);

    cwd.makeDir(foldername) catch |err| {
        const out = std.fmt.allocPrint(allocator, "Failed to create folder '{s}': {s}", .{ foldername, @errorName(err) }) catch unreachable;
        plugin.setError(out);
        return 1;
    };

    return 0;
}

fn handleErr(p: Plugin, message: []const u8, err: anyerror) i32 {
    const out = std.fmt.allocPrint(allocator, "{s}: {s}", .{ message, @errorName(err) }) catch unreachable;
    p.setError(out);
    return 1;
}

fn parseConfigFolderStruct(str: []u8) anyerror![]Filer {
    const params = try std.json.parseFromSlice([]Filer, allocator, str, std.json.ParseOptions{});
    return params.value;
}

export fn createFolderStruct() callconv(.C) i32 {
    const plugin = Plugin.init(allocator);

    const config = plugin.getConfig("folder_struct") catch |err| {
        return handleErr(plugin, "this action requires a folder_struct to be defined", err);
    };
    if (config) |conf| {
        const filers = parseConfigFolderStruct(conf) catch |err| {
            return handleErr(plugin, "failed to parse folder_struct", err);
        };

        return create_folder_struct(plugin, filers, null);
    }

    return 0;
}

fn create_folder_struct(plugin: Plugin, filers: []Filer, current: ?[]const u8) i32 {
    for (filers) |filer| {
        switch (filer.type) {
            .file => {
                var currentDir: fs.Dir = cwd;
                if (current) |sub| {
                    currentDir = cwd.openDir(sub, .{}) catch |err| {
                        const out = std.fmt.allocPrint(allocator, "failed to open dir {s}", .{filer.name}) catch unreachable;
                        return handleErr(plugin, out, err);
                    };
                }
                const fd = currentDir.createFile(filer.name, .{ .read = true, .truncate = true }) catch |err| {
                    const out = std.fmt.allocPrint(allocator, "failed to create file {s}", .{filer.name}) catch unreachable;
                    return handleErr(plugin, out, err);
                };
                defer fd.close();

                if (filer.spec) |spec| {
                    if (!std.mem.eql(u8, spec.content, "")) {
                        fd.writeAll(spec.content) catch |err| {
                            const out = std.fmt.allocPrint(allocator, "failed to write content to file {s}", .{filer.name}) catch unreachable;
                            return handleErr(plugin, out, err);
                        };
                    }
                }
            },
            .folder => {
                var p: []const u8 = "";
                if (current) |currentPath| {
                    p = currentPath;
                }
                p = fs.path.join(allocator, &[_][]const u8{ p, filer.name }) catch |err| {
                    const out = std.fmt.allocPrint(allocator, "Failed to join path '{s}': {s}", .{ filer.name, @errorName(err) }) catch unreachable;
                    plugin.setError(out);
                    return 1;
                };
                cwd.makeDir(p) catch |err| {
                    const out = std.fmt.allocPrint(allocator, "Failed to create folder '{s}': {s}", .{ filer.name, @errorName(err) }) catch unreachable;
                    plugin.setError(out);
                    return 1;
                };
                if (filer.spec) |spec| {
                    if (spec.children.len != 0) {
                        const ret = create_folder_struct(plugin, spec.children, p);
                        if (ret == 1) {
                            return ret;
                        }
                    }
                }
            },
        }
    }
    return 0;
}
