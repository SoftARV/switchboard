[GtkTemplate (ui = "/dev/miguel/Switchboard/mode-tile.ui")]
public class Switchboard.ModeTile : Gtk.ToggleButton {

    [GtkChild] private unowned Gtk.Image tile_icon;
    [GtkChild] private unowned Gtk.Label tile_title;
    [GtkChild] private unowned Gtk.Image tile_info;

    public GpuMode gpu_mode { get; construct; }

    public ModeTile (GpuMode gpu_mode) {
        Object (gpu_mode: gpu_mode);
    }

    construct {
        tile_icon.icon_name = gpu_mode.icon_name ();
        tile_title.label = gpu_mode.title ();
        tile_info.tooltip_text = gpu_mode.blurb ();
    }
}
