#!/usr/bin/env python3
"""Recorre tareas/ y genera data/tareas.json para la web.

Estructura esperada:
    tareas/<unidad>/<tarea>/archivos...      (una tarea = una carpeta)
    tareas/<unidad>/archivo.ext              (un archivo suelto = una tarea)

Opcional dentro de cada carpeta de tarea:
    info.json   {"titulo": "...", "fecha": "2026-09-21", "descripcion": "..."}
    README.md   texto que se muestra al abrir la tarea
"""
import json
import re
import subprocess
from datetime import datetime
from pathlib import Path
from urllib.parse import quote

ROOT = Path(__file__).resolve().parent
TAREAS = ROOT / "tareas"
OUT = ROOT / "data" / "tareas.json"

HIDDEN = {"info.json", "unidad.json", "readme.md", ".gitkeep", ".ds_store", "thumbs.db"}

KINDS = {
    "image": {"png", "jpg", "jpeg", "gif", "webp", "svg", "bmp"},
    "video": {"mp4", "webm", "ogv", "mov"},
    "pdf": {"pdf"},
    "doc": {"doc", "docx", "odt", "xls", "xlsx", "ods", "ppt", "pptx", "odp"},
    "archive": {"zip", "rar", "7z", "tar", "gz", "tgz"},
    "code": {
        "sh", "bash", "ps1", "bat", "cmd", "py", "php", "js", "ts", "sql", "conf",
        "cfg", "ini", "yml", "yaml", "json", "html", "htm", "css", "xml", "txt",
        "log", "md", "env", "htaccess", "toml", "java", "c", "cpp", "cs", "go",
        "rb", "vhost", "pkt", "dockerfile",
    },
}


def kind_of(path: Path) -> str:
    ext = path.suffix.lower().lstrip(".") or path.name.lower()
    for kind, exts in KINDS.items():
        if ext in exts:
            return kind
    return "other"


def pretty(name: str) -> str:
    return re.sub(r"[-_]+", " ", name).strip()


def split_prefix(name: str, pattern: str):
    m = re.match(pattern, name)
    return (m.group(1), m.group(2)) if m else (None, name)


def git_date(path: Path):
    try:
        out = subprocess.run(
            ["git", "log", "--diff-filter=A", "--format=%aI", "--", str(path)],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout.split()
        return out[-1][:10] if out else None
    except (OSError, subprocess.CalledProcessError):
        return None


def date_of(path: Path, prefix, info):
    if info.get("fecha"):
        return str(info["fecha"])
    if prefix:
        return prefix
    return git_date(path) or datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d")


def file_entry(f: Path) -> dict:
    rel = f.relative_to(ROOT).as_posix()
    return {
        "name": f.name,
        "url": quote(rel),
        "size": f.stat().st_size,
        "kind": kind_of(f),
        "ext": f.suffix.lower().lstrip("."),
    }


def read_json(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def read_readme(folder: Path) -> str:
    for name in ("README.md", "readme.md"):
        p = folder / name
        if p.exists():
            return p.read_text(encoding="utf-8")
    return ""


def split_summary(readme: str):
    """Devuelve (resumen, readme sin ese primer párrafo) para no repetirlo."""
    blocks = re.split(r"\n\s*\n", readme)
    for i, block in enumerate(blocks):
        block = block.strip()
        if block and not block.startswith("#"):
            rest = "\n\n".join(blocks[:i] + blocks[i + 1:]).strip()
            return re.sub(r"[*_`]", "", block)[:200], rest
    return "", readme


def build_task(unit_id: str, path: Path) -> dict:
    if path.is_dir():
        prefix, rest = split_prefix(path.name, r"^(\d{4}-\d{2}-\d{2})[-_ ]+(.*)$")
        info = read_json(path / "info.json")
        readme = read_readme(path)
        files = sorted(
            (f for f in path.rglob("*") if f.is_file() and f.name.lower() not in HIDDEN),
            key=lambda f: f.as_posix().lower(),
        )
    else:
        prefix, rest = split_prefix(path.stem, r"^(\d{4}-\d{2}-\d{2})[-_ ]+(.*)$")
        info, readme, files = {}, "", [path]
    summary = info.get("descripcion", "")
    if not summary:
        summary, readme = split_summary(readme)
    return {
        "id": f"{unit_id}--{re.sub(r'[^a-z0-9]+', '-', path.stem.lower()).strip('-')}",
        "title": info.get("titulo") or pretty(rest),
        "date": date_of(path, prefix, info),
        "summary": summary,
        "readme": readme,
        "files": [file_entry(f) for f in files],
    }


def build_unit(folder: Path) -> dict:
    tag, rest = split_prefix(folder.name, r"^(UT\d+|\d+)[-_ ]+(.*)$")
    info = read_json(folder / "unidad.json")
    unit_id = re.sub(r"[^a-z0-9]+", "-", folder.name.lower()).strip("-")
    tasks = [
        build_task(unit_id, p)
        for p in folder.iterdir()
        if p.name.lower() not in HIDDEN and not p.name.startswith(".")
    ]
    tasks.sort(key=lambda t: t["date"], reverse=True)
    return {
        "id": unit_id,
        "tag": info.get("etiqueta") or tag or "",
        "title": info.get("titulo") or pretty(rest),
        "tasks": tasks,
    }


def main():
    TAREAS.mkdir(exist_ok=True)
    units = [
        build_unit(d)
        for d in sorted(TAREAS.iterdir(), key=lambda p: p.name.lower())
        if d.is_dir() and not d.name.startswith(".")
    ]
    OUT.parent.mkdir(exist_ok=True)
    OUT.write_text(json.dumps({"units": units}, ensure_ascii=False, indent=1), encoding="utf-8")
    total = sum(len(u["tasks"]) for u in units)
    print(f"{total} tareas en {len(units)} unidades -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
