{
  lib,
  stdenv,
  fetchurl,
  autoreconfHook,
  dbus,
  fzssh,
  gettext,
  gnutls,
  libfilezilla,
  libiconvReal,
  libidn,
  nettle,
  pkg-config,
  pugixml,
  sqlite,
  tinyxml,
  boost,
  wrapGAppsHook3,
  wxwidgets_3_2,
  gtk3,
  xdg-utils,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "filezilla";
  version = "3.71.1";

  src = fetchurl {
    # Upstream download link was made unstable on purpose.
    # See https://trac.filezilla-project.org/ticket/13186
    url = "https://sources.archlinux.org/other/filezilla/filezilla-${finalAttrs.version}.tar.xz";
    hash = "sha256-Pfm5s+Wyw33G2ey4g1VKuhQKAuxHw9a1IzO/FzOvTaQ=";
  };

  configureFlags = [
    "--disable-manualupdatecheck"
    "--disable-autoupdatecheck"
    "--with-wx-prefix=${wxwidgets_3_2}"
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    "--with-pugixml=builtin"
  ];

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    wrapGAppsHook3
    xdg-utils
  ];

  buildInputs = [
    boost
    fzssh
    gettext
    gnutls
    libfilezilla
    libidn
    nettle
    sqlite
    tinyxml
    wxwidgets_3_2
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    dbus
    gtk3
    pugixml
  ];

  strictDeps = true;
  enableParallelBuilding = true;

  preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
    gappsWrapperArgs+=(
      --suffix PATH : "${lib.makeBinPath [ xdg-utils ]}"
    )
  '';

  postInstall = lib.optionalString stdenv.hostPlatform.isDarwin ''
    mkdir -p "$out/Applications"
    cp -R FileZilla.app "$out/Applications/"

    framework="$out/Applications/FileZilla.app/Contents/Frameworks"

    # FileZilla's macOS bundle contains Apple's libiconv, while
    # libidn2 requires GNU libiconv.
    mv "$framework/libiconv.2.dylib" \
      "$framework/libiconv-apple.2.dylib"

    install_name_tool \
      -id "@loader_path/libiconv-apple.2.dylib" \
      "$framework/libiconv-apple.2.dylib"

    # Bundle GNU libiconv for libidn2.
    cp "${libiconvReal}/lib/libiconv.2.dylib" \
      "$framework/libiconv.2.dylib"

    install_name_tool \
      -id "@loader_path/libiconv.2.dylib" \
      "$framework/libiconv.2.dylib"

    # These libraries use Apple's libiconv ABI.
    for dylib in \
      "$framework"/libfilezilla*.dylib \
      "$framework"/libwx*.dylib \
      "$framework"/libintl*.dylib
    do
      if [ -f "$dylib" ]; then
        install_name_tool \
          -change "@loader_path/libiconv.2.dylib" \
          "@loader_path/libiconv-apple.2.dylib" \
          "$dylib"
      fi
    done
  '';

  meta = {
    homepage = "https://filezilla-project.org/";
    description = "Graphical FTP, FTPS and SFTP client";
    longDescription = ''
      FileZilla Client is a free, open source FTP client. It supports
      FTP, SFTP, and FTPS (FTP over SSL/TLS). The client is available
      under many platforms; binaries for Windows, Linux and macOS
      are provided.
    '';
    license = lib.licenses.gpl2;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
    maintainers = with lib.maintainers; [
      iedame
      pSub
    ];
  };
})
