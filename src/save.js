export function loadSave() {
  try {
    const raw = localStorage.getItem('fallout-rockies.save.v1');
    if (!raw) return null;
    const data = JSON.parse(raw);
    if (!data || data.version !== 1) return null;
    return data;
  } catch {
    return null;
  }
}

export function writeSave(data) {
  try {
    const existing = loadSave() || {};
    const out = { version: 1, ...existing, ...data, savedAt: new Date().toISOString() };
    localStorage.setItem('fallout-rockies.save.v1', JSON.stringify(out));
    return out;
  } catch {
    return null;
  }
}

export function clearSave() {
  try { localStorage.removeItem('fallout-rockies.save.v1'); } catch {}
}
