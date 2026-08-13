// A plain Box rather than an Adw.ActionRow: rows live inside a Gtk.ListView,
// which recycles them, and an ActionRow is a Gtk.ListBoxRow -- the wrong thing
// to nest in a list view.
[GtkTemplate (ui = "/dev/miguel/Switchboard/block-event-row.ui")]
public class Switchboard.BlockEventRow : Gtk.Box {

    [GtkChild] private unowned Gtk.Label name_label;
    [GtkChild] private unowned Gtk.Label detail_label;
    [GtkChild] private unowned Gtk.Label time_label;

    public CardwireClient client { get; construct; }

    public BlockEventRow (CardwireClient client) {
        Object (client: client);
    }

    public void bind_event (BlockEvent ev) {
        var gpu = client.find_by_id (ev.gpu_id);

        name_label.label = ev.display_name ();
        detail_label.label = "%s · pid %u".printf (
            gpu != null ? gpu.short_name () : "GPU %u".printf (ev.gpu_id),
            ev.pid
        );
        time_label.label = ev.when ();
        tooltip_text = gpu != null ? "%s\n%s · %s".printf (gpu.name, gpu.driver, gpu.pci) : null;
    }
}
