import importlib.util
import os
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT not in sys.path:
    sys.path.insert(0, ROOT)


def test_top_level_app_py_exposes_package_factory():
    path = os.path.join(ROOT, "app.py")
    spec = importlib.util.spec_from_file_location("legacy_app_entrypoint", path)
    assert spec is not None
    assert spec.loader is not None

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    assert hasattr(module, "create_app")
    assert hasattr(module, "app")
    assert hasattr(module, "application")

    client = module.create_app().test_client()
    response = client.get("/health")

    assert response.status_code == 200
    assert response.get_json()["ok"] is True


def test_wsgi_module_exposes_application_alias():
    path = os.path.join(ROOT, "wsgi.py")
    spec = importlib.util.spec_from_file_location("legacy_wsgi_entrypoint", path)
    assert spec is not None
    assert spec.loader is not None

    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)

    assert hasattr(module, "app")
    assert hasattr(module, "application")
