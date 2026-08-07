// Murmur — browser prototype.
// Capture in the browser -> transcribe on-device with Whisper (WASM) ->
// summarize / ask with the user's own Claude key. No backend, no analytics.

// ---------- Templates (mirrors the native app's built-ins) ----------
const TEMPLATES = [
  { name: 'Meeting Minutes', symbol: '🧑‍🤝‍🧑', instructions:
`You are a precise meeting scribe. Produce clean minutes in Markdown with these headings (omit any that are genuinely empty):
## Summary — 2–3 sentences.
## Decisions — bullet each concrete decision.
## Action Items — a checklist "- [ ] Task — Owner (due date)".
## Open Questions — anything left unresolved.
Be faithful to the transcript; never invent owners or dates.` },
  { name: 'Action Items', symbol: '☑️', instructions:
`Extract only the action items as a Markdown checklist "- [ ] Task — Owner (due date)". If nothing is actionable, say "No action items found." No commentary.` },
  { name: 'Quick Summary', symbol: '⚡️', instructions:
`Summarize this transcript in 4–6 tight bullet points capturing the key points and any outcome. Plain language, no preamble.` },
  { name: 'Interview Notes', symbol: '🎤', instructions:
`This is an interview. Produce:
## Themes — 3–6 themes, each a short heading with bullets.
## Notable Quotes — 2–4 verbatim quotes with speaker if identifiable.
## Follow-ups — questions worth asking next.` },
  { name: 'Clean Voice Note', symbol: '🌊', instructions:
`This is a spoken voice memo. Rewrite it into clear first-person prose that keeps every idea but removes filler, false starts, and repetition. Add paragraph breaks. This is a cleanup, not a summary.` },
  { name: 'Follow-up Email', symbol: '✉️', instructions:
`Draft a concise, professional follow-up email from this conversation: a subject line, a brief recap, agreed next steps as a short list, and a friendly close. Use "[Name]" placeholders where unknown. Under 200 words.` },
  { name: 'Speaker-labeled', symbol: '👥', instructions:
`Re-format this transcript by speaker. Detect speaker changes and label blocks "Speaker 1", "Speaker 2", etc. (or a name if unambiguous). Keep wording verbatim; only add labels and paragraph breaks. Best-effort — don't guess names that aren't clearly stated.` },
];

// ---------- Settings ----------
const settings = {
  claudeKey: localStorage.getItem('claudeKey') || '',
  claudeModel: localStorage.getItem('claudeModel') || 'claude-sonnet-5',
  whisperModel: localStorage.getItem('whisperModel') || 'Xenova/whisper-tiny.en',
};

// ---------- Tiny IndexedDB wrapper (recordings hold audio blobs) ----------
const DB = {
  db: null,
  open() {
    return new Promise((res, rej) => {
      const req = indexedDB.open('murmur', 1);
      req.onupgradeneeded = () => req.result.createObjectStore('recordings', { keyPath: 'id' });
      req.onsuccess = () => { this.db = req.result; res(); };
      req.onerror = () => rej(req.error);
    });
  },
  tx(mode) { return this.db.transaction('recordings', mode).objectStore('recordings'); },
  all() { return new Promise((res) => { const r = this.tx('readonly').getAll(); r.onsuccess = () => res(r.result || []); }); },
  get(id) { return new Promise((res) => { const r = this.tx('readonly').get(id); r.onsuccess = () => res(r.result); }); },
  put(rec) { return new Promise((res) => { const r = this.tx('readwrite').put(rec); r.onsuccess = () => res(); }); },
  del(id) { return new Promise((res) => { const r = this.tx('readwrite').delete(id); r.onsuccess = () => res(); }); },
};

// ---------- Helpers ----------
const $ = (id) => document.getElementById(id);
const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
function clock(sec) { const s = Math.floor(sec); const m = Math.floor(s / 60), r = s % 60; const h = Math.floor(m / 60);
  return h > 0 ? `${h}:${String(m % 60).padStart(2, '0')}:${String(r).padStart(2, '0')}` : `${m}:${String(r).padStart(2, '0')}`; }
function when(ts) { return new Date(ts).toLocaleString([], { weekday: 'short', month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' }); }
let toastTimer;
function toast(msg) { const t = $('toast'); t.textContent = msg; t.classList.add('show'); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('show'), 2400); }

// Minimal, safe Markdown -> HTML (headings, bold, bullets, checkboxes).
function md(text) {
  const lines = esc(text).split('\n');
  let html = '', inList = false;
  const closeList = () => { if (inList) { html += '</ul>'; inList = false; } };
  for (let raw of lines) {
    let line = raw.replace(/\*\*(.+?)\*\*/g, '<strong>$1</strong>');
    if (/^#{1,6}\s+/.test(line)) { closeList(); html += `<h3>${line.replace(/^#{1,6}\s+/, '')}</h3>`; }
    else if (/^\s*[-*]\s+\[[ xX]\]\s+/.test(line)) { if (!inList) { html += '<ul>'; inList = true; } const done = /\[[xX]\]/.test(line); html += `<li>${done ? '✅' : '⬜️'} ${line.replace(/^\s*[-*]\s+\[[ xX]\]\s+/, '')}</li>`; }
    else if (/^\s*[-*]\s+/.test(line)) { if (!inList) { html += '<ul>'; inList = true; } html += `<li>${line.replace(/^\s*[-*]\s+/, '')}</li>`; }
    else if (line.trim() === '') { closeList(); html += '<br>'; }
    else { closeList(); html += `<p>${line}</p>`; }
  }
  closeList();
  return html;
}

// ---------- Navigation ----------
const screens = ['library', 'record', 'detail', 'ask', 'settings'];
function show(name) {
  screens.forEach((s) => $('screen-' + s).classList.toggle('hidden', s !== name));
  $('fab-wrap').classList.toggle('hidden', name !== 'library');
}

// ---------- Claude ----------
async function claudeComplete(system, messages) {
  if (!settings.claudeKey) throw new Error('Add your Claude API key in Settings to summarize or chat.');
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': settings.claudeKey,
      'anthropic-version': '2023-06-01',
      'anthropic-dangerous-direct-browser-access': 'true',
    },
    body: JSON.stringify({ model: settings.claudeModel, max_tokens: 4096, system, messages }),
  });
  if (!res.ok) {
    let msg = await res.text();
    try { msg = JSON.parse(msg).error.message; } catch {}
    throw new Error(`Claude error (${res.status}): ${msg}`);
  }
  const data = await res.json();
  return (data.content || []).filter((b) => b.type === 'text').map((b) => b.text).join('');
}

// ---------- On-device transcription (Whisper via transformers.js) ----------
let asrPipeline = null;
let asrModelId = null;

function decodeAudio(ctx, arrayBuf) {
  return new Promise((res, rej) => {
    const p = ctx.decodeAudioData(arrayBuf, res, rej);
    if (p && p.then) p.then(res, rej);
  });
}
async function blobToMono16k(blob) {
  const buf = await blob.arrayBuffer();
  const AC = window.AudioContext || window.webkitAudioContext;
  const tmp = new AC();
  const decoded = await decodeAudio(tmp, buf);
  tmp.close && tmp.close();
  const rate = 16000;
  const frames = Math.ceil(decoded.duration * rate);
  const OAC = window.OfflineAudioContext || window.webkitOfflineAudioContext;
  const off = new OAC(1, frames, rate);
  const src = off.createBufferSource();
  src.buffer = decoded;
  src.connect(off.destination);
  src.start(0);
  const rendered = await off.startRendering();
  return rendered.getChannelData(0);
}
async function ensurePipeline(onProgress) {
  if (asrPipeline && asrModelId === settings.whisperModel) return asrPipeline;
  onProgress('Loading transcription engine…', 0);
  const { pipeline, env } = await import('https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.5.0');
  env.allowLocalModels = false;
  try { env.backends.onnx.wasm.numThreads = 1; } catch {}
  asrModelId = settings.whisperModel;
  asrPipeline = await pipeline('automatic-speech-recognition', asrModelId, {
    dtype: 'q8',
    progress_callback: (p) => {
      if (p.status === 'progress' && p.progress != null) {
        onProgress(`Downloading model… ${Math.round(p.progress)}%`, p.progress);
      } else if (p.status === 'ready') {
        onProgress('Model ready', 100);
      }
    },
  });
  return asrPipeline;
}
async function transcribe(blob, onProgress) {
  const asr = await ensurePipeline(onProgress);
  onProgress('Preparing audio…', 100);
  const audio = await blobToMono16k(blob);
  onProgress('Transcribing on your device…', 100);
  const out = await asr(audio, { chunk_length_s: 30, stride_length_s: 5 });
  return (out.text || '').trim();
}

// ---------- Recording ----------
const R = { rec: null, chunks: [], stream: null, startAt: 0, timer: null, blob: null, active: false };
function pickMime() {
  const types = ['audio/mp4', 'audio/webm;codecs=opus', 'audio/webm', 'audio/aac', ''];
  for (const t of types) { if (t === '') return ''; try { if (MediaRecorder.isTypeSupported(t)) return t; } catch {} }
  return '';
}
async function startRecording() {
  try {
    R.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
  } catch (e) {
    $('rec-status').innerHTML = '<span class="err">Microphone access denied. Enable it in Safari settings.</span>';
    return;
  }
  const mime = pickMime();
  R.chunks = [];
  R.rec = new MediaRecorder(R.stream, mime ? { mimeType: mime } : undefined);
  R.rec.ondataavailable = (e) => { if (e.data.size) R.chunks.push(e.data); };
  R.rec.onstop = onRecStopped;
  R.rec.start();
  R.active = true;
  R.startAt = Date.now();
  $('rec-toggle').textContent = 'Stop & transcribe';
  $('rec-status').textContent = 'Recording — speak now';
  $('rec-pulse').style.visibility = 'visible';
  R.timer = setInterval(() => { $('rec-timer').textContent = clock((Date.now() - R.startAt) / 1000); }, 250);
}
function stopRecording() {
  if (!R.rec || R.rec.state === 'inactive') return;
  clearInterval(R.timer);
  R.active = false;
  R.rec.stop();
  R.stream.getTracks().forEach((t) => t.stop());
  $('rec-pulse').style.visibility = 'hidden';
}
async function onRecStopped() {
  const type = R.rec.mimeType || 'audio/mp4';
  R.blob = new Blob(R.chunks, { type });
  const duration = (Date.now() - R.startAt) / 1000;
  const setProg = (msg, pct) => { $('rec-status').textContent = msg; $('rec-progress').style.width = (pct || 0) + '%'; };
  let transcript = '';
  try {
    transcript = await transcribe(R.blob, setProg);
  } catch (e) {
    setProg('', 0);
    $('rec-live').innerHTML = `<span class="err">${esc(e.message || 'Transcription failed')}</span>`;
    return;
  }
  const rec = {
    id: String(Date.now()),
    title: when(Date.now()),
    createdAt: Date.now(),
    duration,
    transcript,
    audioBlob: R.blob,
    summaries: [],
  };
  await DB.put(rec);
  setProg('Done', 100);
  openDetail(rec.id);
  renderLibrary();
}

// ---------- Library ----------
async function renderLibrary() {
  const recs = (await DB.all()).sort((a, b) => b.createdAt - a.createdAt);
  const list = $('library-list');
  $('library-empty').classList.toggle('hidden', recs.length > 0);
  list.innerHTML = recs.map((r) => `
    <div class="rec-card" data-id="${r.id}">
      <h3>${esc(r.title)}</h3>
      <div class="rec-meta"><span>◷ ${clock(r.duration)}</span>${r.summaries.length ? `<span style="color:var(--coral)">✦ ${r.summaries.length}</span>` : ''}</div>
      <p class="rec-snippet">${esc(r.transcript || 'No transcript').slice(0, 160)}</p>
    </div>`).join('');
  list.querySelectorAll('.rec-card').forEach((el) => el.onclick = () => openDetail(el.dataset.id));
}

// ---------- Detail ----------
let current = null;
async function openDetail(id) {
  current = await DB.get(id);
  if (!current) return;
  renderDetail();
  show('detail');
}
function renderDetail() {
  const r = current;
  const audioURL = r.audioBlob ? URL.createObjectURL(r.audioBlob) : null;
  const summaries = (r.summaries || []).slice().reverse();
  $('detail-content').innerHTML = `
    <h2 style="margin-top:8px">${esc(r.title)}</h2>
    ${audioURL ? `<div class="card"><audio controls src="${audioURL}"></audio><div class="pill">◷ ${clock(r.duration)} · transcribed on-device</div></div>` : ''}
    <div class="card">
      <h3>Summarize <span class="pill">${settings.claudeKey ? 'Claude' : 'add key in ⚙︎'}</span></h3>
      <div class="chips" id="template-chips">
        ${TEMPLATES.map((t, i) => `<button class="chip" data-i="${i}">${t.symbol} ${t.name}</button>`).join('')}
      </div>
      <div id="summarize-status" class="status" style="margin-top:10px"></div>
    </div>
    <button class="btn block" id="open-ask" style="margin-bottom:14px">💬 Ask your notes</button>
    ${summaries.map((s) => `
      <div class="card">
        <h3>${esc(s.template)} <span class="pill">${esc(s.engine)}</span></h3>
        <div class="summary-body">${md(s.content)}</div>
      </div>`).join('')}
    <div class="card">
      <h3>Transcript <button class="chip" id="copy-md">Copy note</button></h3>
      <div class="transcript">${esc(r.transcript || 'No transcript.')}</div>
    </div>
    <button class="btn block" id="del-rec" style="color:var(--warn);margin-top:6px">Delete recording</button>
  `;
  $('template-chips').querySelectorAll('.chip').forEach((el) => el.onclick = () => runTemplate(+el.dataset.i));
  $('open-ask').onclick = openAsk;
  $('copy-md').onclick = copyNote;
  $('del-rec').onclick = deleteCurrent;
}
async function runTemplate(i) {
  const t = TEMPLATES[i];
  const status = $('summarize-status');
  status.textContent = `Summarizing with ${settings.claudeModel}…`;
  try {
    const content = await claudeComplete(
      'You transform transcripts into clean notes in Markdown. The transcript is machine-generated and may contain errors; never invent facts. No meta-commentary.',
      [{ role: 'user', content: `${t.instructions}\n\n---\nTranscript:\n\n${current.transcript}` }]
    );
    current.summaries.push({ template: t.name, engine: `Claude (${settings.claudeModel})`, content, createdAt: Date.now() });
    await DB.put(current);
    renderDetail();
  } catch (e) {
    status.innerHTML = `<span class="err">${esc(e.message)}</span>`;
  }
}
function copyNote() {
  let md = `# ${current.title}\n\n`;
  for (const s of current.summaries) md += `## ${s.template}\n\n${s.content}\n\n`;
  md += `## Transcript\n\n${current.transcript}\n`;
  navigator.clipboard?.writeText(md).then(() => toast('Note copied'), () => toast('Copy failed'));
  if (navigator.share) navigator.share({ title: current.title, text: md }).catch(() => {});
}
async function deleteCurrent() {
  await DB.del(current.id);
  renderLibrary();
  show('library');
}

// ---------- Ask ----------
let chat = [];
function openAsk() { chat = []; $('ask-chat').innerHTML = ''; renderChat(); show('ask'); }
function renderChat() {
  $('ask-chat').innerHTML = chat.map((m) => `<div class="bubble ${m.role === 'user' ? 'user' : 'bot'}">${m.role === 'user' ? esc(m.content) : md(m.content)}</div>`).join('')
    + (chat.thinking ? '<div class="bubble bot">…</div>' : '');
  const chatEl = $('ask-chat');
  chatEl.scrollTop = chatEl.scrollHeight;
}
async function sendAsk() {
  const input = $('ask-input');
  const q = input.value.trim();
  if (!q || chat.thinking) return;
  input.value = '';
  const history = chat.map((m) => ({ role: m.role, content: m.content }));
  chat.push({ role: 'user', content: q });
  chat.thinking = true; renderChat();
  try {
    const answer = await claudeComplete(
      `You answer questions about ONE transcript. Base answers strictly on it; if it doesn't contain the answer, say so. Be concise.\n\n--- TRANSCRIPT ---\n${current.transcript}\n--- END ---`,
      [...history, { role: 'user', content: q }]
    );
    chat.push({ role: 'assistant', content: answer });
  } catch (e) {
    chat.push({ role: 'assistant', content: `⚠️ ${e.message}` });
  }
  chat.thinking = false; renderChat();
}

// ---------- Settings ----------
function openSettings() {
  $('set-key').value = settings.claudeKey;
  $('set-model').value = settings.claudeModel;
  $('set-whisper').value = settings.whisperModel;
  show('settings');
}
function saveSettings() {
  settings.claudeKey = $('set-key').value.trim();
  settings.claudeModel = $('set-model').value.trim() || 'claude-sonnet-5';
  settings.whisperModel = $('set-whisper').value;
  localStorage.setItem('claudeKey', settings.claudeKey);
  localStorage.setItem('claudeModel', settings.claudeModel);
  localStorage.setItem('whisperModel', settings.whisperModel);
  if (asrModelId !== settings.whisperModel) { asrPipeline = null; }
  toast('Saved');
  show('library');
}

// ---------- Wire up ----------
function resetRecordScreen() {
  $('rec-timer').textContent = '0:00';
  $('rec-status').textContent = 'Tap start to record';
  $('rec-progress').style.width = '0%';
  $('rec-live').textContent = 'Transcript will appear here after you stop…';
  $('rec-toggle').textContent = 'Start recording';
  $('rec-pulse').style.visibility = 'hidden';
}
$('fab-record').onclick = () => { resetRecordScreen(); show('record'); };
$('record-back').onclick = () => { if (R.active) stopRecording(); show('library'); };
$('rec-toggle').onclick = () => { if (R.active) stopRecording(); else startRecording(); };
$('detail-back').onclick = () => show('library');
$('ask-back').onclick = () => renderDetail() || show('detail');
$('ask-send').onclick = sendAsk;
$('ask-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') sendAsk(); });
$('nav-settings').onclick = openSettings;
$('settings-back').onclick = () => show('library');
$('set-save').onclick = saveSettings;

// ---------- Boot ----------
(async function boot() {
  await DB.open();
  await renderLibrary();
  show('library');
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  }
})();
