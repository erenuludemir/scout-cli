import os,sys,importlib,importlib.util,glob
def _load_from_module(modname):
    try:
        m=importlib.import_module(modname)
    except Exception:
        return None
    for cand in ("app","application","api"):
        if hasattr(m,cand): return getattr(m,cand)
    if hasattr(m,"create_app") and callable(getattr(m,"create_app")): return m.create_app()
    return None
def _load_from_path(path):
    if not os.path.isfile(path): return None
    spec=importlib.util.spec_from_file_location("dynapp",path)
    if not spec or not spec.loader: return None
    m=importlib.util.module_from_spec(spec)
    try:
        spec.loader.exec_module(m)
    except Exception:
        return None
    for cand in ("app","application","api"):
        if hasattr(m,cand): return getattr(m,cand)
    if hasattr(m,"create_app") and callable(getattr(m,"create_app")): return m.create_app()
    return None
def resolve_app():
    entry=os.getenv("APP_ENTRY","").strip()
    if entry:
        if ":" in entry:
            mod,attr=entry.split(":",1)
            try:
                return getattr(importlib.import_module(mod),attr)
            except Exception:
                p=mod if mod.endswith(".py") else mod+".py"
                cand=_load_from_path(p)
                if cand is not None: return cand
        else:
            cand=_load_from_module(entry)
            if cand is not None: return cand
    for mod in ("app","main","api","server","quantumai_usdt.app","quantumai_usdt.main"):
        cand=_load_from_module(mod)
        if cand is not None: return cand
    roots=["/app","/app/quantumai-usdt","/app/quantumai_usdt"]
    names=("wsgi.py","app.py","main.py","api.py","server.py")
    for r in roots:
        for n in names:
            cand=_load_from_path(os.path.join(r,n))
            if cand is not None: return cand
    for r in roots:
        for path in glob.glob(os.path.join(r,"**","*.py"),recursive=True):
            cand=_load_from_path(path)
            if cand is not None: return cand
    raise ImportError("app not found; set APP_ENTRY or expose app|application|api or create_app()")
app=resolve_app()
