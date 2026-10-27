{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.wesnothd;

  toWML =
    value:
    if lib.isBool value then
      lib.boolToYesNo value
    else if lib.isInt value then
      toString value
    else
      "\"${lib.replaceStrings [ "\"" ] [ "\"\"" ] value}\"";

  configFile = pkgs.writeText "wesnothd.cfg" (
    lib.concatLines (lib.mapAttrsToList (key: value: "${key}=${toWML value}") cfg.settings)
    + cfg.extraConfig
  );

  # wesnoth-devel installs its binaries with a -devel suffix
  serverProgram = "wesnothd" + lib.removePrefix "wesnoth" cfg.package.pname;
in
{
  options.services.wesnothd = {
    enable = lib.mkEnableOption "the Battle for Wesnoth multiplayer server";

    package = lib.mkPackageOption pkgs "wesnoth" {
      example = "wesnoth-devel";
      extraDescription = ''
        Clients can only connect to a server of the same version series, so use
        `wesnoth-devel` to host games for development releases.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 15000;
      description = "TCP port the server listens on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to open {option}`services.wesnothd.port` in the firewall.";
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf (
          lib.types.oneOf [
            lib.types.bool
            lib.types.int
            lib.types.str
          ]
        );

        options = {
          fifo_path = lib.mkOption {
            type = lib.types.str;
            default = "/run/wesnothd/socket";
            description = ''
              Path of the FIFO server commands can be written to, for example
              `echo status > /run/wesnothd/socket`.
            '';
          };

          ban_save_file = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/wesnothd/bans";
            description = "File bans are saved to, so they persist across restarts.";
          };
        };
      };
      default = { };
      example = {
        motd = "Welcome to my server!";
        connections_allowed = 10;
        save_replays = true;
        replay_save_path = "/var/lib/wesnothd/replays";
      };
      description = ''
        Top-level keys of the server configuration file. See the
        [server administration documentation](https://wiki.wesnoth.org/ServerAdministration)
        for the available keys.

        The configuration file is world-readable in the Nix store, so do not
        set `passwd` here.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        [redirect]
            host="server2.example.org"
            port=15000
            version="1.16*"
        [/redirect]
      '';
      description = ''
        Additional WML appended to the configuration file, for sections such as
        `[redirect]` or `[proxy]` that cannot be expressed with
        {option}`services.wesnothd.settings`.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--keepalive" ];
      description = "Extra command line arguments passed to {command}`wesnothd`.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    systemd.services.wesnothd = {
      description = "Battle for Wesnoth multiplayer server";
      documentation = [ "https://wiki.wesnoth.org/ServerAdministration" ];
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe' cfg.package serverProgram)
            "--config"
            configFile
            "--port"
            (toString cfg.port)
          ]
          ++ cfg.extraArgs
        );
        ExecReload = "${lib.getExe' pkgs.coreutils "kill"} -HUP $MAINPID";
        Restart = "on-failure";

        DynamicUser = true;
        StateDirectory = "wesnothd";
        RuntimeDirectory = "wesnothd";
        RuntimeDirectoryMode = "0750";
        WorkingDirectory = "/var/lib/wesnothd";

        # Hardening
        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged"
          "~@resources"
        ];
        UMask = "0077";
      };
    };
  };

  meta.maintainers = with lib.maintainers; [ iedame ];
}
