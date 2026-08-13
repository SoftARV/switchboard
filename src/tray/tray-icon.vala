public class Switchboard.TrayIcon : Object {

    // The watcher resolves the item by bus name and expects it here.
    private const string ITEM_PATH = "/StatusNotifierItem";
    private const string MENU_PATH = "/dev/miguel/Switchboard/Menu";
    private const string WATCHER = "org.kde.StatusNotifierWatcher";

    public CardwireClient client { get; construct; }

    public signal void show_requested ();
    public signal void quit_requested ();

    private DBusConnection? bus;
    private StatusNotifierItem? item;
    private Dbusmenu.Server? server;
    private Dbusmenu.Menuitem? root;
    private Dbusmenu.Menuitem[] mode_items = {};
    private GpuMode[] mode_values = {};
    private uint watch_id;
    private bool menu_syncing = false;
    private bool enabled = true;

    public TrayIcon (CardwireClient client) {
        Object (client: client);
    }

    public void start () {
        export.begin ();
    }

    // Hosts hide a Passive item, which is a cleaner way to turn the icon off
    // than tearing the export down and rebuilding it.
    public void set_enabled (bool value) {
        enabled = value;
        if (item == null) {
            return;
        }
        var state = value ? "Active" : "Passive";
        if (item.status != state) {
            item.status = state;
            item.new_status (state);
        }
    }

    private async void export () {
        try {
            bus = yield Bus.get (BusType.SESSION);

            server = new Dbusmenu.Server (MENU_PATH);
            root = new Dbusmenu.Menuitem ();
            server.set_root (root);
            rebuild_menu ();

            item = new StatusNotifierItem ();
            item.id = Config.APP_ID;
            item.status = enabled ? "Active" : "Passive";
            item.menu = new ObjectPath (MENU_PATH);
            item.icon_theme_path = icon_theme_path ();
            item.icon_name = icon_for_state ();
            item.activate_requested.connect (() => {
                show_requested ();
            });

            bus.register_object (ITEM_PATH, item);

            client.ready.connect (() => {
                rebuild_menu ();
                sync ();
            });
            client.notify["mode"].connect (sync);
            client.notify["available"].connect (sync);
            client.gpus.items_changed.connect ((p, r, a) => {
                track_gpus ();
                sync ();
            });
            track_gpus ();
            sync ();

            // Re-register when the host restarts: a GNOME Shell reload or the
            // AppIndicator extension being toggled drops every registered item.
            watch_id = Bus.watch_name (BusType.SESSION, WATCHER, BusNameWatcherFlags.NONE,
                (conn, name, owner) => { register.begin (); },
                (conn, name) => { });
        } catch (Error e) {
            warning ("tray export: %s", e.message);
        }
    }

    private async void register () {
        try {
            StatusNotifierWatcher watcher = yield Bus.get_proxy<StatusNotifierWatcher> (
                BusType.SESSION, WATCHER, "/StatusNotifierWatcher");
            watcher.register_status_notifier_item (bus.unique_name);
        } catch (Error e) {
            warning ("tray register: %s", e.message);
        }
    }

    // Empty means "use the default icon theme", which is what an installed
    // build wants. Sending a path is actively harmful otherwise: the host
    // *replaces* its whole search path with it, so a directory that does not
    // hold the icons makes them unfindable even when they are installed
    // properly. Only the dev override sets it.
    private string icon_theme_path () {
        var dev = Environment.get_variable ("SWITCHBOARD_ICON_PATH");
        return dev != null ? dev : "";
    }

    private GpuDevice? discrete () {
        for (uint i = 0; i < client.gpus.get_n_items (); i++) {
            var dev = (GpuDevice) client.gpus.get_item (i);
            if (dev.discrete) {
                return dev;
            }
        }
        return null;
    }

    // A chip rather than the app's own card icon: in a panel these read as
    // status, and filled-vs-hollow is the clearest difference at 16px.
    private string icon_for_state () {
        var dev = discrete ();
        var awake = dev != null && dev.awake ();
        return Config.APP_ID + (awake ? "-awake-symbolic" : "-asleep-symbolic");
    }

    private void track_gpus () {
        for (uint i = 0; i < client.gpus.get_n_items (); i++) {
            var dev = (GpuDevice) client.gpus.get_item (i);
            dev.notify["power-state"].connect (sync);
            dev.notify["blocked"].connect (sync);
        }
    }

    private void sync () {
        if (item == null) {
            return;
        }

        var icon = icon_for_state ();
        if (item.icon_name != icon) {
            item.icon_name = icon;
            item.new_icon ();
        }

        var dev = discrete ();
        var label = client.available
            ? "Switchboard · %s%s".printf (
                client.mode.title (),
                dev != null ? " · " + dev.power_label () : "")
            : "Switchboard · cardwired not running";

        if (item.title != label) {
            item.title = label;
            item.new_title ();
        }

        sync_menu ();
    }

    private void rebuild_menu () {
        Dbusmenu.Menuitem[] existing = {};
        foreach (var child in root.get_children ()) {
            existing += child;
        }
        foreach (var child in existing) {
            root.child_delete (child);
        }

        mode_items = {};
        mode_values = {};

        foreach (var available in client.available_modes ()) {
            var mode = available;
            var entry = new Dbusmenu.Menuitem ();
            entry.property_set (Dbusmenu.MENUITEM_PROP_LABEL, mode.title ());
            entry.property_set (Dbusmenu.MENUITEM_PROP_TOGGLE_TYPE, Dbusmenu.MENUITEM_TOGGLE_RADIO);
            entry.property_set_int (Dbusmenu.MENUITEM_PROP_TOGGLE_STATE,
                mode == client.mode
                    ? Dbusmenu.MENUITEM_TOGGLE_STATE_CHECKED
                    : Dbusmenu.MENUITEM_TOGGLE_STATE_UNCHECKED);

            entry.item_activated.connect ((ts) => {
                if (menu_syncing) {
                    return;
                }
                apply_mode.begin (mode);
            });

            root.child_append (entry);
            mode_items += entry;
            mode_values += mode;
        }

        if (mode_values.length > 0) {
            var separator = new Dbusmenu.Menuitem ();
            separator.property_set (Dbusmenu.MENUITEM_PROP_TYPE, Dbusmenu.CLIENT_TYPES_SEPARATOR);
            root.child_append (separator);
        }

        var show = new Dbusmenu.Menuitem ();
        show.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Show Switchboard");
        show.item_activated.connect ((ts) => {
            show_requested ();
        });
        root.child_append (show);

        var quit = new Dbusmenu.Menuitem ();
        quit.property_set (Dbusmenu.MENUITEM_PROP_LABEL, "Quit");
        quit.item_activated.connect ((ts) => {
            quit_requested ();
        });
        root.child_append (quit);
    }

    private void sync_menu () {
        menu_syncing = true;
        for (int i = 0; i < mode_items.length; i++) {
            mode_items[i].property_set_int (Dbusmenu.MENUITEM_PROP_TOGGLE_STATE,
                mode_values[i] == client.mode
                    ? Dbusmenu.MENUITEM_TOGGLE_STATE_CHECKED
                    : Dbusmenu.MENUITEM_TOGGLE_STATE_UNCHECKED);
        }
        menu_syncing = false;
    }

    private async void apply_mode (GpuMode target) {
        try {
            yield client.request_mode (target);
        } catch (Error e) {
            warning ("tray mode: %s", e.message);
            sync_menu ();
        }
    }
}
