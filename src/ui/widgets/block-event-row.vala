[GtkTemplate (ui = "/dev/miguel/Switchboard/block-event-row.ui")]
public class Switchboard.BlockEventRow : Adw.ActionRow {

    [GtkChild] private unowned Gtk.Label time_label;

    public CardwireClient client { get; construct; }
    public BlockEvent block_event { get; construct; }

    public BlockEventRow (CardwireClient client, BlockEvent block_event) {
        Object (client: client, block_event: block_event);
    }

    construct {
        var gpu = client.find_by_id (block_event.gpu_id);

        title = block_event.display_name ();
        subtitle = "%s · pid %u".printf (
            gpu != null ? gpu.short_name () : "GPU %u".printf (block_event.gpu_id),
            block_event.pid
        );
        time_label.label = block_event.when ();

        if (gpu != null) {
            tooltip_text = "%s\n%s · %s".printf (gpu.name, gpu.driver, gpu.pci);
        }
    }
}
