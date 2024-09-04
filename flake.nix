{
    inputs = {
        nixpkgs.url = "github:NixOS/nixpkgs";
        goo.url = "github:doma-engineering/goo";
    };

    outputs = {self, nixpkgs, goo}:
        let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        in {
            defaultPackage.x86_64-linux = pkgs.hello;

            devShell.x86_64-linux =
                pkgs.mkShell {
                    buildInputs = [
                        pkgs.erlang_26
                        goo.defaultPackage.x86_64-linux
                    ];
                };
        };
}
