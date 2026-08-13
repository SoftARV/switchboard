public class Switchboard.Application : Adw.Application {

    private CardwireClient client;
    private TrayIcon tray;
    private Settings prefs;
    private Window? window;
    private bool held = false;

    public Application () {
        Object (application_id: Config.APP_ID,
                flags: ApplicationFlags.DEFAULT_FLAGS);
    }

    protected override void startup () {
        base.startup ();

        prefs = new Settings (Config.APP_ID);

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource (Config.APP_PATH + "/style.css");
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        client = new CardwireClient ();
        client.start ();

        tray = new TrayIcon (client);
        tray.show_requested.connect (() => {
            activate ();
        });
        tray.quit_requested.connect (() => {
            shut_down ();
        });
        tray.start ();

        prefs.changed["tray-icon"].connect (apply_background_policy);
        prefs.changed["run-in-background"].connect (apply_background_policy);
        apply_background_policy ();

        var prefs_action = new SimpleAction ("preferences", null);
        prefs_action.activate.connect (() => {
            new PreferencesDialog (client, prefs).present (active_window);
        });
        add_action (prefs_action);

        var about_action = new SimpleAction ("about", null);
        about_action.activate.connect (() => {
            show_about ();
        });
        add_action (about_action);

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            shut_down ();
        });
        add_action (quit_action);

        set_accels_for_action ("app.preferences", { "<Control>comma" });
        set_accels_for_action ("app.about", { "F1" });
        set_accels_for_action ("app.quit", { "<Control>q" });
    }

    // hold() is what keeps the process alive with no window. Only worth doing
    // when the tray is actually showing, otherwise the app would be running
    // with nothing to bring it back.
    private void apply_background_policy () {
        var tray_on = prefs.get_boolean ("tray-icon");
        tray.set_enabled (tray_on);

        var keep = tray_on && prefs.get_boolean ("run-in-background");
        if (keep && !held) {
            hold ();
            held = true;
        } else if (!keep && held) {
            release ();
            held = false;
        }
    }

    private void shut_down () {
        if (held) {
            release ();
            held = false;
        }
        quit ();
    }

    private void show_about () {
        new Adw.AboutDialog () {
            application_name = "Switchboard",
            application_icon = Config.APP_ID,
            version = Config.VERSION,
            developer_name = "Miguel Rincon",
            comments = "Switch GPU modes and keep your dGPU asleep.",
            website = "https://github.com/SoftARV/switchboard",
            issue_url = "https://github.com/SoftARV/switchboard/issues",
            license_type = Gtk.License.GPL_3_0,
            copyright = "© 2026 Miguel Rincon",
        }.present (active_window);
    }

    protected override void activate () {
        if (window == null) {
            window = new Window (this, client, prefs);
        }
        window.present ();
    }
}
