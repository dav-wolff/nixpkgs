{
  lib,
  fetchFromGitea,
  rustPlatform,
  pkg-config,
  openssl,
  testers,
}:

let
  pname = "acmed";
  version = "0.25.0";
  src = fetchFromGitea {
    domain = "codeberg.org";
    owner = "rbd";
    repo = "acmed";
    rev = "v${version}";
    hash = "sha256-QEQUzV1S08x7EyM2REw1U3gNmcYCyFc095fVGwyruuo=";
  };
in
rustPlatform.buildRustPackage (finalAttrs: {
  inherit
    pname
    version
    src
    ;

  outputs = [
    "out"
    "man"
  ];

  cargoHash = "sha256-ck8nT8yFZlwopDZAGZEeMFb/aZM6MHLLNmPQraK94bg=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  postInstall = ''
    mkdir $out/etc
    cp -r acmed/config $out/etc/acmed

    mkdir -p $man/share/man/man5 $man/share/man/man8
    gzip <"man/en/acmed.8"      >"$man/share/man/man8/acmed.8.gz"
    gzip <"man/en/acmed.toml.5" >"$man/share/man/man5/acmed.toml.5.gz"
    gzip <"man/en/tacd.8"       >"$man/share/man/man8/tacd.8.gz"
  '';

  passthru.tests = {
    acmedVersion = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "acmed --version";
    };
    tacdVersion = testers.testVersion {
      package = finalAttrs.finalPackage;
      command = "tacd --version";
    };
  };

  meta = {
    description = "ACME (RFC 8555) client daemon";
    mainProgram = "acmed";
    homepage = "https://codeberg.org/rbd/acmed";
    changelog = "https://codeberg.org/rbd/acmed/src/tag/v${version}/CHANGELOG.md";
    license = with lib.licenses; [
      mit
      asl20
    ];
    maintainers = with lib.maintainers; [ dav-wolff ];
  };
})
