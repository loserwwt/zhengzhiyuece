(function () {
  const rawFiles = window.DOWNLOAD_FILES;
  const files = Array.isArray(rawFiles) ? rawFiles : rawFiles ? [rawFiles] : [];
  const meta = window.DOWNLOAD_META || {};

  const countEl = document.querySelector("#file-count");
  const totalSizeEl = document.querySelector("#total-size");
  const updatedAtEl = document.querySelector("#updated-at");
  const listEl = document.querySelector("#file-list");
  const emptyEl = document.querySelector("#empty-state");
  const searchInput = document.querySelector("#search-input");
  const sortSelect = document.querySelector("#sort-select");

  const formatBytes = (bytes) => {
    const value = Number(bytes) || 0;
    if (value === 0) return "0 B";
    const units = ["B", "KB", "MB", "GB", "TB"];
    const index = Math.min(Math.floor(Math.log(value) / Math.log(1024)), units.length - 1);
    const size = value / 1024 ** index;
    return `${size >= 10 || index === 0 ? size.toFixed(0) : size.toFixed(1)} ${units[index]}`;
  };

  const iconFor = (extension) => {
    const ext = String(extension || "").toLowerCase();
    if (["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt"].includes(ext)) return "DOC";
    if (["zip", "rar", "7z", "tar", "gz"].includes(ext)) return "ZIP";
    if (["jpg", "jpeg", "png", "gif", "webp", "mp4", "mov"].includes(ext)) return "IMG";
    if (["js", "py", "java", "cpp", "html", "css", "json"].includes(ext)) return "DEV";
    return ext ? ext.slice(0, 3).toUpperCase() : "FILE";
  };

  const compareByName = (a, b) => a.name.localeCompare(b.name, "zh-CN", { numeric: true });

  const triggerNativeDownload = (file) => {
    const fallback = document.createElement("a");
    fallback.href = file.path;
    fallback.download = file.name || "download";
    fallback.rel = "noopener";
    document.body.append(fallback);
    fallback.click();
    fallback.remove();
  };

  const forceDownload = async (event, file) => {
    event.preventDefault();

    const button = event.currentTarget;
    const originalText = button.textContent;
    button.textContent = "准备中";
    button.setAttribute("aria-busy", "true");

    try {
      const response = await fetch(file.path, { cache: "no-store" });
      if (!response.ok) {
        throw new Error(`Download request failed: ${response.status}`);
      }

      const sourceBlob = await response.blob();
      const downloadBlob = new Blob([sourceBlob], { type: "application/octet-stream" });
      const objectUrl = URL.createObjectURL(downloadBlob);
      const downloadLink = document.createElement("a");
      downloadLink.href = objectUrl;
      downloadLink.download = file.name || "download";
      document.body.append(downloadLink);
      downloadLink.click();
      downloadLink.remove();
      window.setTimeout(() => URL.revokeObjectURL(objectUrl), 30000);
    } catch (error) {
      triggerNativeDownload(file);
    } finally {
      window.setTimeout(() => {
        button.textContent = originalText;
        button.removeAttribute("aria-busy");
      }, 500);
    }
  };

  const getVisibleFiles = () => {
    const query = searchInput.value.trim().toLowerCase();
    const visible = files.filter((file) => {
      const text = `${file.name} ${file.description || ""}`.toLowerCase();
      return !query || text.includes(query);
    });

    if (sortSelect.value === "name") {
      visible.sort(compareByName);
    } else if (sortSelect.value === "size") {
      visible.sort((a, b) => Number(b.bytes || 0) - Number(a.bytes || 0) || compareByName(a, b));
    } else {
      visible.sort((a, b) => String(b.modifiedIso || "").localeCompare(String(a.modifiedIso || "")) || compareByName(a, b));
    }

    return visible;
  };

  const createFileCard = (file) => {
    const card = document.createElement("article");
    card.className = "file-card";

    const icon = document.createElement("div");
    icon.className = "file-icon";
    icon.textContent = iconFor(file.extension);

    const main = document.createElement("div");
    main.className = "file-main";

    const title = document.createElement("h3");
    title.className = "file-title";
    title.textContent = file.name || "未命名文件";

    const description = document.createElement("p");
    description.className = "file-description";
    description.textContent = file.description || "暂无说明";

    const metaLine = document.createElement("div");
    metaLine.className = "file-meta";

    const size = document.createElement("span");
    size.textContent = file.size || formatBytes(file.bytes);

    const modified = document.createElement("span");
    modified.textContent = file.modified ? `更新：${file.modified}` : "更新日期未知";

    metaLine.append(size, modified);
    main.append(title, description, metaLine);

    const action = document.createElement("a");
    action.className = "download-button";
    action.href = file.path;
    action.download = file.name || "";
    action.textContent = "下载";
    action.addEventListener("click", (event) => forceDownload(event, file));

    card.append(icon, main, action);
    return card;
  };

  const render = () => {
    const visible = getVisibleFiles();
    listEl.replaceChildren(...visible.map(createFileCard));
    listEl.hidden = visible.length === 0;
    emptyEl.hidden = visible.length !== 0;

    const totalBytes = files.reduce((sum, file) => sum + Number(file.bytes || 0), 0);
    countEl.textContent = `${files.length} 个文件`;
    totalSizeEl.textContent = formatBytes(totalBytes);

    if (files.length === 0) {
      updatedAtEl.textContent = "文件列表为空";
    } else if (meta.generatedAt) {
      updatedAtEl.textContent = `列表更新：${meta.generatedAt}`;
    } else {
      updatedAtEl.textContent = "文件列表已载入";
    }
  };

  searchInput.addEventListener("input", render);
  sortSelect.addEventListener("change", render);
  render();
})();
