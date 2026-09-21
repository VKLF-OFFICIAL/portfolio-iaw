const KIND_LABELS = { code: "Código", image: "Imágenes", video: "Vídeo", pdf: "PDF", doc: "Documentos", archive: "Comprimidos", other: "Otros" };
const LANGS = { sh: "bash", bash: "bash", ps1: "powershell", bat: "dos", cmd: "dos", py: "python", php: "php", js: "javascript", ts: "typescript", sql: "sql", yml: "yaml", yaml: "yaml", json: "json", html: "xml", htm: "xml", xml: "xml", css: "css", md: "markdown", ini: "ini", cfg: "ini", toml: "ini", conf: "apache", vhost: "apache", htaccess: "apache", java: "java", c: "c", cpp: "cpp", cs: "csharp", go: "go", rb: "ruby", dockerfile: "dockerfile" };
const MAX_PREVIEW = 60 * 1024;

const $ = (id) => document.getElementById(id);
const state = { units: [], unit: "all", kind: "all", q: "", sort: "desc" };

const fmtDate = (iso) => new Date(iso + "T00:00:00").toLocaleDateString("es-ES", { day: "numeric", month: "short", year: "numeric" });
const fmtSize = (b) => (b < 1024 ? `${b} B` : b < 1048576 ? `${(b / 1024).toFixed(0)} KB` : `${(b / 1048576).toFixed(1)} MB`);
const md = (text) => DOMPurify.sanitize(marked.parse(text));

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k === "class") node.className = v;
    else if (k === "html") node.innerHTML = v;
    else node.setAttribute(k, v);
  }
  node.append(...children.filter((c) => c != null));
  return node;
}

async function init() {
  const [site, data] = await Promise.all([
    fetch("site.json").then((r) => r.json()).catch(() => ({})),
    fetch("data/tareas.json").then((r) => r.json()).catch(() => ({ units: [] })),
  ]);
  $("nombre").textContent = site.nombre || "Portfolio";
  $("modulo").textContent = site.modulo || "Portfolio";
  $("intro").textContent = site.intro || "";
  $("centro").textContent = site.centro || "";
  if (site.github) $("github").href = site.github; else $("github").hidden = true;
  $("foot").textContent = `${site.nombre || ""} — ${site.modulo || ""}`.replace(/^ — /, "");
  document.title = `${site.nombre ? site.nombre + " · " : ""}${site.modulo || "Portfolio"}`;

  state.units = data.units;
  renderUnits();
  renderKinds();
  $("q").addEventListener("input", (e) => { state.q = e.target.value.trim().toLowerCase(); renderList(); });
  $("sort").addEventListener("change", (e) => { state.sort = e.target.value; renderList(); });
  renderList();
  openFromHash();
}

const allTasks = () => state.units.flatMap((u) => u.tasks.map((t) => ({ ...t, unit: u })));

function renderUnits() {
  const ul = $("units");
  ul.replaceChildren();
  const items = [{ id: "all", title: "todas", count: allTasks().length }, ...state.units.map((u) => ({ id: u.id, title: (u.tag ? u.tag + " " : "") + u.title, count: u.tasks.length }))];
  for (const it of items) {
    const b = el("button", { type: "button", "aria-pressed": String(state.unit === it.id) }, el("span", {}, it.title), el("span", { class: "n" }, String(it.count)));
    b.addEventListener("click", () => { state.unit = it.id; renderUnits(); renderList(); });
    ul.append(el("li", {}, b));
  }
}

function renderKinds() {
  const present = new Set(allTasks().flatMap((t) => t.files.map((f) => f.kind)));
  const box = $("kinds");
  box.replaceChildren();
  const kinds = ["all", ...Object.keys(KIND_LABELS).filter((k) => present.has(k))];
  if (kinds.length < 3) return;
  for (const k of kinds) {
    const b = el("button", { type: "button", "aria-pressed": String(state.kind === k) }, k === "all" ? "Todos" : KIND_LABELS[k]);
    b.addEventListener("click", () => { state.kind = k; renderKinds(); renderList(); });
    box.append(b);
  }
}

function matches(t) {
  if (state.unit !== "all" && t.unit.id !== state.unit) return false;
  if (state.kind !== "all" && !t.files.some((f) => f.kind === state.kind)) return false;
  if (!state.q) return true;
  return [t.title, t.summary, t.readme, ...t.files.map((f) => f.name)].join(" ").toLowerCase().includes(state.q);
}

function renderList() {
  const list = $("list");
  const dir = state.sort === "asc" ? 1 : -1;
  const tasks = allTasks().filter(matches).sort((a, b) => dir * a.date.localeCompare(b.date) || a.title.localeCompare(b.title, "es"));
  list.replaceChildren();
  $("count").textContent = tasks.length ? `${tasks.length} ${tasks.length === 1 ? "tarea" : "tareas"}` : "";

  if (!tasks.length) {
    const none = allTasks().length === 0;
    list.append(el("div", { class: "empty" },
      el("strong", {}, none ? "Todavía no hay tareas publicadas" : "Ninguna tarea coincide"),
      none ? "Vuelve pronto: las tareas aparecen aquí según se entregan." : "Prueba con otra palabra o quita los filtros."));
    return;
  }

  for (const t of tasks) list.append(taskRow(t));
}

function rowCells(t) {
  const kinds = [...new Set(t.files.map((f) => f.kind))];
  return [
    el("span", { class: "t-date" }, fmtDate(t.date), el("span", { class: "t-unit", title: t.unit.title }, t.unit.tag || t.unit.title)),
    el("span", { class: "t-title" }, t.title, t.summary ? el("span", { class: "t-sum" }, t.summary) : null),
    el("span", { class: "t-kinds" }, ...kinds.map((k) => el("span", { class: k === "pdf" ? "chip chip-pdf" : "chip" }, KIND_LABELS[k]))),
  ];
}

// Una tarea con PDF: el clic en la fila abre el PDF; el botón despliega el resto.
function taskRow(t) {
  const pdf = t.files.find((f) => f.kind === "pdf");
  return pdf ? pdfRow(t, pdf) : detailsRow(t);
}

function detailsRow(t) {
  const d = el("details", { class: "task", id: t.id }, el("summary", {}, ...rowCells(t)));
  d.addEventListener("toggle", () => {
    if (!d.open || d.querySelector(".task-body")) return;
    d.append(taskBody(t));
    history.replaceState(null, "", "#" + t.id);
  });
  return d;
}

function pdfRow(t, pdf) {
  const rest = t.files.filter((f) => f !== pdf);
  const row = el("div", { class: "task task-pdf", id: t.id },
    el("div", { class: "t-bar" },
      el("a", { class: "t-row", href: pdf.url, target: "_blank", rel: "noopener", title: "Abrir el PDF en una pestaña nueva" }, ...rowCells(t))));
  if (!rest.length && !t.readme) return row;

  const btn = el("button", { type: "button", class: "t-toggle", "aria-expanded": "false" }, "Detalles");
  btn.addEventListener("click", () => {
    const open = btn.getAttribute("aria-expanded") === "true";
    btn.setAttribute("aria-expanded", String(!open));
    btn.textContent = open ? "Detalles" : "Ocultar";
    let body = row.querySelector(".task-body");
    if (!body) row.append((body = taskBody(t, rest)));
    body.hidden = open;
  });
  row.firstChild.append(btn);
  return row;
}

function taskBody(t, files = t.files) {
  const body = el("div", { class: "task-body" });
  if (t.readme) body.append(el("div", { class: "readme", html: md(t.readme) }));
  for (const f of files) body.append(fileBlock(f));
  return body;
}

function fileBlock(f) {
  const head = el("div", { class: "file-head" },
    el("span", { class: "file-name" }, f.name, el("span", {}, fmtSize(f.size))),
    el("span", { class: "file-actions" },
      el("a", { href: f.url, target: "_blank", rel: "noopener" }, "Abrir"),
      el("a", { href: f.url, download: f.name }, "Descargar")));
  const block = el("div", { class: "file" }, head);

  if (f.kind === "image") block.append(el("img", { src: f.url, alt: f.name, loading: "lazy" }));
  else if (f.kind === "video") block.append(el("video", { src: f.url, controls: "", preload: "metadata" }));
  else if (f.kind === "pdf") block.append(el("iframe", { src: f.url, title: f.name, loading: "lazy" }));
  else if (f.kind === "code") {
    if (f.size > MAX_PREVIEW) block.append(el("p", { class: "note" }, "Archivo grande: ábrelo o descárgalo para verlo completo."));
    else fetch(f.url).then((r) => r.text()).then((text) => {
      const code = el("code");
      code.textContent = text;
      const lang = LANGS[f.ext] || LANGS[f.name.toLowerCase()];
      if (lang && hljs.getLanguage(lang)) code.className = "language-" + lang;
      hljs.highlightElement(code);
      block.append(el("pre", {}, code));
    }).catch(() => block.append(el("p", { class: "note" }, "No se pudo cargar la vista previa. Usa Abrir o Descargar.")));
  } else block.append(el("p", { class: "note" }, "Sin vista previa para este tipo de archivo. Descárgalo para verlo."));
  return block;
}

function openFromHash() {
  const id = decodeURIComponent(location.hash.slice(1));
  const node = id && document.getElementById(id);
  if (!node) return;
  if (node.tagName === "DETAILS") node.open = true;
  else node.querySelector(".t-toggle")?.click();
  node.scrollIntoView({ block: "start" });
}

function initTheme() {
  const btn = $("theme");
  const apply = (dark) => {
    document.documentElement.dataset.theme = dark ? "dark" : "light";
    btn.textContent = dark ? "Modo claro" : "Modo oscuro";
  };
  apply(document.documentElement.dataset.theme === "dark");
  btn.addEventListener("click", () => {
    const dark = document.documentElement.dataset.theme !== "dark";
    apply(dark);
    try { localStorage.setItem("theme", dark ? "dark" : "light"); } catch {}
  });
}

initTheme();

init();
