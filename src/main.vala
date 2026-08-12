int main (string[] args) {
    if (args.length > 1 && args[1] == "--probe") {
        return Switchboard.run_probe (args.length > 2 && args[2] == "write");
    }
    return new Switchboard.Application ().run (args);
}
