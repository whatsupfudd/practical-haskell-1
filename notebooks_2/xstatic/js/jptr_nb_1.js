
document.addEventListener("DOMContentLoaded", async () => {
  const diagrams = document.querySelectorAll(".jp-Mermaid > pre.mermaid");
  // do not load mermaidjs if not needed
  if (!diagrams.length) {
    return;
  }
  const mermaid = (await import("https://cdnjs.cloudflare.com/ajax/libs/mermaid/10.5.0/mermaid.esm.min.mjs")).default;
  const parser = new DOMParser();

  mermaid.initialize({
    maxTextSize: 100000,
    startOnLoad: false,
    fontFamily: window
      .getComputedStyle(document.body)
      .getPropertyValue("--jp-ui-font-family"),
    theme: document.querySelector("body[data-jp-theme-light='true']")
      ? "default"
      : "dark",
  });

  let _nextMermaidId = 0;

  function makeMermaidImage(svg) {
    const img = document.createElement("img");
    const doc = parser.parseFromString(svg, "image/svg+xml");
    const svgEl = doc.querySelector("svg");
    const { maxWidth } = svgEl?.style || {};
    const firstTitle = doc.querySelector("title");
    const firstDesc = doc.querySelector("desc");

    img.setAttribute("src", `data:image/svg+xml,${encodeURIComponent(svg)}`);
    if (maxWidth) {
      img.width = parseInt(maxWidth);
    }
    if (firstTitle) {
      img.setAttribute("alt", firstTitle.textContent);
    }
    if (firstDesc) {
      const caption = document.createElement("figcaption");
      caption.className = "sr-only";
      caption.textContent = firstDesc.textContent;
      return [img, caption];
    }
    return [img];
  }

  async function makeMermaidError(text) {
    let errorMessage = "";
    try {
      await mermaid.parse(text);
    } catch (err) {
      errorMessage = `${err}`;
    }

    const result = document.createElement("details");
    result.className = 'jp-RenderedMermaid-Details';
    const summary = document.createElement("summary");
    summary.className = 'jp-RenderedMermaid-Summary';
    const pre = document.createElement("pre");
    const code = document.createElement("code");
    code.innerText = text;
    pre.appendChild(code);
    summary.appendChild(pre);
    result.appendChild(summary);

    const warning = document.createElement("pre");
    warning.innerText = errorMessage;
    result.appendChild(warning);
    return [result];
  }

  async function renderOneMarmaid(src) {
    const id = `jp-mermaid-${_nextMermaidId++}`;
    const parent = src.parentNode;
    let raw = src.textContent.trim();
    const el = document.createElement("div");
    el.style.visibility = "hidden";
    document.body.appendChild(el);
    let results = null;
    let output = null;
    try {
      const { svg } = await mermaid.render(id, raw, el);
      results = makeMermaidImage(svg);
      output = document.createElement("figure");
      results.map(output.appendChild, output);
    } catch (err) {
      parent.classList.add("jp-mod-warning");
      results = await makeMermaidError(raw);
      output = results[0];
    } finally {
      el.remove();
    }
    parent.classList.add("jp-RenderedMermaid");
    parent.appendChild(output);
  }

  void Promise.all([...diagrams].map(renderOneMarmaid));
});
