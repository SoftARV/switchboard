public class Switchboard.CardwireClient : Object {

    public bool available { get; private set; default = false; }
    public bool busy { get; private set; default = false; }
    public GpuMode mode { get; private set; default = GpuMode.HYBRID; }

    public ListStore gpus { get; private set; }
    public ListStore events { get; private set; }
    public ConfigProxy? config { get; private set; }

    public signal void ready ();
    public signal void event_added (BlockEvent ev);

    private DBusConnection? bus;
    private ModeProxy? mode_proxy;
    private HashTable<string, GpuProxy> proxies;
    private GpuMode[] modes;
    private uint watch_id;
    private uint[] subs;

    construct {
        gpus = new ListStore (typeof (GpuDevice));
        events = new ListStore (typeof (BlockEvent));
        proxies = new HashTable<string, GpuProxy> (str_hash, str_equal);
        modes = {};
        subs = {};
    }

    public void start () {
        watch_id = Bus.watch_name (BusType.SYSTEM, CARDWIRE_BUS, BusNameWatcherFlags.NONE,
            (conn, name, owner) => { connect_all.begin (); },
            (conn, name) => { teardown (); });
    }

    public GpuMode[] available_modes () {
        return modes;
    }

    private async void connect_all () {
        try {
            bus = yield Bus.get (BusType.SYSTEM);

            mode_proxy = yield Bus.get_proxy<ModeProxy> (BusType.SYSTEM, CARDWIRE_BUS, CARDWIRE_PATH);
            config = yield Bus.get_proxy<ConfigProxy> (BusType.SYSTEM, CARDWIRE_BUS, CARDWIRE_PATH);

            mode = GpuMode.from_uint (mode_proxy.mode);
            ((DBusProxy) mode_proxy).g_properties_changed.connect (() => {
                mode = GpuMode.from_uint (mode_proxy.mode);
            });

            GpuMode[] found = {};
            foreach (var raw in mode_proxy.available_modes ()) {
                found += GpuMode.from_uint (raw);
            }
            modes = found;

            yield load_gpus ();
            yield load_events ();
            subscribe ();

            available = true;
            ready ();
        } catch (Error e) {
            warning ("cardwire unreachable: %s", e.message);
            available = false;
        }
    }

    private void teardown () {
        foreach (var id in subs) {
            if (bus != null) {
                bus.signal_unsubscribe (id);
            }
        }
        subs = {};
        proxies.remove_all ();
        gpus.remove_all ();
        events.remove_all ();
        mode_proxy = null;
        config = null;
        available = false;
    }

    private async void load_gpus () throws Error {
        var reply = yield bus.call (CARDWIRE_BUS, CARDWIRE_PATH,
            "org.freedesktop.DBus.ObjectManager", "GetManagedObjects",
            null, new VariantType ("(a{oa{sa{sv}}})"), DBusCallFlags.NONE, -1, null);

        var iter = new VariantIter (reply.get_child_value (0));
        string path;
        Variant ifaces;

        while (iter.next ("{o@a{sa{sv}}}", out path, out ifaces)) {
            if (ifaces.lookup_value (GPU_IFACE, null) == null) {
                continue;
            }
            yield add_gpu (path);
        }
    }

    private async void add_gpu (string path) {
        try {
            var dev = new GpuDevice ((uint) int.parse (Path.get_basename (path)), path);
            var proxy = yield Bus.get_proxy<GpuProxy> (BusType.SYSTEM, CARDWIRE_BUS, path);

            // zbus flattens the struct into the reply tuple, so the signature is
            // (ssuubbbbssbs) and not the ((ssuubbbbssbs)) a nested struct would give.
            var info = yield bus.call (CARDWIRE_BUS, path, GPU_IFACE, "GetDevice",
                null, new VariantType ("(ssuubbbbssbs)"), DBusCallFlags.NONE, -1, null);
            dev.apply_device (info);

            dev.blocked = proxy.block;
            dev.launchable = proxy.launchable;
            // the daemon returns this with a trailing newline
            dev.power_state = proxy.power_state ().strip ();

            ((DBusProxy) proxy).g_properties_changed.connect (() => {
                dev.blocked = proxy.block;
                dev.launchable = proxy.launchable;
            });

            proxies.insert (path, proxy);
            // GetManagedObjects hands them back unordered
            gpus.insert_sorted (dev, (a, b) => {
                return (int) ((GpuDevice) a).id - (int) ((GpuDevice) b).id;
            });
        } catch (Error e) {
            warning ("gpu %s: %s", path, e.message);
        }
    }

    private async void load_events () throws Error {
        var reply = yield bus.call (CARDWIRE_BUS, CARDWIRE_PATH, LOGGER_IFACE, "ProcessBlocked",
            null, new VariantType ("(a((tu)usus))"), DBusCallFlags.NONE, -1, null);

        var iter = new VariantIter (reply.get_child_value (0));
        Variant entry;
        while (iter.next ("@((tu)usus)", out entry)) {
            events.append (BlockEvent.from_variant (entry));
        }
    }

    private void subscribe () {
        subs += bus.signal_subscribe (CARDWIRE_BUS, GPU_IFACE, "PowerStateChanged", null, null,
            DBusSignalFlags.NONE,
            (conn, sender, path, iface, sig, args) => {
                var dev = find (path);
                if (dev != null) {
                    dev.power_state = args.get_child_value (0).get_string ().strip ();
                }
            });

        subs += bus.signal_subscribe (CARDWIRE_BUS, LOGGER_IFACE, "ProcessBlockedChanged",
            CARDWIRE_PATH, null, DBusSignalFlags.NONE,
            (conn, sender, path, iface, sig, args) => {
                var ev = BlockEvent.from_variant (args.get_child_value (0));
                events.append (ev);
                event_added (ev);
            });

        subs += bus.signal_subscribe (CARDWIRE_BUS, "org.freedesktop.DBus.ObjectManager",
            "InterfacesAdded", CARDWIRE_PATH, null, DBusSignalFlags.NONE,
            (conn, sender, path, iface, sig, args) => {
                var added = args.get_child_value (0).get_string ();
                if (find (added) == null) {
                    add_gpu.begin (added);
                }
            });

        subs += bus.signal_subscribe (CARDWIRE_BUS, "org.freedesktop.DBus.ObjectManager",
            "InterfacesRemoved", CARDWIRE_PATH, null, DBusSignalFlags.NONE,
            (conn, sender, path, iface, sig, args) => {
                remove_gpu (args.get_child_value (0).get_string ());
            });
    }

    public GpuDevice? find_by_id (uint id) {
        for (uint i = 0; i < gpus.get_n_items (); i++) {
            var dev = (GpuDevice) gpus.get_item (i);
            if (dev.id == id) {
                return dev;
            }
        }
        return null;
    }

    public GpuDevice? find (string path) {
        for (uint i = 0; i < gpus.get_n_items (); i++) {
            var dev = (GpuDevice) gpus.get_item (i);
            if (dev.path == path) {
                return dev;
            }
        }
        return null;
    }

    private void remove_gpu (string path) {
        for (uint i = 0; i < gpus.get_n_items (); i++) {
            if (((GpuDevice) gpus.get_item (i)).path == path) {
                gpus.remove (i);
                proxies.remove (path);
                return;
            }
        }
    }

    // Every write goes through Properties.Set by hand rather than the proxy setter.
    // Vala's generated setters are synchronous, and a mode transition reprograms an
    // eBPF map, sends a DRM uevent and may restart nvidia-powerd -- that would
    // freeze the main loop for the duration.
    private async void set_property_async (string path, string iface, string prop, Variant val) throws Error {
        busy = true;
        try {
            yield bus.call (CARDWIRE_BUS, path, "org.freedesktop.DBus.Properties", "Set",
                new Variant ("(ssv)", iface, prop, val),
                null, DBusCallFlags.NONE, -1, null);
        } finally {
            busy = false;
        }
    }

    // Named request_* rather than set_*: `mode` is a property here, so set_mode
    // would collide with its generated setter. valac reports that as an internal
    // redefinition error, not an obvious name clash.
    public async void request_mode (GpuMode target) throws Error {
        yield set_property_async (CARDWIRE_PATH, "org.opengamingcollective.cardwire.Mode",
            "Mode", new Variant.uint32 (target));
    }

    public async void request_block (GpuDevice dev, bool blocked) throws Error {
        yield set_property_async (dev.path, GPU_IFACE, "Block", new Variant.boolean (blocked));
    }

    public async void set_config_bool (string prop, bool val) throws Error {
        yield set_property_async (CARDWIRE_PATH, "org.opengamingcollective.cardwire.Config",
            prop, new Variant.boolean (val));
    }

    public async void set_config_uint (string prop, uint val) throws Error {
        yield set_property_async (CARDWIRE_PATH, "org.opengamingcollective.cardwire.Config",
            prop, new Variant.uint32 (val));
    }

    public async void save_config () throws Error {
        yield bus.call (CARDWIRE_BUS, CARDWIRE_PATH,
            "org.opengamingcollective.cardwire.Config", "SaveToFile",
            null, null, DBusCallFlags.NONE, -1, null);
    }

    public async void refresh_power () {
        for (uint i = 0; i < gpus.get_n_items (); i++) {
            var dev = (GpuDevice) gpus.get_item (i);
            var proxy = proxies.lookup (dev.path);
            if (proxy == null) {
                continue;
            }
            try {
                dev.power_state = proxy.power_state ().strip ();
            } catch (Error e) {
                warning ("power state %s: %s", dev.path, e.message);
            }
        }
    }
}
