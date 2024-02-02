{ pkgs, lib, config, inputs, ... }:

let
  cfg = config.services.kratos;

  nixpkgs-ory = inputs.nixpkgs-ory or (throw ''
    You need to add the following to your devenv.yaml:

    inputs:
      nixpkgs-ory:
        url: "git+https://codeberg.org/empunkt/nixpkgs-ory.git";
        inputs:
          nixpkgs:
            follows: nixpkgs
          devenv:
            follows: devenv
  '');

  configFormat = pkgs.formats.json { };

  configDir = config.env.DEVENV_STATE + "/ory/kratos/config";

  kratosConfig = cfg.config // {
    identity = {
      default_schema_id = "default";
      schemas = [
        {
          id = "default";
          url = "file://${configDir}/identity.schema.json";
        }
      ];
    };
  };

  defaultIdentitySchema = builtins.fromJSON (builtins.readFile "${cfg.package}/config/default/identity.schema.json");
  defaultConfig = builtins.fromJSON (builtins.readFile "${cfg.package}/config/default/kratos.json");

  migrationScript = pkgs.writeShellScriptBin "kratos-migrate" ''
    set -euo pipefail

    exec ${cfg.package}/bin/kratos -c "${configDir}/kratos.json" migrate sql --yes ${kratosConfig.dsn}
  '';

  runScript = pkgs.writeShellScriptBin "kratos-run" ''
    set -euo pipefail

    exec ${cfg.package}/bin/kratos -c "${configDir}/kratos.json" serve
  '';

  startScript = pkgs.writeShellScriptBin "start-kratos" ''
    set -euo pipefail

    if [[ ! -d "${configDir}" ]]; then
      mkdir -p ${configDir}

      install -m 0644 \
        '${configFormat.generate "identity.schema.json" cfg.identitySchema}' \
        "${configDir}/identity.schema.json"

      install -m 0644 \
        '${configFormat.generate "kratos.json" kratosConfig}' \
        "${configDir}/kratos.json"
    fi

    ${migrationScript}/bin/kratos-migrate
    ${runScript}/bin/kratos-run
  '';
in
{
  options.services.kratos = {
    enable = lib.mkEnableOption "kratos";

    package = lib.mkOption {
      type = lib.types.package;
      default = nixpkgs-ory.packages.${pkgs.stdenv.system}."ory-kratos-v1.0.0";
      defaultText = "nixpkgs-ory.packages.\${pkgs.stdenv.system}.\"ory-kratos-v1.0.0\"";
      description = "The kratos package to use.";
    };

    identitySchema = lib.mkOption {
      type = configFormat.type;
      default = defaultIdentitySchema;
      description = ''
        Content of the identity.schema.json

        Refer to https://www.ory.sh/docs/kratos/manage-identities/overview for more details.
      '';
      example = defaultIdentitySchema;
    };

    config = lib.mkOption {
      type = configFormat.type;
      default = defaultConfig;
      description = ''
        Content of the kratos.json

        Refer to https://www.ory.sh/docs/kratos/reference/configuration for more details.

        There is also a genarator available at https://www.ory.sh/docs/kratos/reference/configuration-editor.

        The `identity` attribute will be set automatically to refer to the `itentitySchema` option. So, whatever is
        configured here, doesn't have any effect.
      '';
      example = defaultConfig;
    };
  };

  config = lib.mkIf cfg.enable {
    packages = [ cfg.package startScript ];

    processes.kratos = {
      exec = "${startScript}/bin/start-kratos";
    };
  };
}
