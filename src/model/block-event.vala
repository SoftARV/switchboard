public class Switchboard.BlockEvent : Object {

    public DateTime time { get; construct; }
    public uint pid { get; construct; }
    public string comm { get; construct; }
    public uint gpu_id { get; construct; }
    public string app_id { get; construct; }

    public BlockEvent (DateTime time, uint pid, string comm, uint gpu_id, string app_id) {
        Object (time: time, pid: pid, comm: comm, gpu_id: gpu_id, app_id: app_id);
    }

    // LogEntry is ((tu)usus): (secs, nsecs), pid, comm, gpu_id, wayland_app_id
    public static BlockEvent from_variant (Variant entry) {
        uint64 secs;
        uint32 nsecs, pid, gpu_id;
        string comm, app_id;

        entry.get ("((tu)usus)", out secs, out nsecs, out pid, out comm, out gpu_id, out app_id);

        return new BlockEvent (
            new DateTime.from_unix_local ((int64) secs),
            pid, comm, gpu_id, app_id
        );
    }

    public string display_name () {
        return app_id == "" ? comm : app_id;
    }
}
