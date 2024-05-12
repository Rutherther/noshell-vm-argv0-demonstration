# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:

let
  noshell-old = pkgs.callPackage (
    (builtins.fetchTarball "https://github.com/viperML/noshell/archive/dbbfaa6368c559dcf5ded621e7a96ed4b3ddf477.tar.gz") + "/package.nix") {};

  noshell-new = pkgs.callPackage (
    (builtins.fetchTarball "https://github.com/Rutherther/noshell/archive/48ce746f5a6c3859dd3391eb64ebe2dac9bdefe8.tar.gz") + "/package.nix") {};

  # Print arguments
  noshell-old-patched = noshell-old.overrideAttrs {
    patches = ./noshell-old.patch;
  };
  noshell-new-patched = noshell-new.overrideAttrs {
    patches = ./noshell.patch;
  };

  # Apparently NixOS modules handle shells by putting them to current system
  # bin folder. That cannot work here as there is a collision, and only one noshell is used...
  noshell-old-wrapped = pkgs.symlinkJoin {
    name = "noshell-old-wrapped";
    paths = [ noshell-old-patched ];
    postBuild = ''
      mv $out/bin/noshell $out/bin/noshell-old
    '';
    passthru = {
      shellPath = "/bin/noshell-old";
    };
  };

  mkNoshellTmpfiles = user: shell: {
    "new-user-env" = {
      "/home/${user}/.config" = {
        "d" = {
          user = user;
          group = "users";
          mode = "0755";
        };
      };
      "/home/${user}/.config/shell" = {
        "L+" = {
          user = "-";
          group = "-";
          mode = "-";
          # argument = "/run/current-system/sw/bin/zsh";
          argument = shell;
        };
      };
      "/home/${user}/.profile" = {
        f = {
          user = user;
          group = "users";
          mode = "0660";
          argument = ''
            echo "Home profile sourced"
          '';
        };
      };
      "/home/${user}/.zprofile" = {
        f = {
          user = user;
          group = "users";
          mode = "0660";
          argument = ''
            echo "Home zprofile sourced"
          '';
        };
      };
      "/home/${user}/.zshrc" = {
        f = {
          user = user;
          group = "users";
          mode = "0660";
          argument = ''
            echo "Home zshrc sourced"
          '';
        };
      };
      "/home/${user}/.bashrc" = {
        f = {
          user = user;
          group = "users";
          mode = "0660";
          argument = ''
            echo "Home bashrc sourced"
          '';
        };
      };
    };
  };
in {
  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  systemd.tmpfiles.settings = lib.mkMerge [
    {
      "zsh-shells-emulation-demonstration" = {
        "/shells/bash" = {
          "L+" = {
            argument = "/run/current-system/sw/bin/zsh";
          };
        };
        "/shells/shell" = {
          "L+" = {
            argument = "/run/current-system/sw/bin/zsh";
          };
        };
      };
    }
    (mkNoshellTmpfiles "new" "/run/current-system/sw/bin/zsh")
    (mkNoshellTmpfiles "old" "/run/current-system/sw/bin/zsh")
    (mkNoshellTmpfiles "new-bash-emulation" "/shells/bash")
    (mkNoshellTmpfiles "new-sh-emulation" "/shells/shell") # if the $0 contains shell, it's going to emulate sh!
  ];

  environment.etc."zprofile".text = ''
     echo "Etc zprofile sourced"
  '';

  environment.etc."bashrc".text = ''
     echo "Etc bashrc sourced"
  '';

  environment.etc."zshrc".text = ''
     echo "Etc zshrc sourced"
  '';

  users.users.root.password = "vm";
  users.users.new = {
    isNormalUser = true;
    shell = noshell-new-patched;
    password = "vm";
  };
  users.users.new-bash-emulation = {
    isNormalUser = true;
    shell = noshell-new-patched;
    password = "vm";
  };
  users.users.new-sh-emulation = {
    isNormalUser = true;
    shell = noshell-new-patched;
    password = "vm";
  };
  users.users.old = {
    isNormalUser = true;
    shell = noshell-old-wrapped;
    password = "vm";
  };

  environment.systemPackages = [
    pkgs.zsh
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  system.stateVersion = "24.05";
}
