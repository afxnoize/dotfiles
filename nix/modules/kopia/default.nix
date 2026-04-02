{ pkgs-unstable, ... }:

let
  kopia = pkgs-unstable.kopia;
in
{
  home.packages = [ kopia ];

  systemd.user.services.kopia-backup = {
    Unit = {
      Description = "Kopia snapshot backup";
      After = [ "network-online.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${kopia}/bin/kopia snapshot create --all";
    };
  };

  systemd.user.timers.kopia-backup = {
    Unit = {
      Description = "Daily Kopia backup";
    };
    Timer = {
      OnCalendar = "daily";
      RandomizedDelaySec = "1h";
      Persistent = true;
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
