{
  lib,
  stdenv,
  fetchFromGitHub,

  autoconf,
  cmake,
  nasm,
  pkg-config,
  xxd,

  libGL,
  libx11,
  vulkan-headers,
  vulkan-loader,

  callPackage,
  pkgsCross,
}:

let
  x86Bintools = pkgsCross.gnu64.buildPackages.binutils;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "felix86";
  version = "26.11";

  src = fetchFromGitHub {
    owner = "OFFTKP";
    repo = "felix86";
    tag = finalAttrs.version;
    hash = "sha256-bZicwdVuG2BUb3+5J7vUngQh9qXBsezzo11wZRkOYog=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    autoconf
    cmake
    nasm
    pkg-config
    vulkan-headers
    xxd
  ];

  buildInputs = [
    libGL
    libx11
    vulkan-loader
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 felix86 $out/bin/felix86

    runHook postInstall
  '';

  cmakeFlags = [
    (lib.cmakeBool "ZYDIS_BUILD_DOXYGEN" false)
    (lib.cmakeBool "BUILD_TESTS" true)
    (lib.cmakeBool "FELIX86_MONTHLY_RELEASE" true)
    # x86-64 binutils to link the guest vDSO
    (lib.cmakeFeature "FELIX86_X86_CROSS" "${x86Bintools}/bin/${x86Bintools.targetPrefix}")
  ];

  passthru.tests = callPackage ./test.nix { };

  meta = {
    description = "x86 and x86-64 userspace emulator for RISC-V Linux";
    homepage = "https://github.com/OFFTKP/felix86";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ eljamm ];
    teams = with lib.teams; [ ngi ];
    mainProgram = "felix86";
    platforms = [ "riscv64-linux" ];
  };
})
