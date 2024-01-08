const std = @import("std");
const win = std.os.windows;

const zwin = @import("zigwin32").everything;

pub fn getProcessIdByName(proc_name: [:0]const u16) anyerror!win.DWORD {
    const handle = zwin.CreateToolhelp32Snapshot(zwin.TH32CS_SNAPPROCESS, 0) orelse return error.InvalidSnapshotHandle;
    defer _ = zwin.CloseHandle(handle);

    var entry: zwin.PROCESSENTRY32W = undefined;
    entry.dwSize = @sizeOf(zwin.PROCESSENTRY32W);

    var is_ok = zwin.Process32FirstW(handle, &entry);
    if (is_ok == win.FALSE) {
        return error.ProcessNotFound;
    }

    while (is_ok == win.TRUE) : (is_ok = zwin.Process32NextW(handle, &entry)) {
        if (std.mem.eql(u16, proc_name, entry.szExeFile[0..proc_name.len])) {
            return entry.th32ProcessID;
        }
    }

    return error.ProcessNotFound;
}
