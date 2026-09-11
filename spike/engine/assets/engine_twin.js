// engine_twin.js — JS twin of the Dart spike kernels, executed by QuickJS
// via flutter_js. Measures the interpreter tax on identical inputs: the
// corpus is generated deterministically in Dart and passed in as JSON, so
// both runtimes do the same work on the same bytes.
//
// Parity notes: mirrors the Dart kernels' semantics (tokenize → normalize →
// stem; BM25 k1=1.2/b=0.75 with RSJ idf; dedup L1/L2/L3; citation stripping;
// SSE frames + ring). L2 uses the normalize-once lexical trick because
// QuickJS ships no WebCrypto; it matches the Dart kernel's invariance
// guarantees (whitespace/case/punctuation) though not its digest bytes —
// the desktop oracle's real SHA-256 parity comes via the gold vectors.

var AR_PREFIX_CLITICS = ['ال', 'وال', 'فال', 'بال', 'لل', 'كال'];
var AR_NORM = { 'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ٱ': 'ا', 'ة': 'ه', 'ى': 'ي', 'ؤ': 'و', 'ئ': 'ي' };

function isDiacritic(cp) {
  return (cp >= 0x064B && cp <= 0x065F) || cp === 0x0670 ||
         (cp >= 0x06D6 && cp <= 0x06ED) || cp === 0x0640;
}

function stripDiacritics(s) {
  var out = '';
  for (var i = 0; i < s.length; i++) {
    var cp = s.codePointAt(i);
    if (!isDiacritic(cp)) out += String.fromCodePoint(cp);
    if (cp > 0xffff) i++;
  }
  return out;
}

function normalizeToken(t) {
  t = stripDiacritics(t);
  var out = '';
  for (var i = 0; i < t.length; i++) {
    var ch = t[i];
    out += AR_NORM[ch] || ch.toLowerCase();
  }
  return out;
}

function hasArabic(t) {
  for (var i = 0; i < t.length; i++) {
    var cp = t.codePointAt(i);
    if (cp >= 0x0621 && cp <= 0x064A) return true;
  }
  return false;
}

function stemArabic(t) {
  var stripped = true;
  while (stripped && t.length > 4) {
    stripped = false;
    for (var k = 0; k < AR_PREFIX_CLITICS.length; k++) {
      var c = AR_PREFIX_CLITICS[k];
      if (t.lastIndexOf(c, 0) === 0 && t.length - c.length >= 3) {
        t = t.substring(c.length);
        stripped = true;
        break;
      }
    }
  }
  return t;
}

function isLetter(cp) {
  return (cp >= 0x30 && cp <= 0x39) || (cp >= 0x0660 && cp <= 0x0669) ||
         (cp >= 0x41 && cp <= 0x5A) || (cp >= 0x61 && cp <= 0x7A) ||
         (cp >= 0x0621 && cp <= 0x064A) ||
         (cp >= 0xAA && cp <= 0x2AF) || (cp >= 0x370 && cp <= 0x3FF) ||
         (cp >= 0x4E00 && cp <= 0x9FFF) || (cp >= 0x0400 && cp <= 0x04FF);
}

function tokenize(text) {
  var tokens = [], cur = '';
  for (var i = 0; i < text.length; i++) {
    var cp = text.codePointAt(i);
    if (cp > 0xffff) i++;
    if (isLetter(cp)) cur += String.fromCodePoint(cp);
    else if (cur) { tokens.push(cur); cur = ''; }
  }
  if (cur) tokens.push(cur);
  return tokens;
}

function analyze(text) {
  var raw = tokenize(text), out = [];
  for (var i = 0; i < raw.length; i++) {
    var t = normalizeToken(raw[i]);
    if (hasArabic(t)) t = stemArabic(t);
    if (t) out.push(t);
  }
  return out;
}

// ---------- BM25 (k1=1.2, b=0.75, RSJ idf) ----------
function Bm25() {
  this.freqs = {}; this.lens = {}; this.df = {}; this.n = 0; this.avg = 0;
}
Bm25.prototype.add = function (id, text) {
  var terms = analyze(text), f = {};
  for (var i = 0; i < terms.length; i++) f[terms[i]] = (f[terms[i]] || 0) + 1;
  this.freqs[id] = f; this.lens[id] = terms.length; this.n++;
  for (var t in f) this.df[t] = (this.df[t] || 0) + 1;
};
Bm25.prototype.build = function () {
  var total = 0; for (var id in this.lens) total += this.lens[id];
  this.avg = this.n ? total / this.n : 0;
};
Bm25.prototype.idf = function (t) {
  var df = this.df[t] || 0;
  if (!this.n || !df) return 0;
  return Math.log((this.n - df + 0.5) / (df + 0.5) + 1);
};
Bm25.prototype.search = function (query, topK) {
  var qt = analyze(query), scores = {}, k1 = 1.2, b = 0.75;
  for (var id in this.freqs) {
    var f = this.freqs[id], dl = this.lens[id], s = 0;
    if (!dl) continue;
    for (var i = 0; i < qt.length; i++) {
      var tf = f[qt[i]];
      if (!tf) continue;
      s += this.idf(qt[i]) * (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (dl / this.avg)));
    }
    if (s > 0) scores[id] = s;
  }
  var res = [];
  for (var id2 in scores) res.push([id2, scores[id2]]);
  res.sort(function (a, c) { return c[1] - a[1] || (a[0] < c[0] ? -1 : 1); });
  return res.slice(0, topK || 10);
};

// ---------- Dedup L1/L2/L3 ----------
function canonicalUrl(url) {
  var m = url.trim().toLowerCase().match(/^(?:https?:)?\/\/([^\/?#]+)([^?#]*)(\?[^#]*)?/);
  if (!m) return url.trim().toLowerCase();
  var host = m[1].replace(/^www\./, '');
  var path = m[2];
  if (path.length > 1 && path.charAt(path.length - 1) === '/') path = path.slice(0, -1);
  return host + path + (m[3] || '');
}

function lexicalKey(content) {
  // normalize-once trick: collapse whitespace, lowercase, strip punctuation
  // (invariance-compatible with the Dart kernel's SHA-256 L2; no WebCrypto in QuickJS).
  return content.toLowerCase().replace(/\s+/g, ' ')
    .replace(/[^\w\u0600-\u06FF ]/g, '').trim();
}

function fnv64(bytes) {
  var h1 = 0x811c9dc5, h2 = 0x1000193;
  for (var i = 0; i < bytes.length; i++) {
    h1 = (h1 ^ bytes[i]) >>> 0; h1 = (h1 * 0x01000193) >>> 0;
    h2 = ((h2 ^ (bytes[i] << 5)) >>> 0); h2 = (h2 * 0x85ebca6b) >>> 0;
  }
  return [h1 >>> 0, h2 >>> 0];
}

function simhash64(tokens) {
  var v = new Array(64).fill(0);
  for (var i = 0; i < tokens.length; i++) {
    var bytes = [];
    var tok = tokens[i];
    for (var j = 0; j < tok.length; j++) bytes.push(tok.charCodeAt(j) & 0xff);
    var h = fnv64(bytes);
    var all = [h[0], h[1]];
    for (var b = 0; b < 64; b++) {
      var word = all[b < 32 ? 0 : 1], bit = (word >>> (b % 32)) & 1;
      v[b] += bit ? 1 : -1;
    }
  }
  var w0 = 0, w1 = 0;
  for (var b2 = 0; b2 < 64; b2++) {
    if (v[b2] > 0) { if (b2 < 32) w0 |= (1 << b2) >>> 0; else w1 |= (1 << (b2 - 32)) >>> 0; }
  }
  return [w0 >>> 0, w1 >>> 0];
}

function hamming(a, b) {
  var d = 0;
  for (var w = 0; w < 2; w++) {
    var x = (a[w] ^ b[w]) >>> 0;
    while (x) { d += x & 1; x = x >>> 1; }
  }
  return d;
}

function hex(words) {
  return words.map(function (w) { return ('00000000' + w.toString(16)).slice(-8); }).join('');
}

function Dedup() {
  this.urls = {}; this.keys = {}; this.sims = [];
}
Dedup.prototype.decide = function (url, content) {
  var c = canonicalUrl(url);
  if (this.urls[c]) return { v: 'dup-url', m: this.urls[c], h: '' };
  var key = lexicalKey(content);
  if (this.keys[key]) return { v: 'dup-content', m: this.keys[key], h: '' };
  var sh = simhash64(analyze(content));
  for (var i = 0; i < this.sims.length; i++) {
    if (hamming(sh, this.sims[i].sh) <= 3) return { v: 'near', m: this.sims[i].url, h: hex(sh) };
  }
  this.urls[c] = url; this.keys[key] = url;
  this.sims.push({ url: url, sh: sh });
  return { v: 'unique', m: null, h: hex(sh) };
};

// ---------- Citation stripping + SSE + ring ----------
function cleanCitations(text, maxIndex) {
  return text.replace(/\[(\d{1,3})\]/g, function (m, d) {
    var n = parseInt(d, 10);
    return (n >= 1 && n <= maxIndex) ? m : '';
  });
}

function feedSse(state, chunk) {
  state.buf += chunk;
  var frames = state.buf.split('\n\n');
  state.buf = frames.pop();
  for (var i = 0; i < frames.length; i++) {
    var lines = frames[i].split('\n'), data = [];
    for (var j = 0; j < lines.length; j++) {
      if (lines[j].lastIndexOf('data:', 0) === 0) data.push(lines[j].substring(5).trim());
    }
    var payload = data.join('\n');
    if (payload === '[DONE]') continue;
    state.count++;
  }
}

// ---------- Entry point ----------
globalThis.bench = function (corpusJson) {
  var t0 = Date.now();
  var corpus = JSON.parse(corpusJson);

  var bm = new Bm25();
  for (var i = 0; i < corpus.docs.length; i++) bm.add(corpus.docs[i].id, corpus.docs[i].text);
  bm.build();
  var bmMs = Date.now() - t0;
  var q0 = Date.now();
  var queryResults = [];
  for (var q = 0; q < corpus.queries.length; q++) {
    queryResults.push(bm.search(corpus.queries[q], 10).map(function (r) { return r[0]; }));
  }
  var queryMs = Date.now() - q0;

  var t1 = Date.now();
  var dd = new Dedup(), v = { unique: 0, near: 0, dup: 0 };
  for (var i2 = 0; i2 < corpus.dedup.length; i2++) {
    var r = corpus.dedup[i2];
    var d = dd.decide(r.url, r.text);
    if (d.v === 'unique') v.unique++; else if (d.v === 'near') v.near++; else v.dup++;
  }
  var dedupMs = Date.now() - t1;

  var t2 = Date.now();
  var draft = 'evidence supports [1], contradicts [2], hallucinates [' + (corpus.dedup.length + 1) + '] and [999]';
  var cleaned = cleanCitations(draft, corpus.dedup.length);
  var citMs = Date.now() - t2;

  var t3 = Date.now();
  var sse = { buf: '', count: 0 };
  // Ring mirroring the Dart probe's workload: 300-capacity, push per event,
  // replay since=last-50 — all inside the timed window (matched workloads).
  var RING_CAP = 300;
  var ring = new Array(RING_CAP), ringStart = 0, ringSize = 0, ringNext = 0;
  for (var e = 0; e < 10000; e++) {
    var frame = 'event: telemetry\ndata: {"i":' + e + '}\n\n';
    feedSse(sse, frame);
    if (ringSize === RING_CAP) {
      ring[ringStart] = frame; ringStart = (ringStart + 1) % RING_CAP;
    } else {
      ring[(ringStart + ringSize) % RING_CAP] = frame; ringSize++;
    }
    ringNext++;
  }
  var since = ringNext - 1 - 50;
  var firstAvail = ringNext - ringSize;
  var replayed = since < firstAvail ? ringSize : (ringNext - 1 - since);
  var sseMs = Date.now() - t3;

  return JSON.stringify({
    bmBuildMs: bmMs, bmQueryMs: queryMs, topQuery: queryResults[0] ? queryResults[0].slice(0, 3) : [],
    dedupMs: dedupMs, dedupVerdicts: v,
    citationMs: citMs, kept: (cleaned.match(/\[\d+\]/g) || []).length,
    sseMs: sseMs, sseEvents: sse.count, ringReplayed: replayed
  });
};
