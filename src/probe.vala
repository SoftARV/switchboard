namespace Switchboard {

    // Headless check against the running daemon: switchboard --probe [write]
    public int run_probe (bool write_check = false) {
        var loop = new MainLoop ();
        var client = new CardwireClient ();
        var ok = false;

        client.ready.connect (() => {
            ok = true;
            dump (client);
            if (write_check) {
                check_write.begin (client, () => loop.quit ());
            } else {
                loop.quit ();
            }
        });

        Timeout.add_seconds (8, () => {
            stderr.printf ("timed out waiting for %s\n", CARDWIRE_BUS);
            loop.quit ();
            return Source.REMOVE;
        });

        client.start ();
        loop.run ();
        return ok ? 0 : 1;
    }

    // Exercises the write path against the one property that cannot change
    // behaviour: BatteryAutoSwitchMode is inert while BatteryAutoSwitch is off,
    // and nothing is persisted without SaveToFile. Never writes Mode or Block.
    private async void check_write (CardwireClient client) {
        if (client.config == null) {
            return;
        }
        if (client.config.battery_auto_switch) {
            stdout.printf ("\nwrite check : skipped, battery auto-switch is on\n");
            return;
        }

        var original = client.config.battery_auto_switch_mode;
        var probe_value = original == 1 ? 3 : 1;

        try {
            yield client.set_config_uint ("BatteryAutoSwitchMode", probe_value);
            var seen = client.config.battery_auto_switch_mode;
            yield client.set_config_uint ("BatteryAutoSwitchMode", original);

            stdout.printf ("\nwrite check : %s -> %s -> %s  [%s]\n",
                GpuMode.from_uint (original).title (),
                GpuMode.from_uint (seen).title (),
                GpuMode.from_uint (client.config.battery_auto_switch_mode).title (),
                seen == probe_value ? "ok" : "FAILED");
        } catch (Error e) {
            stdout.printf ("\nwrite check : FAILED %s\n", e.message);
        }
    }

    private void dump (CardwireClient client) {
        stdout.printf ("daemon      : up\n");
        stdout.printf ("mode        : %s (%d)\n", client.mode.title (), client.mode);

        var names = new StringBuilder ();
        foreach (var m in client.available_modes ()) {
            if (names.len > 0) {
                names.append (", ");
            }
            names.append (m.title ());
        }
        stdout.printf ("modes       : %s\n", names.str);

        stdout.printf ("\ngpus        : %u\n", client.gpus.get_n_items ());
        for (uint i = 0; i < client.gpus.get_n_items (); i++) {
            var d = (GpuDevice) client.gpus.get_item (i);
            stdout.printf ("  [%u] %s\n", d.id, d.name);
            stdout.printf ("      vendor=%s driver=%s pci=%s\n", d.vendor, d.driver, d.pci);
            stdout.printf ("      discrete=%s default=%s available=%s nvidia=%s\n",
                d.discrete.to_string (), d.is_default.to_string (),
                d.available.to_string (), d.nvidia.to_string ());
            stdout.printf ("      blocked=%s launchable=%s power=%s\n",
                d.blocked.to_string (), d.launchable.to_string (), d.power_label ());
        }

        if (client.config != null) {
            stdout.printf ("\nconfig\n");
            stdout.printf ("  auto_apply_gpu_state       = %s\n", client.config.auto_apply_gpu_state.to_string ());
            stdout.printf ("  battery_auto_switch        = %s\n", client.config.battery_auto_switch.to_string ());
            stdout.printf ("  battery_auto_switch_mode   = %s\n",
                GpuMode.from_uint (client.config.battery_auto_switch_mode).title ());
            stdout.printf ("  experimental_nvidia_block  = %s\n", client.config.experimental_nvidia_block.to_string ());
            stdout.printf ("  external_display_auto_switch = %s\n", client.config.external_display_auto_switch.to_string ());
        }

        var n = client.events.get_n_items ();
        stdout.printf ("\nblocked     : %u events\n", n);
        for (uint i = (n > 8 ? n - 8 : 0); i < n; i++) {
            var e = (BlockEvent) client.events.get_item (i);
            stdout.printf ("  %s  pid=%-7u gpu=%u  %s\n",
                e.time.format ("%H:%M:%S"), e.pid, e.gpu_id, e.display_name ());
        }
    }
}
