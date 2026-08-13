[GtkTemplate (ui = "/dev/miguel/Switchboard/window.ui")]
public class Switchboard.Window : Adw.ApplicationWindow {

    [GtkChild] private unowned Adw.Bin status_slot;
    [GtkChild] private unowned Adw.Bin activity_slot;

    public CardwireClient client { get; construct; }

    // Not "settings": Gtk.Widget already has get_settings(), and a property of
    // that name would silently override it.
    public Settings prefs { get; construct; }

    public Window (Gtk.Application app, CardwireClient client, Settings prefs) {
        Object (application: app, client: client, prefs: prefs);
    }

    construct {
        // libadwaita hangs the stripe off `window.devel headerbar`, so the class
        // belongs on the window and reaches the header bar by descent.
        if (Config.PROFILE == "development") {
            add_css_class ("devel");
        }

        status_slot.child = new StatusPage (client);
        activity_slot.child = new ActivityPage (client);

        prefs.bind ("window-width", this, "default-width", SettingsBindFlags.DEFAULT);
        prefs.bind ("window-height", this, "default-height", SettingsBindFlags.DEFAULT);
        prefs.bind ("window-maximized", this, "maximized", SettingsBindFlags.DEFAULT);

        close_request.connect (() => {
            if (prefs.get_boolean ("tray-icon") && prefs.get_boolean ("run-in-background")) {
                set_visible (false);
                return true;
            }
            return false;
        });
    }
}
