{ pkgs ? import <nixos> { } }:

let
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

  supervisor-conf = pkgs.writeText "supervisor.conf" ''
    [supervisord]
    logfile=/dev/stdout
    logfile_maxbytes = 0
    nodaemon = true

    [program:omnikey]
    command=${omnikey}/bin/read-omnikey

    [program:pcscd]
    environment=LIBCCID_ifdLogLevel="0x000F"
    command=${pkgs.pcsclite}/sbin/pcscd --foreground --debug --apdu --color
  '';

in

{
  inherit omnikey;
  # docker run --mount type=tmpfs,destination=/run -v /dev:/dev -it <image>
  image = pkgs.dockerTools.streamLayeredImage {
    name = "read-omnicard";
    contents = [pkgs.bashInteractive pkgs.coreutils pkgs.strace pkgs.libudev ];
    config = {
      Cmd = [
        "${pkgs.python3Packages.supervisor}/bin/supervisord" "-c" "${supervisor-conf}"
      ];
    };
  };
}
