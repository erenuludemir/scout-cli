from __future__ import annotations

import importlib.util
import os
import sys
from types import ModuleType

ROOT = os.path.dirname(__file__)
PACKAGE_APP = os.path.join(ROOT, "app", "__init__.py")


def _load_package_app() -> ModuleType:
    if ROOT not in sys.path:
        sys.path.insert(0, ROOT)
    spec = importlib.util.spec_from_file_location("_qai_app_package", PACKAGE_APP)
    if spec is None or spec.loader is None:
        raise ImportError(f"Unable to load package app from {PACKAGE_APP}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_app_module = _load_package_app()
create_app = _app_module.create_app
app = create_app()
application = app


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("HOST_PORT", 5002)))
