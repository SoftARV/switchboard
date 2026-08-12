namespace Switchboard {

    public enum GpuMode {
        INTEGRATED = 0,
        HYBRID = 1,
        MANUAL = 2,
        SMART = 3;

        public static GpuMode from_uint (uint value) {
            switch (value) {
                case 0: return INTEGRATED;
                case 1: return HYBRID;
                case 2: return MANUAL;
                case 3: return SMART;
                default: return HYBRID;
            }
        }

        public string title () {
            switch (this) {
                case INTEGRATED: return "Integrated";
                case HYBRID: return "Hybrid";
                case MANUAL: return "Manual";
                case SMART: return "Smart";
                default: return "Unknown";
            }
        }

        public string blurb () {
            switch (this) {
                case INTEGRATED: return "The discrete GPU stays blocked and asleep";
                case HYBRID: return "Both GPUs available, apps pick their own";
                case MANUAL: return "You decide which GPUs are blocked";
                case SMART: return "Access granted per app, on request";
                default: return "";
            }
        }

        public string icon_name () {
            switch (this) {
                case INTEGRATED: return "power-profile-power-saver-symbolic";
                case HYBRID: return "power-profile-balanced-symbolic";
                case MANUAL: return "emblem-system-symbolic";
                case SMART: return "starred-symbolic";
                default: return "dialog-question-symbolic";
            }
        }
    }
}
