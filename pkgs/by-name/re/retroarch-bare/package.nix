{
  lib,
  stdenv,
  # deps
  alsa-lib,
  dbus,
  fetchFromGitHub,
  ffmpeg_7,
  flac,
  freetype,
  gamemode,
  gitUpdater,
  libdrm,
  libGL,
  libGLU,
  libpulseaudio,
  libv4l,
  libx11,
  libxdmcp,
  libxext,
  libxkbcommon,
  libxml2,
  libxxf86vm,
  makeBinaryWrapper,
  mbedtls,
  moltenvk,
  libgbm,
  nixosTests,
  nvidia_cg_toolkit,
  pipewire,
  pkg-config,
  python3,
  qt6,
  SDL2,
  spirv-tools,
  udev,
  vulkan-loader,
  wayland,
  wayland-scanner,
  wrapGAppsHook3,
  zlib,
  # wrapper deps
  libretro,
  libretro-core-info,
  retroarch-assets,
  retroarch-bare,
  retroarch-joypad-autoconfig,
  writeText,
  symlinkJoin,
  # params
  enableNvidiaCgToolkit ? false,
  withGamemode ? stdenv.hostPlatform.isLinux,
  withVulkan ? stdenv.hostPlatform.isLinux,
  withWayland ? stdenv.hostPlatform.isLinux,
  # On Darwin, build with this Xcode instead of the system default. This can be a path to
  # Xcode.app, e.g. "/Applications/Xcode.app", or one of the `darwin.xcode_*` packages.
  # Set it with an overlay, so that the wrapper and the cores use it too.
  withXcodePath ? null,
}:

let
  runtimeLibs =
    lib.optional withVulkan vulkan-loader ++ lib.optional withGamemode (lib.getLib gamemode);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "retroarch-bare";
  version = "1.22.2";

  src = fetchFromGitHub {
    owner = "libretro";
    repo = "RetroArch";
    hash = "sha256-+3jgoh6OVbPzW5/nCvpB1CRgkMTBxLkYMm6UV16/cfU=";
    rev = "v${finalAttrs.version}";
  };

  patches = lib.optionals stdenv.hostPlatform.isDarwin [
    # Without this, opening a video crashes, as the built-in player asks for legacy OpenGL
    ./darwin-legacy-gl-driver.patch
  ];

  ${if stdenv.hostPlatform.isDarwin then "postPatch" else null} = ''
    # Xcode bundles the MoltenVK it finds here, and RetroArch loads it at runtime
    cp ${lib.getLib moltenvk}/lib/libMoltenVK.dylib \
      pkg/apple/Frameworks/MoltenVK.xcframework/macos-arm64_x86_64/MoltenVK.framework/Versions/A/MoltenVK

    # Same as the --disable-update_* configureFlags, and ignore any upstream deps on the host
    substituteInPlace pkg/apple/BaseConfig.xcconfig \
      --replace-fail 'OTHER_CFLAGS = $(inherited) -DHAVE_UPDATE_ASSETS' "" \
      --replace-fail 'OTHER_CFLAGS = $(inherited) -DHAVE_UPDATE_CORE_INFO' "" \
      --replace-fail '#include? "/usr/local/share/retroarch-apple-deps/deps.xcconfig"' ""
    substituteInPlace pkg/apple/Metal.xcconfig --replace-fail ' -DHAVE_UPDATE_CORES' ""
  '';

  # xcodebuild doesn't see these on darwin, as buildPhase runs it with env -i
  nativeBuildInputs =
    lib.optionals (!stdenv.hostPlatform.isDarwin) [
      pkg-config
      qt6.wrapQtAppsHook
      wrapGAppsHook3
    ]
    ++ lib.optional withWayland wayland
    ++ lib.optional (runtimeLibs != [ ] || stdenv.hostPlatform.isDarwin) makeBinaryWrapper;

  buildInputs =
    lib.optionals (!stdenv.hostPlatform.isDarwin) [
      ffmpeg_7
      flac
      freetype
      libGL
      libGLU
      libxml2
      mbedtls
      python3
      qt6.qtbase
      SDL2
      spirv-tools
      zlib
    ]
    ++ lib.optional enableNvidiaCgToolkit nvidia_cg_toolkit
    ++ lib.optional withVulkan vulkan-loader
    ++ lib.optionals withWayland [
      wayland
      wayland-scanner
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      alsa-lib
      dbus
      libx11
      libxdmcp
      libxext
      libxxf86vm
      libdrm
      libpulseaudio
      libv4l
      libxkbcommon
      libgbm
      pipewire
      udev
    ];

  enableParallelBuilding = true;

  # Upstream builds macOS with Xcode. nixpkgs can't provide it, so like macvim this relies on the
  # system's Xcode, or on withXcodePath.
  ${if stdenv.hostPlatform.isDarwin then "dontConfigure" else null} = true;

  configureFlags = [
    "--disable-update_cores"
    "--disable-builtinmbedtls"
    "--enable-systemmbedtls"
    "--disable-builtinzlib"
    # https://github.com/libretro/RetroArch/issues/18370
    # "--disable-builtinflac"
    "--disable-update_assets"
    "--disable-update_core_info"
  ]
  ++ lib.optionals stdenv.hostPlatform.isLinux [
    "--enable-dbus"
    "--enable-egl"
    "--enable-kms"
  ];

  # env -i keeps stdenv's compiler and SDK environment away from xcodebuild, as DEVELOPER_DIR would
  # otherwise point it at nixpkgs' SDK.
  #
  # The Metal Toolchain is a separate component, needed even though Vulkan is the default driver.
  # If this fails looking for `metal`, see `xcodebuild -showComponent metalToolchain`, and install
  # that build with `xcodebuild -downloadComponent metalToolchain -buildVersion <version>`.
  #
  # The MBEDTLS_BUILTIN_FLAG and search path settings replace the vendored mbedtls, like
  # --disable-builtinmbedtls and --enable-systemmbedtls. The FFmpeg and SDL2 flags are the ones
  # from upstream's retroarch-apple-deps.
  ${if stdenv.hostPlatform.isDarwin then "buildPhase" else null} = ''
    runHook preBuild

    env -i SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" PATH=/usr/bin:/bin:/usr/sbin:/sbin ${
      lib.optionalString (
        withXcodePath != null
      ) "DEVELOPER_DIR=${lib.escapeShellArg "${withXcodePath}/Contents/Developer"}"
    } /usr/bin/xcodebuild \
      -project pkg/apple/RetroArch_Metal.xcodeproj \
      -scheme RetroArch \
      -configuration Release \
      -destination generic/platform=macOS \
      -derivedDataPath "$NIX_BUILD_TOP/derivedData" \
      -jobs "$NIX_BUILD_CORES" \
      ARCHS=${stdenv.hostPlatform.darwinArch} \
      MACOSX_DEPLOYMENT_TARGET=${stdenv.hostPlatform.darwinMinVersion} \
      MBEDTLS_BUILTIN_FLAG= \
      'HEADER_SEARCH_PATHS=$(inherited) ${lib.getDev mbedtls}/include ${lib.getDev ffmpeg_7}/include ${lib.getDev SDL2}/include/SDL2' \
      'OTHER_CFLAGS=$(inherited) -DHAVE_FFMPEG -DHAVE_AVCODEC -DHAVE_AVDEVICE -DHAVE_AVFORMAT -DHAVE_AVUTIL -DHAVE_SWRESAMPLE -DHAVE_SWSCALE -DHAVE_SDL2 -D_THREAD_SAFE' \
      'OTHER_LDFLAGS=$(inherited) -L${lib.getLib mbedtls}/lib -lmbedtls -lmbedx509 -lmbedcrypto -L${lib.getLib ffmpeg_7}/lib -lavcodec -lavdevice -lavformat -lavutil -lswresample -lswscale -L${lib.getLib SDL2}/lib -lSDL2' \
      CODE_SIGNING_ALLOWED=NO \
      build

    runHook postBuild
  '';

  ${if stdenv.hostPlatform.isDarwin then "installPhase" else null} = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -R "$NIX_BUILD_TOP/derivedData/Build/Products/Release/RetroArch.app" $out/Applications/
    makeWrapper $out/Applications/RetroArch.app/Contents/MacOS/RetroArch $out/bin/retroarch

    runHook postInstall
  '';

  postInstall =
    lib.optionalString (runtimeLibs != [ ]) ''
      wrapProgram $out/bin/retroarch \
        --prefix LD_LIBRARY_PATH ':' ${lib.makeLibraryPath runtimeLibs}
    ''
    + lib.optionalString enableNvidiaCgToolkit ''
      wrapProgram $out/bin/retroarch-cg2glsl \
        --prefix PATH ':' ${lib.makeBinPath [ nvidia_cg_toolkit ]}
    ''
    + lib.optionalString (!stdenv.hostPlatform.isDarwin) ''
      mkdir -p $out/share/icons/hicolor/scalable
      mv $out/share/{pixmaps,icons/hicolor/scalable/apps}
    '';

  preFixup = lib.optionalString (!enableNvidiaCgToolkit && !stdenv.hostPlatform.isDarwin) ''
    rm $out/bin/retroarch-cg2glsl
    rm $out/share/man/man6/retroarch-cg2glsl.6*
  '';

  # Xcode may be located in an arbitrary place and it's not clear what system-level components it
  # requires, so allow full filesystem access. When sandboxed, this still blocks the network.
  sandboxProfile = lib.optionalString stdenv.hostPlatform.isDarwin ''
    (allow file-read* file-write* process-exec mach-lookup)
    ; block homebrew dependencies
    (deny file-read* file-write* process-exec mach-lookup (subpath "/usr/local") (with no-log))
  '';

  passthru = {
    tests = nixosTests.retroarch;
    updateScript = gitUpdater {
      rev-prefix = "v";
    };
    wrapper =
      {
        cores ? [ ],
        settings ? { },
      }:
      import ./wrapper.nix {
        inherit
          lib
          libretro
          makeBinaryWrapper
          retroarch-bare
          stdenv
          writeText
          symlinkJoin
          cores
          ;
        settings = {
          assets_directory = "${retroarch-assets}/share/retroarch/assets";
          joypad_autoconfig_dir = "${retroarch-joypad-autoconfig}/share/libretro/autoconfig";
          libretro_info_path = "${libretro-core-info}/share/retroarch/cores";
        }
        // settings;
      };
  };

  meta = {
    homepage = "https://libretro.com";
    description = "Multi-platform emulator frontend for libretro cores";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.unix;
    # hydra can't build this on darwin as long as we rely on Xcode and sandboxProfile
    hydraPlatforms = lib.platforms.linux;
    changelog = "https://github.com/libretro/RetroArch/blob/v${finalAttrs.version}/CHANGES.md";
    maintainers = with lib.maintainers; [
      kolbycrouch
    ];
    teams = [ lib.teams.libretro ];
    mainProgram = "retroarch";
    mainDarwinApp = "RetroArch.app";
  };
})
