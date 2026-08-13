[GtkTemplate (ui = "/dev/miguel/Switchboard/activity-page.ui")]
public class Switchboard.ActivityPage : Adw.Bin {

    [GtkChild] private unowned Gtk.Stack stack;
    [GtkChild] private unowned Gtk.Label summary;
    [GtkChild] private unowned Gtk.ListView list_view;

    public CardwireClient client { get; construct; }

    public ActivityPage (CardwireClient client) {
        Object (client: client);
    }

    construct {
        var sorter = new Gtk.CustomSorter ((a, b) => {
            return ((BlockEvent) b).time.compare (((BlockEvent) a).time);
        });

        var factory = new Gtk.SignalListItemFactory ();
        factory.setup.connect ((obj) => {
            ((Gtk.ListItem) obj).child = new BlockEventRow (client);
        });
        factory.bind.connect ((obj) => {
            var item = (Gtk.ListItem) obj;
            ((BlockEventRow) item.child).bind_event ((BlockEvent) item.item);
        });

        // The list view only builds the rows it can show, so the whole ring
        // buffer can be listed without paying for rows nobody scrolls to.
        list_view.model = new Gtk.NoSelection (new Gtk.SortListModel (client.events, sorter));
        list_view.factory = factory;

        client.events.items_changed.connect ((pos, removed, added) => {
            sync ();
        });

        sync ();
    }

    private void sync () {
        var total = client.events.get_n_items ();
        stack.visible_child_name = total == 0 ? "empty" : "list";
        summary.label = total == 1
            ? "1 blocked process"
            : "%u blocked processes".printf (total);
    }
}
