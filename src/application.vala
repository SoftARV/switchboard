public class Switchboard.Application : Adw.Application {

    private CardwireClient client;

    public Application () {
        Object (application_id: Config.APP_ID,
                flags: ApplicationFlags.DEFAULT_FLAGS);
    }

    protected override void startup () {
        base.startup ();

        client = new CardwireClient ();
        client.start ();

        var provider = new Gtk.CssProvider ();
        provider.load_from_resource (Config.APP_PATH + "/style.css");
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        );

        var about_action = new SimpleAction ("about", null);
        about_action.activate.connect (() => {
            show_about ();
        });
        add_action (about_action);

        var quit_action = new SimpleAction ("quit", null);
        quit_action.activate.connect (() => {
            quit ();
        });
        add_action (quit_action);

        set_accels_for_action ("app.about", { "F1" });
        set_accels_for_action ("app.quit", { "<Control>q" });
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
        if (active_window != null) {
            active_window.present ();
            return;
        }

        new Window (this, client).present ();
    }
}
