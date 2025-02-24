{ ghcVersion }:

let
  sources = (import ./sources.nix);
  pkgs = import sources.nixpkgs {};
in
pkgs.haskell.lib.buildStackProject {
  name = "cachix-stack-shell";

  ghc = pkgs.haskell.compiler."${ghcVersion}";

  buildInputs = [
    pkgs.lzma
    pkgs.zlib
    pkgs.nix
    pkgs.boost
  ];
}
