{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  nasm,
}:

rustPlatform.buildRustPackage rec {
  pname = "sic-image-cli";
  version = "0.24.0";

  src = fetchFromGitHub {
    owner = "foresterre";
    repo = "sic";
    rev = "v${version}";
    hash = "sha256-pnnMRRccxSA5F6oIbe9wvdMmuSUMI7Da+NtwyH2psjo=";
  };

  cargoHash = "sha256-6QMMP6Uss9r6zNd/S6w7yo19IBOQyLmFvcn2o0MkOq4=";

  enableParallelBuilding = true;

  nativeBuildInputs = [
    installShellFiles
    nasm
  ];

  postBuild = ''
    cargo run --example gen_completions
  '';

  postInstall = ''
    installShellCompletion ig.{bash,fish}
    installShellCompletion --zsh _ig
  '';

  meta = {
    description = "Accessible image processing and conversion from the terminal";
    homepage = "https://github.com/foresterre/sic";
    changelog = "https://github.com/foresterre/sic/blob/v${version}/CHANGELOG.md";
    license = with lib.licenses; [
      asl20 # or
      mit
    ];
    maintainers = [ ];
    mainProgram = "ig";
  };
}
