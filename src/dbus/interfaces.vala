namespace Switchboard {

    public const string CARDWIRE_BUS = "org.opengamingcollective.cardwire";
    public const string CARDWIRE_PATH = "/org/opengamingcollective/cardwire";
    public const string GPU_IFACE = "org.opengamingcollective.cardwire.Gpu";
    public const string LOGGER_IFACE = "org.opengamingcollective.cardwire.Logger";

    [DBus (name = "org.opengamingcollective.cardwire.Mode")]
    public interface ModeProxy : Object {
        public abstract uint mode { get; set; }
        public abstract uint[] available_modes () throws Error;
    }

    [DBus (name = "org.opengamingcollective.cardwire.Config")]
    public interface ConfigProxy : Object {
        public abstract bool auto_apply_gpu_state { get; set; }
        public abstract bool battery_auto_switch { get; set; }
        public abstract uint battery_auto_switch_mode { get; set; }
        public abstract bool experimental_nvidia_block { get; set; }
        public abstract bool external_display_auto_switch { get; set; }
        public abstract void save_to_file () throws Error;
    }

    [DBus (name = "org.opengamingcollective.cardwire.Gpu")]
    public interface GpuProxy : Object {
        public abstract bool block { get; set; }
        public abstract bool launchable { get; }
        public abstract string[] env { owned get; }
        public abstract string power_state () throws Error;
    }

    [DBus (name = "org.opengamingcollective.cardwire.Manager")]
    public interface ManagerProxy : Object {
        public abstract void status () throws Error;
    }
}
