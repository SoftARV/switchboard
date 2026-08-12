[GtkTemplate (ui = "/dev/miguel/Switchboard/window.ui")]
public class Switchboard.Window : Adw.ApplicationWindow {

    public Window (Gtk.Application app) {
        Object (application: app);
    }
}
