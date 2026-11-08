// Monta barra de estados/tema e a moldura do iPhone. Cada tela só declara seus estados.
function proto({ title, tab, titulo, estados, inicial, acao, back }) {
  const temas = { auto: "Sistema", light: "Claro", dark: "Escuro" };
  let est = inicial, tema = "dark";
  const $ = (id) => document.getElementById(id);
  document.body.innerHTML = `<div class="proto-bar" role="toolbar" aria-label="Controles do protótipo"><h1>${title}</h1><div class="grp" id="estado"><span class="lbl">Estado</span></div><div class="grp" id="tema"><span class="lbl">Tema</span></div></div><main><div><div class="phone" id="phone"></div><p class="meta" id="meta"></p></div></main>`;
  const mk = (box, obj, set) => Object.entries(obj).forEach(([k, v]) => { const b = document.createElement("button"); b.textContent = Array.isArray(v) ? v[0] : v; b.dataset.k = k; b.onclick = () => { set(k); render(); }; $(box).appendChild(b); });
  function render() {
    document.documentElement.dataset.theme = tema === "auto" ? "" : tema;
    document.querySelectorAll("#estado button").forEach((b) => b.setAttribute("aria-pressed", b.dataset.k === est));
    document.querySelectorAll("#tema button").forEach((b) => b.setAttribute("aria-pressed", b.dataset.k === tema));
    const tabs = ["Chat", "Material", "Ensaio", "Ajustes"].map((t) => `<div ${t === tab ? 'aria-current="page"' : ""}>${t}</div>`).join("");
    $("phone").innerHTML = `<div class="top"><h2>${titulo}</h2>${back ? `<div class="ghost">${back}</div>` : ""}</div><div class="body">${estados[est][1]}</div>${acao && acao[est] ? `<div class="act">${acao[est]}</div>` : ""}<nav class="tabs" aria-label="Abas">${tabs}</nav>`;
    $("meta").textContent = `estado: ${est} · tema: ${tema} · iPhone retrato`;
  }
  mk("estado", estados, (k) => (est = k)); mk("tema", temas, (k) => (tema = k)); render();
}
