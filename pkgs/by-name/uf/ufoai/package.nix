{
  lib,
  stdenv,
  fetchurl,
  libtheora,
  xvidcore,
  libGLU,
  libGL,
  curl,
  libjpeg,
  libpng,
  gawk,
  gnugrep,
  gnused,
  gettext,
  cunit,
  doxygen,
  SDL2,
  SDL2_mixer,
  SDL2_image,
  SDL2_ttf,
  python3,
  pkg-config,
  enableEditor ? false,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ufoai";
  version = "2.5";
  src = fetchurl {
    url = "mirror://sourceforge/ufoai/ufoai-${finalAttrs.version}-source.tar.bz2";
    hash = "sha256-DHzDvJ7+snb3HL5u6P98dvmNGD3nnxoGn6YwWc8YKo8=";
  };

  srcData = fetchurl {
    url = "mirror://sourceforge/ufoai/ufoai-${finalAttrs.version}-data.tar";
    hash = "sha256-XnBqQkr/ai6jCkx5gSnWME6Jc4fq34CFKBKbUSt9zbA=";
  };

  patches = lib.optional stdenv.hostPlatform.isAarch64 [
    ./patch-bug-5345.diff
    ./patch-bug-5336.diff
  ];

  env = {
    NIX_CFLAGS_COMPILE = "-fcommon";
    NIX_CFLAGS_LINK = toString (
      lib.optionals stdenv.hostPlatform.isLinux [
      "-lgcc_s"
      "-lm"
      ]
    );
  };

  preConfigure = ''tar xvf "${finalAttrs.srcData}"'';

  configureFlags = [
    "--enable-release"
  ]
  ++ lib.optional enableEditor "--enable-uforadiant"
  ++ lib.optional stdenv.hostPlatform.isx86 "--enable-sse"
  ++ lib.optional stdenv.hostPlatform.isDarwin "--target-os=darwin";

  nativeBuildInputs = [
    pkg-config
    gawk
    gettext
    gnugrep
    gnused
  ];

  buildInputs = [
    libtheora
    xvidcore
    libGLU
    libGL
    curl
    libjpeg
    libpng
    gettext
    cunit
    doxygen
    SDL2
    SDL2_mixer
    SDL2_image
    SDL2_ttf
    python3
  ];

  meta = {
    homepage = "http://ufoai.org";
    description = "Squad-based tactical strategy game in the tradition of X-Com";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [ iedame ];
    platforms = lib.platforms.unix;
  };
})
