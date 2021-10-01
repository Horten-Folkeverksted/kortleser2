{ pkgs  ? import <nixos> {} }:

rec {
  omnikey = pkgs.stdenv.mkDerivation {
    pname = "read-omnikey";
    version = "0.1.0";

    buildInputs = with pkgs; [ (perl.withPackages (x: with x; [pcscperl])) ];

    unpackPhase = "true";
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp ${./read-omnikey.pl} $out/bin/read-omnikey
      chmod +x $out/bin/read-omnikey
      runHook postInstall
    '';
  };
}
