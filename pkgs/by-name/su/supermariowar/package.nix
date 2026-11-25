{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  sdl3,
  sdl3-image,
  sdl3-mixer,
  toml11,
  zlib,
  unstableGitUpdater,
  makeWrapper,
}:

let
  # The game needs the CMake package from the upstream author's ENet fork
  enet-src = fetchFromGitHub {
    owner = "mmatyas";
    repo = "enet";
    rev = "74d43e850f5abda0e5f565caa5d54f462bc210fd";
    hash = "sha256-hpVKt0vIlaSdwUmPc+a1vUd3FQ7va9Q0yd9Ed12UdTo=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "supermariowar";
  version = "2026-05-unstable-2026-11-22";

  src = fetchFromGitHub {
    owner = "mmatyas";
    repo = "supermariowar";
    rev = "166dde1020cd024b19782a6068f8665beef54a94";
    hash = "sha256-mVzd3+fIwu4Ml0y+oQvhQ5Ra1b+gAAUUi7ixZnPx6Hc=";
    fetchSubmodules = true;
  };

  patches = [
    # Find the system zlib with the FindZLIB module
    ./system-zlib.patch
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    sdl3
    sdl3-image
    sdl3-mixer
    toml11
    zlib
  ];

  cmakeFlags = [
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_ENET" "${enet-src}")
  ];

  doCheck = true;

  postInstall = ''
    # Installed by the bundled ENet, the game links it statically
    rm -r $out/include $out/lib

    mkdir -p $out/bin

    for app in smw smw-leveledit smw-worldedit; do
      makeWrapper $out/games/$app $out/bin/$app \
        --add-flags "--datadir $out/share/games/smw"
    done

    ln -s $out/games/smw-server $out/bin/smw-server
  '';

  passthru.updateScript = unstableGitUpdater { };

  meta = {
    description = "Fan-made multiplayer Super Mario Bros. style deathmatch game";
    homepage = "https://github.com/mmatyas/supermariowar";
    changelog = "https://github.com/mmatyas/supermariowar/blob/${finalAttrs.src.rev}/CHANGELOG";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [ theobori ];
    mainProgram = "smw";
    platforms = lib.platforms.linux;
  };
})
