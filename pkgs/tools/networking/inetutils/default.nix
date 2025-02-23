{ stdenv, lib, fetchurl, ncurses, perl, help2man
, apparmorRulesFromClosure
}:

stdenv.mkDerivation rec {
  pname = "inetutils";
  version = "2.4";

  src = fetchurl {
    url = "mirror://gnu/${pname}/${pname}-${version}.tar.xz";
    sha256 = "sha256-F4nWsbGlff4qere1M+6fXf2cv1tZuxuzwmEu0I0PaLI=";
  };

  outputs = ["out" "apparmor"];

  patches = [
    # https://git.congatec.com/yocto/meta-openembedded/commit/3402bfac6b595c622e4590a8ff5eaaa854e2a2a3
    ./inetutils-1_9-PATH_PROCNET_DEV.patch
  ];

  nativeBuildInputs = [ help2man perl /* for `whois' */ ];
  buildInputs = [ ncurses /* for `talk' */ ];

  # Don't use help2man if cross-compiling
  # https://lists.gnu.org/archive/html/bug-sed/2017-01/msg00001.html
  # https://git.congatec.com/yocto/meta-openembedded/blob/3402bfac6b595c622e4590a8ff5eaaa854e2a2a3/meta-networking/recipes-connectivity/inetutils/inetutils_1.9.1.bb#L44
  preConfigure = let
    isCross = stdenv.hostPlatform != stdenv.buildPlatform;
  in lib.optionalString isCross ''
    export HELP2MAN=true
  '';

  configureFlags = [ "--with-ncurses-include-dir=${ncurses.dev}/include" ]
  ++ lib.optionals stdenv.hostPlatform.isMusl [ # Musl doesn't define rcmd
    "--disable-rcp"
    "--disable-rsh"
    "--disable-rlogin"
    "--disable-rexec"
  ] ++ lib.optional stdenv.isDarwin  "--disable-servers";

  # Test fails with "UNIX socket name too long", probably because our
  # $TMPDIR is too long.
  doCheck = false;

  installFlags = [ "SUIDMODE=" ];

  postInstall = ''
    mkdir $apparmor
    cat >$apparmor/bin.ping <<EOF
    $out/bin/ping {
      include <abstractions/base>
      include <abstractions/consoles>
      include <abstractions/nameservice>
      include "${apparmorRulesFromClosure { name = "ping"; } [stdenv.cc.libc]}"
      include <local/bin.ping>
      capability net_raw,
      network inet raw,
      network inet6 raw,
      mr $out/bin/ping,
    }
    EOF
  '';

  meta = with lib; {
    description = "Collection of common network programs";

    longDescription =
      '' The GNU network utilities suite provides the
         following tools: ftp(d), hostname, ifconfig, inetd, logger, ping, rcp,
         rexec(d), rlogin(d), rsh(d), syslogd, talk(d), telnet(d), tftp(d),
         traceroute, uucpd, and whois.
      '';

    homepage = "https://www.gnu.org/software/inetutils/";
    license = licenses.gpl3Plus;

    maintainers = with maintainers; [ matthewbauer ];
    platforms = platforms.unix;
  };
}
