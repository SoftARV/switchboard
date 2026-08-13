[GtkTemplate (ui = "/dev/miguel/Switchboard/window.ui")]
public class Switchboard.Window : Adw.ApplicationWindow {

    [GtkChild] private unowned Adw.Bin status_slot;
    [GtkChild] private unowned Adw.Bin activity_slot;

    public CardwireClient client { get; construct; }

    public Window (Gtk.Application app, CardwireClient client) {
        Object (application: app, client: client);
    }

    construct {
        status_slot.child = new StatusPage (client);
        activity_slot.child = new ActivityPage (client);
    }
}
