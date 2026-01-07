{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  flit-scm,
  django,
  django-appconf,
}:
let
  pname = "django-decorator-include";
  version = "3.3";
  src = fetchFromGitHub {
    owner = "twidi";
    repo = "django-decorator-include";
    rev = "${version}";
    hash = "sha256-lW/QdM9IPOrCLPPXrx4waBUaYi1OkM5Vd2uH8PZdWbs=";
  };
in
buildPythonPackage {
  inherit pname version src;
  pyproject = true;
  build-system = [ flit-scm ];

  dependencies = [
    django
    django-appconf
  ];

  checkPhase = ''
    runHook preCheck
    ./runtests.sh
    runHook postCheck
  '';

  meta = {
    description = "Include Django URL patterns with decorators";
    homepage = "https://github.com/twidi/django-decorator-include";
    changelog = "https://github.com/twidi/django-decorator-include/blob/${version}/CHANGELOG.rst";
    license = lib.licenses.bsd2;
    maintainers = with lib.maintainers; [ dav-wolff ];
  };
}
