{
  lib,
  stdenv,
  runtimeShell,
  python3,
  fetchFromGitHub,
  nixosTests,
}:
let
  python = python3.withPackages (
    ps:
    with ps;
    [
      # https://github.com/FuzzyGrim/Yamtrack/blob/v0.25.0/requirements.txt
      aiohttp
      apprise
      beautifulsoup4
      celery
      croniter
      defusedxml
      django
      django-allauth
      django-celery-beat
      django-celery-results
      django-debug-toolbar
      django-decorator-include
      django-health-check
      django-model-utils
      django-redis
      django-select2
      django-simple-history
      django-widget-tweaks
      gunicorn
      icalendar
      pillow
      psycopg
      python-decouple
      redis
      requests
      requests-ratelimiter_0_8
      unidecode
    ]
    ++ lib.flatten [
      django-allauth.optional-dependencies.socialaccount
      psycopg.optional-dependencies.c
      psycopg.optional-dependencies.pool
      redis.optional-dependencies.hiredis
    ]
  );

  pname = "yamtrack";
  version = "0.25.0";
  src = fetchFromGitHub {
    owner = "FuzzyGrim";
    repo = "Yamtrack";
    rev = "v${version}";
    hash = "sha256-dUf8ZVS1lWmP96G2KoPmqsRVypiCCvwtyOMhjEFPm1g=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname version src;

  buildInputs = [ python ];

  buildPhase = ''
    runHook preBuild

    cd src
    python manage.py collectstatic --noinput

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Yamtrack assumes the database file location (if sqlite is used) is relative to the application.
    # Since this is located in the read-only nix store, allow setting it via an environment variable.
    substituteInPlace config/settings.py \
     --replace-fail 'BASE_DIR / "db" / "db.sqlite3"' 'config("DB_FILE")'
    # Yamtrack doesn't allow configuring the port, which is fine in a docker container but problematic outside.
    substituteInPlace config/gunicorn.py \
      --replace-fail 'bind = "localhost:8001"' $'import decouple\nbind = "localhost:" + decouple.config("PORT", default="8001")'

    mkdir -p $out/lib
    cp -r . $out/lib/yamtrack

    mkdir -p $out/bin
    ln -s $out/lib/yamtrack/manage.py $out/bin/yamtrack-manage

    cat > $out/bin/yamtrack <<EOF
    #!${runtimeShell}
    cd $out/lib/yamtrack
    export VERSION=\''${VERSION:-v${finalAttrs.version} (nixpkgs)}
    ${python.interpreter} manage.py migrate --noinput
    ${python}/bin/celery --app config worker --without-mingle --without-gossip &
    ${python}/bin/celery --app config beat &
    exec ${python}/bin/gunicorn --config python:config.gunicorn config.wsgi:application
    EOF

    chmod +x $out/bin/yamtrack

    runHook postInstall
  '';

  passthru = {
    tests = {
      inherit (nixosTests) yamtrack;
    };
    inherit python;
    staticFiles = "${finalAttrs.finalPackage}/lib/yamtrack/staticfiles";
  };

  meta = {
    description = "Self hosted media tracker";
    mainProgram = "yamtrack";
    homepage = "https://github.com/FuzzyGrim/Yamtrack";
    changelog = "https://github.com/FuzzyGrim/Yamtrack/releases/tag/v${version}";
    license = with lib.licenses; [ agpl3Only ];
    maintainers = with lib.maintainers; [ dav-wolff ];
  };
})
