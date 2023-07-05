{ pkgs, config, lib, inputs, ... }:

let
  cfg = config.languages.rust;
  setup = ''
    inputs:
      fenix:
        url: github:nix-community/fenix
        inputs:
          nixpkgs:
            follows: nixpkgs
  '';

  fenix' = dbg: inputs.fenix or
    (throw "to use languages.rust.${dbg}, you must add the following to your devenv.yaml:\n\n${setup}");
  fenix = dbg: (fenix' dbg).packages.${pkgs.stdenv.system};
in
{
  options.languages.rust = {
    enable = lib.mkEnableOption "tools for Rust development";

    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalExpression "nixpkgs";
      default = pkgs.symlinkJoin {
        name = "nixpkgs-rust";
        paths = with pkgs; [
          rustc
          cargo
          rustfmt
          clippy
          rust-analyzer
        ];
      };
      description = "Rust package including rustc and Cargo.";
    };

    components = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" ];
      defaultText = lib.literalExpression ''[ "rustc" "cargo" "clippy" "rustfmt" "rust-analyzer" ]'';
      description = ''
        List of [Rustup components](https://rust-lang.github.io/rustup/concepts/components.html)
        to install. Defaults to those available in ${lib.literalExpression "nixpkgs"}.
      '';
    };

    rust-src = lib.mkOption {
      type = lib.types.path;
      default = pkgs.rustPlatform.rustLibSrc;
      defaultText = "${lib.literalExpression "pkgs.rustPlatform.rustLibSrc"} or "
        + "${lib.literalExpression "toolchain.rust-src"}, depending on if a fenix toolchain is set.";
      description = ''
        The path to the rust-src Rustup component. Note that this is necessary for some tools
        like rust-analyzer to work.
      '';
    };

    toolchain = lib.mkOption {
      # TODO: better type with https://nixos.org/manual/nixos/stable/index.html
      type = lib.types.nullOr lib.types.anything;
      default = null;
      defaultText = lib.literalExpression "fenix.packages.stable";
      description = "The [fenix toolchain](https://github.com/nix-community/fenix#toolchain) to use.";
    };

    version = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "stable" "beta" "latest" ]);
      default = null;
      defaultText = lib.literalExpression "null";
      description = "The toolchain version to install.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      packages = [ cfg.package ]
        ++ lib.optional pkgs.stdenv.isDarwin pkgs.libiconv;

      env.RUST_SRC_PATH = cfg.rust-src;

      # enable compiler tooling by default to expose things like cc
      languages.c.enable = lib.mkDefault true;
    })
    (lib.mkIf (cfg.toolchain != null) {
      languages.rust.package = lib.mkForce (cfg.toolchain.withComponents cfg.components);
      languages.rust.rust-src = lib.mkForce "${cfg.toolchain.rust-src}/lib/rustlib/src/rust/library";
    })
    (lib.mkIf (cfg.version != null) {
      languages.rust.toolchain = lib.mkForce ((fenix "version").${cfg.version});
    })
  ];
}
