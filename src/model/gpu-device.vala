public class Switchboard.GpuDevice : Object {

    public uint id { get; construct; }
    public string path { get; construct; }

    public string name { get; set; default = ""; }
    public string vendor { get; set; default = ""; }
    public string driver { get; set; default = ""; }
    public string pci { get; set; default = ""; }
    public string nvidia_minor { get; set; default = ""; }

    public bool discrete { get; set; }
    public bool is_default { get; set; }
    public bool available { get; set; }
    public bool nvidia { get; set; }

    public bool blocked { get; set; }
    public bool launchable { get; set; }
    public string power_state { get; set; default = "unknown"; }

    public GpuDevice (uint id, string path) {
        Object (id: id, path: path);
    }

    // GetDevice is (ssuubbbbssbs), field order from DbusGpuDevice in the daemon
    public void apply_device (Variant v) {
        string n, p, vend, drv, minor;
        uint32 render, card;
        bool def, disc, virt, avail, nv;

        v.get ("(ssuubbbbssbs)",
            out n, out p, out render, out card,
            out def, out disc, out virt, out avail,
            out vend, out drv, out nv, out minor);

        name = n;
        pci = p;
        is_default = def;
        discrete = disc;
        available = avail;
        vendor = vend;
        driver = drv;
        nvidia = nv;
        nvidia_minor = minor;
    }

    public bool awake () {
        return power_state.has_prefix ("D0");
    }

    public string power_label () {
        if (power_state == "D3cold") {
            return "Asleep · D3cold";
        }
        if (power_state.has_prefix ("D0")) {
            return "Awake · D0";
        }
        return power_state;
    }
}
