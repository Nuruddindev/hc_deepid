# {
#   description = "Flake for Holochain app development";

#   inputs = {
#     holonix.url = "github:holochain/holonix?ref=main";

#     nixpkgs.follows = "holonix/nixpkgs";
#     flake-parts.follows = "holonix/flake-parts";
#   };

#   outputs = inputs@{ flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
#     systems = builtins.attrNames inputs.holonix.devShells;
#     perSystem = { inputs', pkgs, ... }: {
#       formatter = pkgs.nixpkgs-fmt;

#       devShells.default = pkgs.mkShell {
#         packages = (with inputs'.holonix.packages; [
#           holochain
#           hc
#           hcterm
#           bootstrap-srv
#           lair-keystore
#           hc-scaffold
#           hn-introspect
#           rust # For Rust development, with the WASM target included for zome builds
#         ]) ++ (with pkgs; [
#           nodejs_24 # For UI development
#           binaryen # For WASM optimisation
#           # Add any other packages you need here
#         ]);

#         shellHook = ''
#           export PS1='\[\033[1;34m\][holonix:\w]\$\[\033[0m\] '
#         '';
#       };
#     };
#   };
# }

{
  description = "Flake for Holochain app development";
  inputs = {
    holonix.url = "github:holochain/holonix?ref=main-0.6";
    nixpkgs.follows = "holonix/nixpkgs";
    flake-parts.follows = "holonix/flake-parts";
     # TAMBAHKAN INI - Holochain Playground
    holochain-playground.url = "github:darksoil-studio/holochain-playground/main-0.6";
  };
  nixConfig = {
    extra-substituters = [
      "https://holochain-ci.cachix.org"
      # TAMBAHKAN INI - Binary cache untuk playground
      "https://darksoil-studio.cachix.org"
    ];
    extra-trusted-public-keys = [
      "holochain-ci.cachix.org-1:5IUSkZc0aoRS53rfkvH9Kid40NpyjwCMCzwRTXy+QN8="
      # TAMBAHKAN INI - Public key untuk playground
      "darksoil-studio.cachix.org-1:UEi+aujy44s41XL/pscLw37KEVpTEIn8N/kn7jO8rkc="
    ];
  };
  outputs = inputs@{ flake-parts, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = builtins.attrNames inputs.holonix.devShells;
    perSystem = { inputs', pkgs, ... }: {
      formatter = pkgs.nixpkgs-fmt;
      devShells.default = pkgs.mkShell {
        inputsFrom = [ inputs'.holonix.devShells.default ];
        packages = (with pkgs; [
          nodejs_22
          binaryen
          bun
          openssl
          pkg-config
          inputs'.holonix.packages.hc
          inputs'.holonix.packages.holochain
          inputs'.holonix.packages.lair-keystore
          # TAMBAHKAN INI - Playground binary
          inputs'.holochain-playground.packages.hc-playground
         
        ]);
        shellHook = ''
          export PS1='\[\033[1;34m\][holonix:\w]\$\[\033[0m\] '
          export OPENSSL_DIR="${pkgs.openssl.dev}"
          export OPENSSL_INCLUDE_DIR="${pkgs.openssl.dev}/include"
          export OPENSSL_LIB_DIR="${pkgs.openssl.out}/lib"
        '';
      };
    };
  };
}