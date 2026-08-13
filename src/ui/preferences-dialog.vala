[GtkTemplate (ui = "/dev/miguel/Switchboard/preferences-dialog.ui")]
public class Switchboard.PreferencesDialog : Adw.PreferencesDialog {

    [GtkChild] private unowned Adw.SwitchRow battery_row;
    [GtkChild] private unowned Adw.ComboRow battery_mode_row;
    [GtkChild] private unowned Adw.SwitchRow external_row;
    [GtkChild] private unowned Adw.SwitchRow auto_apply_row;
    [GtkChild] private unowned Adw.SwitchRow nvidia_row;
    [GtkChild] private unowned Adw.SwitchRow tray_row;
    [GtkChild] private unowned Adw.SwitchRow background_row;
    [GtkChild] private unowned Adw.PreferencesGroup switching_group;
    [GtkChild] private unowned Adw.PreferencesGroup advanced_group;

    public CardwireClient client { get; construct; }
    public Settings prefs { get; construct; }

    private GpuMode[] combo_modes = {};
    private bool syncing = false;

    public PreferencesDialog (CardwireClient client, Settings prefs) {
        Object (client: client, prefs: prefs);
    }

    construct {
        prefs.bind ("tray-icon", tray_row, "active", SettingsBindFlags.DEFAULT);
        prefs.bind ("run-in-background", background_row, "active", SettingsBindFlags.DEFAULT);
        background_row.sensitive = tray_row.active;
        tray_row.notify["active"].connect (() => {
            background_row.sensitive = tray_row.active;
        });

        build_mode_list ();
        sync_all ();

        battery_row.notify["active"].connect (() => {
            battery_mode_row.sensitive = battery_row.active;
            write_bool ("BatteryAutoSwitch", battery_row.active);
        });
        external_row.notify["active"].connect (() => {
            write_bool ("ExternalDisplayAutoSwitch", external_row.active);
        });
        auto_apply_row.notify["active"].connect (() => {
            write_bool ("AutoApplyGpuState", auto_apply_row.active);
        });
        nvidia_row.notify["active"].connect (() => {
            write_bool ("ExperimentalNvidiaBlock", nvidia_row.active);
        });
        battery_mode_row.notify["selected"].connect (() => {
            if (syncing || battery_mode_row.selected >= combo_modes.length) {
                return;
            }
            write_uint ("BatteryAutoSwitchMode", combo_modes[battery_mode_row.selected]);
        });

        if (client.config != null) {
            ((DBusProxy) client.config).g_properties_changed.connect (sync_all);
        }

        // Only the daemon-backed groups follow the daemon. The app's own
        // settings stay usable with cardwired down.
        client.notify["available"].connect (sync_sensitivity);
        sync_sensitivity ();
    }

    private void build_mode_list () {
        var names = new Gtk.StringList (null);
        combo_modes = {};

        foreach (var mode in client.available_modes ()) {
            names.append (mode.title ());
            combo_modes += mode;
        }

        // Nothing stops the daemon holding a battery mode this system does not
        // offer, so show it rather than silently snapping to something else.
        if (client.config != null) {
            var current = GpuMode.from_uint (client.config.battery_auto_switch_mode);
            var known = false;
            foreach (var mode in combo_modes) {
                if (mode == current) {
                    known = true;
                    break;
                }
            }
            if (!known) {
                names.append (current.title ());
                combo_modes += current;
            }
        }

        battery_mode_row.model = names;
    }

    private void sync_all () {
        if (client.config == null) {
            return;
        }

        syncing = true;

        battery_row.active = client.config.battery_auto_switch;
        external_row.active = client.config.external_display_auto_switch;
        auto_apply_row.active = client.config.auto_apply_gpu_state;
        nvidia_row.active = client.config.experimental_nvidia_block;

        var current = GpuMode.from_uint (client.config.battery_auto_switch_mode);
        for (int i = 0; i < combo_modes.length; i++) {
            if (combo_modes[i] == current) {
                battery_mode_row.selected = i;
                break;
            }
        }

        battery_mode_row.sensitive = battery_row.active;

        syncing = false;
    }

    private void sync_sensitivity () {
        switching_group.sensitive = client.available;
        advanced_group.sensitive = client.available;
    }

    private void write_bool (string prop, bool val) {
        if (syncing) {
            return;
        }
        apply_bool.begin (prop, val);
    }

    private void write_uint (string prop, uint val) {
        if (syncing) {
            return;
        }
        apply_uint.begin (prop, val);
    }

    private async void apply_bool (string prop, bool val) {
        try {
            yield client.set_config_bool (prop, val);
            yield client.save_config ();
        } catch (Error e) {
            warning ("%s: %s", prop, e.message);
            sync_all ();
        }
    }

    private async void apply_uint (string prop, uint val) {
        try {
            yield client.set_config_uint (prop, val);
            yield client.save_config ();
        } catch (Error e) {
            warning ("%s: %s", prop, e.message);
            sync_all ();
        }
    }
}
