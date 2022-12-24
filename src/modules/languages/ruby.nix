{ pkgs, config, lib, ... }:

let
  cfg = config.languages.ruby;
in
{
  options.languages.ruby = {
    enable = lib.mkEnableOption "Enable tools for Ruby development";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ruby_3_1;
      defaultText = "pkgs.ruby_3_1";
      description = "The Ruby package to use.";
    };

    compilers = {
      enable = lib.mkEnableOption "Enable common compiler packages for gem compilation";
      packages = lib.mkOption {
        default = [ pkgs.stdenv pkgs.gnumake pkgs.clang pkgs.gcc ];
        defaultText = lib.literalExpression "[ pkgs.stdenv pkgs.gnumake pkgs.clang pkgs.gcc ]";
        type = lib.types.listOf lib.types.package;
        description = lib.mdDoc ''
          Packages to add to the PATH, so the bundler native extensions can build.
          Expected to be extended per project, based on the bundler dependencies.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    packages = with pkgs; [
      cfg.package
      bundler
    ] ++ (lib.optionals cfg.compilers.enable cfg.compilers.packages);

    env.BUNDLE_PATH = config.env.DEVENV_STATE + "/.bundle";

    env.GEM_HOME = "${config.env.BUNDLE_PATH}/${cfg.package.rubyEngine}/${cfg.package.version.libDir}";

    enterShell =
      let libdir = cfg.package.version.libDir;
      in
      ''
        export RUBYLIB="$DEVENV_PROFILE/${libdir}:$DEVENV_PROFILE/lib/ruby/site_ruby:$DEVENV_PROFILE/lib/ruby/site_ruby/${libdir}:$DEVENV_PROFILE/lib/ruby/site_ruby/${libdir}/${pkgs.system}:$RUBYLIB"
        export GEM_PATH="$GEM_HOME/gems:$GEM_PATH"
        export PATH="$GEM_HOME/bin:$PATH"
      '';
  };
}
