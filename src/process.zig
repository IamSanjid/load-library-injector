const std = @import("std");
const win = std.os.windows;

const zwin = @import("zigwin32").everything;

pub fn getProcessIdByName(proc_name: []const u16) anyerror!win.DWORD {
    var handle = zwin.CreateToolhelp32Snapshot(zwin.TH32CS_SNAPPROCESS, 0) orelse return error.InvalidSnapshotHandle;
    defer _ = zwin.CloseHandle(handle);

    var entry: zwin.PROCESSENTRY32W = undefined;
    entry.dwSize = @sizeOf(zwin.PROCESSENTRY32W);

    if (zwin.Process32FirstW(handle, &entry) == win.FALSE) {
        return error.ProcessNotFound;
    }

    if (std.mem.eql(u16, proc_name, &entry.szExeFile)) {
        return entry.th32ProcessID;
    }

    while (zwin.Process32NextW(handle, &entry) == win.TRUE) {
        if (std.mem.eql(u16, proc_name, entry.szExeFile[0..proc_name.len])) {
            return entry.th32ProcessID;
        }
    }

    return error.ProcessNotFound;
}
