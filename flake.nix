{
  description = "Dev shell for 2D graphics language compiler";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  outputs = { self, nixpkgs }: {
    devShells = {
      x86_64-linux = {
        default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
          buildInputs = [
            nixpkgs.legacyPackages.x86_64-linux.gcc
            nixpkgs.legacyPackages.x86_64-linux.flex
            nixpkgs.legacyPackages.x86_64-linux.bison
            nixpkgs.legacyPackages.x86_64-linux.gnumake
          ];
        };
      };
    };
  };
}
