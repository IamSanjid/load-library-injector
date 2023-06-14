const std = @import("std");
const win = std.os.windows;
const eql = std.mem.eql;

const zwin = @import("zigwin32").everything;

const proc = @import("process.zig");

const help_text =
    \\ Help: injector [process name] [relative dll path]
    \\
    \\ Uses load library to inject a dll into a running process.
;

fn inject(pid: win.DWORD, dll_path: [:0]const u16) !void {
    const proc_handle = zwin.OpenProcess(zwin.PROCESS_ALL_ACCESS, win.FALSE, pid) orelse return error.OpenProcessFailed;
    defer _ = zwin.CloseHandle(proc_handle);

    const dll_path_mem = zwin.VirtualAllocEx(
        proc_handle,
        null,
        dll_path.len * @sizeOf(std.meta.Child(@TypeOf(dll_path))),
        zwin.MEM_COMMIT,
        zwin.PAGE_READWRITE,
    ) orelse return error.VirtualAllocFailed;
    defer _ = zwin.VirtualFreeEx(proc_handle, dll_path_mem, 0, zwin.MEM_RELEASE);

    if (zwin.WriteProcessMemory(
        proc_handle,
        dll_path_mem,
        dll_path.ptr,
        dll_path.len * @sizeOf(std.meta.Child(@TypeOf(dll_path))),
        null,
    ) == win.FALSE) {
        return error.WriteProcessMemoryFailed;
    }

    const kernel32 = zwin.GetModuleHandleW(std.unicode.utf8ToUtf16LeStringLiteral("kernel32")) orelse return error.NoKernelModuleHandle;
    const ll = zwin.GetProcAddress(kernel32, "LoadLibraryW") orelse return error.NoLoadLibraryHandle;
    const thread = zwin.CreateRemoteThread(proc_handle, null, 0, @ptrCast(zwin.LPTHREAD_START_ROUTINE, ll), dll_path_mem, 0, null);
    defer _ = zwin.CloseHandle(thread);

    _ = zwin.WaitForSingleObject(thread, zwin.INFINITE);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const alloc = arena.allocator();

    const args = try std.process.argsAlloc(alloc);
    if (args.len > 3) {
        return error.TooManyArguments;
    }

    var dll_path: []const u8 = undefined;
    var proc_name: []const u8 = undefined;
    for (args[1..], 1..) |arg, i| {
        if ((eql(u8, arg, "-h") or eql(u8, arg, "--help")) and i == 1) {
            try std.io.getStdOut().writer().print("{s}\n", .{help_text});
            std.process.exit(0);
        }

        switch (i) {
            1 => proc_name = arg,
            2 => dll_path = arg,
            else => unreachable,
        }
    }

    const proc_name_widened = try std.unicode.utf8ToUtf16LeWithNull(alloc, proc_name);
    const proc_id = proc.getProcessIdByName(proc_name_widened) catch |err| {
        std.log.err("Failed to get PID for process name {s}: {any}\n", .{ proc_name, err });
        std.process.exit(1);
    };

    const dll_abs_path = try std.fs.cwd().realpathAlloc(alloc, dll_path);
    const dll_path_widened = try std.unicode.utf8ToUtf16LeWithNull(alloc, dll_abs_path);
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Trying to inject: '{s}'\n", .{dll_abs_path});

    try inject(proc_id, dll_path_widened);
    try stdout.print("\x1b[32mSuccessfully injected!\x1b[0m\n", .{});
}

test {
    std.testing.refAllDecls(@import("process.zig"));
}
