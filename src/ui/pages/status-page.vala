[GtkTemplate (ui = "/dev/miguel/Switchboard/status-page.ui")]
public class Switchboard.StatusPage : Adw.Bin {

    [GtkChild] private unowned Adw.Banner banner;
    [GtkChild] private unowned Gtk.Box content;
    [GtkChild] private unowned Adw.PreferencesGroup mode_group;
    [GtkChild] private unowned Gtk.Box mode_box;

    public CardwireClient client { get; construct; }

    private ModeTile[] tiles = {};
    private Gtk.Widget[] cards = {};
    private bool syncing = false;

    public StatusPage (CardwireClient client) {
        Object (client: client);
    }

    construct {
        client.ready.connect (rebuild);
        client.notify["available"].connect (sync_available);
        client.notify["mode"].connect (sync_mode);
        client.notify["busy"].connect (sync_busy);
        client.gpus.items_changed.connect ((pos, removed, added) => {
            rebuild_gpus ();
        });

        sync_available ();
        if (client.available) {
            rebuild ();
        }
    }

    private void rebuild () {
        build_modes ();
        rebuild_gpus ();
        sync_mode ();
        sync_available ();
    }

    private void build_modes () {
        foreach (var old in tiles) {
            mode_box.remove (old);
        }
        tiles = {};

        ModeTile? anchor = null;

        foreach (var available in client.available_modes ()) {
            var mode = available;
            var tile = new ModeTile (mode);

            // Grouped toggles give radio semantics: the active one stays active
            // when clicked again, so a re-click never writes.
            if (anchor == null) {
                anchor = tile;
            } else {
                tile.group = anchor;
            }

            mode_box.append (tile);

            tile.toggled.connect (() => {
                if (syncing || !tile.active) {
                    return;
                }
                apply_mode.begin (mode);
            });

            tiles += tile;
        }
    }

    private void rebuild_gpus () {
        foreach (var card in cards) {
            content.remove (card);
        }
        cards = {};

        for (uint i = 0; i < client.gpus.get_n_items (); i++) {
            var card = new GpuCard (client, (GpuDevice) client.gpus.get_item (i));
            content.append (card);
            cards += card;
        }
    }

    private void sync_mode () {
        syncing = true;
        foreach (var tile in tiles) {
            tile.active = tile.gpu_mode == client.mode;
        }
        syncing = false;
    }

    private void sync_busy () {
        mode_group.sensitive = !client.busy;
    }

    private void sync_available () {
        banner.revealed = !client.available;
        content.sensitive = client.available;
    }

    private async void apply_mode (GpuMode target) {
        try {
            yield client.request_mode (target);
        } catch (Error e) {
            warning ("mode: %s", e.message);
            sync_mode ();
        }
    }
}
