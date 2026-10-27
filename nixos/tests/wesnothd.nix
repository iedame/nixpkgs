{ lib, ... }:

{
  name = "wesnothd";
  meta.maintainers = with lib.maintainers; [ iedame ];

  nodes.machine = {
    services.wesnothd = {
      enable = true;
      settings.motd = "Hello from NixOS";
    };
  };

  testScript = ''
    machine.wait_for_unit("wesnothd.service")
    machine.wait_for_open_port(15000)

    # Server commands are read from the FIFO and answered in the log
    machine.wait_until_succeeds("test -p /run/wesnothd/socket")
    machine.succeed("echo motd > /run/wesnothd/socket")
    machine.wait_until_succeeds("journalctl -u wesnothd.service | grep -F 'Hello from NixOS'")

    machine.succeed("systemctl reload wesnothd.service")
    machine.wait_until_succeeds("journalctl -u wesnothd.service | grep -F 'SIGHUP caught, reloading config'")
    machine.wait_for_open_port(15000)
  '';
}
