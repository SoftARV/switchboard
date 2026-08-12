[GtkTemplate (ui = "/dev/miguel/Switchboard/gpu-card.ui")]
public class Switchboard.GpuCard : Adw.PreferencesGroup {

    [GtkChild] private unowned Adw.ActionRow power_row;
    [GtkChild] private unowned Gtk.Label power_value;
    [GtkChild] private unowned Adw.SwitchRow block_row;

    public CardwireClient client { get; construct; }
    public GpuDevice device { get; construct; }

    private bool syncing = false;

    public GpuCard (CardwireClient client, GpuDevice device) {
        Object (client: client, device: device);
    }

    construct {
        title = device.name;
        description = describe ();

        device.notify["power-state"].connect (sync_power);
        device.notify["launchable"].connect (sync_power);
        device.notify["blocked"].connect (sync_block);
        client.notify["busy"].connect (() => {
            block_row.sensitive = !client.busy;
        });

        block_row.notify["active"].connect (() => {
            if (syncing) {
                return;
            }
            apply.begin (block_row.active);
        });

        sync_power ();
        sync_block ();
    }

    private string describe () {
        var bits = new StringBuilder (device.vendor);
        if (device.driver != "" && device.driver != "none") {
            bits.append (" · ").append (device.driver);
        }
        bits.append (" · ").append (device.discrete ? "discrete" : "integrated");
        if (device.is_default) {
            bits.append (" · default");
        }
        return bits.str;
    }

    private void sync_power () {
        power_value.label = device.power_label ();
        power_row.subtitle = device.launchable
            ? "Applications can launch on this GPU"
            : "Applications cannot see this GPU";
    }

    // The daemon is the source of truth: guard against echoing its own
    // PropertiesChanged back at it as a fresh write.
    private void sync_block () {
        syncing = true;
        block_row.active = device.blocked;
        syncing = false;
    }

    private async void apply (bool blocked) {
        try {
            yield client.request_block (device, blocked);
        } catch (Error e) {
            warning ("block %s: %s", device.path, e.message);
            sync_block ();
        }
    }
}
