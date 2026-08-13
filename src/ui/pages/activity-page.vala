[GtkTemplate (ui = "/dev/miguel/Switchboard/activity-page.ui")]
public class Switchboard.ActivityPage : Adw.Bin {

    // The daemon's ring buffer holds ~4096 entries. Building a row for every one
    // is not worth it, so only the newest are shown -- and the summary says so
    // rather than quietly truncating.
    private const uint MAX_ROWS = 250;

    [GtkChild] private unowned Gtk.Stack stack;
    [GtkChild] private unowned Gtk.Label summary;
    [GtkChild] private unowned Gtk.ListBox list_box;

    public CardwireClient client { get; construct; }

    public ActivityPage (CardwireClient client) {
        Object (client: client);
    }

    construct {
        var sorter = new Gtk.CustomSorter ((a, b) => {
            return ((BlockEvent) b).time.compare (((BlockEvent) a).time);
        });

        var sorted = new Gtk.SortListModel (client.events, sorter);
        var sliced = new Gtk.SliceListModel (sorted, 0, MAX_ROWS);

        list_box.bind_model (sliced, (item) => new BlockEventRow (client, (BlockEvent) item));

        client.events.items_changed.connect ((pos, removed, added) => {
            sync ();
        });

        sync ();
    }

    private void sync () {
        var total = client.events.get_n_items ();
        stack.visible_child_name = total == 0 ? "empty" : "list";

        if (total > MAX_ROWS) {
            summary.label = "Showing the %u most recent of %u blocked processes".printf (MAX_ROWS, total);
        } else if (total == 1) {
            summary.label = "1 blocked process";
        } else {
            summary.label = "%u blocked processes".printf (total);
        }
    }
}
