{
  autoPatchelfHook,
  fetchzip,
  glib,
  lib,
  libxcb,
  microsoft-edge,
  nspr,
  nss,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "msedgedriver";
  version = "153.0.4234.48";

  src =
    let
      driverArch =
        {
          aarch64-darwin = "mac64_m1";
          aarch64-linux = "arm64";
          x86_64-linux = "linux64";
        }
        .${stdenvNoCC.hostPlatform.system};
    in
    fetchzip {
      url = "https://msedgedriver.microsoft.com/${finalAttrs.version}/edgedriver_${driverArch}.zip";
      hash =
        {
          mac64_m1 = "sha256-Ar6DxbhErwTmS1u11qmVwnTVsQDk6X8P+RgzO0IKXOw=";
          arm64 = "sha256-ls4T7uIH25qI44w6Cuh9kZJQRRuLr2T//f+Qi+Mn+S0=";
          linux64 = "sha256-5gCrPPjYC/AmsO5vSNTX/r3hm6wATvNeIxRt4TYyZhY=";
        }
        .${driverArch};
      stripRoot = false;
    };

  buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    glib
    libxcb
    nspr
    nss
  ];

  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    runHook preInstall

    install -D msedgedriver $out/bin/msedgedriver

    runHook postInstall
  '';

  meta = {
    homepage = "https://developer.microsoft.com/en-us/microsoft-edge/tools/webdriver";
    description = "WebDriver implementation that controls an Edge browser running on the local machine";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    license = lib.licenses.unfree;
    maintainers = microsoft-edge.meta.maintainers;
    platforms = lib.platforms.darwin ++ lib.platforms.linux;
    mainProgram = "msedgedriver";
  };
})
