{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.acmed;
  acmed = cfg.package;
  inherit (lib)
    mkEnableOption
    mkPackageOption
    mkOption
    mkIf
    ;
  inherit (lib.types)
    bool
    nullOr
    path
    str
    enum
    ;

  pathOf = file: "/etc/${config.environment.etc.${file}.target}";

  toml = pkgs.formats.toml { };
in
{
  options.services.acmed = {
    enable = mkEnableOption "acmed";
    package = mkPackageOption pkgs "acmed" { };
    settings = mkOption {
      type = toml.type;
      default = { };
      example = {
        account = [
          {
            name = "main";
            contacts = [
              {
                mailto = "example@example.com";
              }
            ];
          }
        ];
        certificate = [
          {
            endpoint = "Let's Encrypt v2 production";
            account = "main";
            hooks = [ "http-01-echo" ];
            identifiers = [
              {
                dns = "example.com";
                challenge = "http-01";
              }
            ];
          }
        ];
      };
      description = ''
        Settings to write to the configuration file. (See man 5 acmed.toml)
      '';
    };
    defaultConfig = mkOption {
      type = bool;
      default = true;
      example = false;
      description = ''
        Whether to include the default hooks and endpoint configuration for Let's Encrypt.
      '';
    };
    acceptLetsEncryptTerms = mkOption {
      type = bool;
      default = false;
      example = true;
      description = ''
        Whether to accept Let's Encrypt's terms of service.
        Required to use the included default endpoint configuration for Let's Encrypt.
      '';
    };
    configFile = mkOption {
      type = nullOr path;
      default = null;
      example = "/path/to/config.toml";
      description = ''
        Path to the configuration file. (See man 5 acmed.toml)
        If set, the configuration from the settings option won't be applied.
      '';
    };
    user = mkOption {
      type = str;
      default = "acmed";
      description = "The user acmed should run as.";
    };
    group = mkOption {
      type = str;
      default = "acmed";
      description = "The group acmed should run as.";
    };
    logLevel = mkOption {
      type = enum [
        "error"
        "warn"
        "info"
        "debug"
        "trace"
      ];
      default = "info";
      example = "debug";
      description = "The level of verbosity to be used for logging.";
    };
  };

  config = mkIf cfg.enable {
    services.acmed.settings = mkIf cfg.defaultConfig {
      include = [
        (pathOf "acmed/default_hooks.toml")
        (pathOf "acmed/letsencrypt.toml")
      ];
    };

    environment.systemPackages = [
      acmed.man
    ];

    environment.etc = {
      "acmed/default_hooks.toml".source = "${acmed}/etc/acmed/default_hooks.toml";
      "acmed/letsencrypt.toml" =
        if cfg.acceptLetsEncryptTerms then
          {
            text = builtins.replaceStrings [ "tos_agreed = false" ] [ "tos_agreed = true" ] (
              builtins.readFile "${acmed}/etc/acmed/letsencrypt.toml"
            );
          }
        else
          {
            source = "${acmed}/etc/acmed/letsencrypt.toml";
          };
      "acmed/acmed.toml" = mkIf (cfg.configFile == null) {
        source = toml.generate "acmed-config.toml" cfg.settings;
      };
    };

    systemd.services.acmed =
      let
        configFile = if cfg.configFile == null then pathOf "acmed/acmed.toml" else cfg.configFile;
      in
      {
        restartTriggers = [
          cfg.acceptLetsEncryptTerms
        ]
        ++ lib.optional (cfg.configFile == null) config.environment.etc."acmed/acmed.toml".source;
        # https://codeberg.org/rbd/acmed/src/branch/main/contrib/systemd/acmed.service
        description = "ACME client daemon";
        after = [ "network.target" ];
        documentation = [
          "man:acmed.toml(5)"
          "man:acmed(8)"
          "https://codeberg.org/rbd/acmed/wiki"
        ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = "/var/lib/acmed";
          RuntimeDirectory = "acmed";
          ExecStart = "${lib.getExe acmed} --foreground --config ${configFile} --pid-file /run/acmed/acmed.pid --log-syslog --log-level ${cfg.logLevel}";
          TimeoutStartSec = 3;
          TimeoutStopSec = 5;
          Restart = "on-failure";
          KillSignal = "SIGINT";

          NoNewPrivileges = "yes";
          PrivateDevices = "yes";
          PrivateTmp = "yes";
          PrivateUsers = "yes";
          ProtectClock = "yes";
          ProtectHostname = "yes";
          ProtectKernelTunables = "yes";
          ProtectKernelModules = "yes";
          ProtectKernelLogs = "yes";
          ProtectSystem = "yes";
          ReadWritePaths = "/etc/acmed /var/lib/acmed";
          RestrictRealtime = "yes";
          RestrictSUIDSGID = "yes";
          SystemCallFilter = "@system-service";
        };
      };

    systemd.tmpfiles.settings.acmed =
      let
        withMode = mode: {
          inherit mode;
          user = cfg.user;
          group = cfg.group;
        };
      in
      {
        # https://codeberg.org/rbd/acmed/src/branch/main/contrib/systemd/acmed.tmpfiles
        "/run/acmed".d = withMode "0755";
        "/run/acmed/acmed.pid".f = withMode "0644";
        "/var/lib/acmed".d = withMode "0755";
        "/var/lib/acmed/accounts".d = withMode "0700";
        "/var/lib/acmed/certs".d = withMode "0755";
      };

    users = {
      users = mkIf (cfg.user == "acmed") {
        acmed = {
          name = "acmed";
          group = cfg.group;
          isSystemUser = true;
        };
      };
      groups = mkIf (cfg.group == "acmed") { acmed = { }; };
    };
  };

  meta = {
    maintainers = with lib.maintainers; [
      dav-wolff
    ];
  };
}
