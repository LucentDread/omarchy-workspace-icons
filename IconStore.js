.pragma library

// Pure helpers shared by the bar widget and the editor. Plain JavaScript so
// Node can load it for tests (see tests/icon-store-test.js).

var MAX_WORKSPACE = 10
var MAX_ICON_LENGTH = 8

// Shown first when the search is empty: common workspace themes.
var SUGGESTED = [
  "md-firefox", "fa-chrome", "md-web", "md-earth", "fa-terminal", "md-console", "md-code_braces",
  "fa-code", "md-github", "md-git", "md-folder", "md-file_document", "md-note_text", "md-calendar",
  "md-email", "fa-envelope", "md-chat", "md-forum", "fa-discord", "fa-slack", "md-music", "fa-spotify",
  "md-play_circle", "md-youtube", "md-movie", "md-image", "md-camera", "md-palette", "md-brush",
  "md-pencil", "md-gamepad_variant", "fa-steam", "md-trophy", "md-robot", "md-brain", "md-flask",
  "md-chart_bar", "md-database", "md-server", "md-cloud", "md-docker", "md-kubernetes", "md-cog",
  "fa-gear", "md-wrench", "md-hammer", "md-shield", "md-lock", "md-key", "md-home", "fa-house",
  "md-briefcase", "md-school", "md-book_open_variant", "md-bookmark", "md-star", "md-heart", "md-fire",
  "md-lightning_bolt", "md-coffee", "fa-mug_hot", "md-rocket", "md-flag", "md-pin", "md-bell",
  "md-clock", "md-timer", "md-download", "md-cart", "md-headphones", "md-microphone", "md-video",
  "md-television", "md-monitor", "md-laptop", "md-cellphone", "md-printer", "md-wifi", "md-bluetooth",
  "linux-archlinux", "linux-tux", "md-language_python", "md-language_javascript", "md-language_rust",
  "md-language_go", "dev-react", "md-nodejs", "md-microsoft_visual_studio_code"
]

// Parse glyphs.tsv ("name<TAB>hex codepoint" rows, "#" comments) into
// [{ name, glyph, words }] sorted by name.
function parseGlyphs(text) {
  var out = []
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line || line.charAt(0) === "#") continue
    var tab = line.indexOf("\t")
    if (tab < 1) continue
    var code = parseInt(line.substring(tab + 1), 16)
    if (!isFinite(code) || code <= 0 || code > 0x10ffff) continue
    var name = line.substring(0, tab)
    out.push({ name: name, glyph: String.fromCodePoint(code), words: name.replace(/[-_]/g, " ") })
  }
  return out
}

// Every query word must appear in the glyph name. Names whose words start
// with the query rank first, then shorter names, so "fire" lists
// md-fire before md-firefox and fa-fire_extinguisher.
function searchGlyphs(glyphs, query, limit) {
  var terms = String(query || "").toLowerCase().trim().split(/\s+/).filter(function(t) { return t !== "" })
  var max = limit > 0 ? limit : 400
  if (terms.length === 0) return suggested(glyphs, max)
  var scored = []
  for (var i = 0; i < glyphs.length; i++) {
    var g = glyphs[i]
    var name = g.name.toLowerCase()
    var score = 0
    var ok = true
    for (var t = 0; t < terms.length; t++) {
      var at = name.indexOf(terms[t])
      if (at === -1) { ok = false; break }
      var before = at === 0 ? "-" : name.charAt(at - 1)
      if (before === "-" || before === "_") score += 2
      var after = name.charAt(at + terms[t].length)
      if (after === "" || after === "-" || after === "_") score += 1
    }
    if (ok) scored.push({ g: g, score: score })
  }
  scored.sort(function(a, b) {
    if (a.score !== b.score) return b.score - a.score
    if (a.g.name.length !== b.g.name.length) return a.g.name.length - b.g.name.length
    return a.g.name < b.g.name ? -1 : (a.g.name > b.g.name ? 1 : 0)
  })
  var out = []
  for (var j = 0; j < scored.length && j < max; j++) out.push(scored[j].g)
  return out
}

// The suggested glyphs in their listed order, then everything else.
function suggested(glyphs, max) {
  var byName = {}
  for (var i = 0; i < glyphs.length; i++) byName[glyphs[i].name] = glyphs[i]
  var out = []
  var seen = {}
  for (var j = 0; j < SUGGESTED.length && out.length < max; j++) {
    var g = byName[SUGGESTED[j]]
    if (g) { out.push(g); seen[g.name] = true }
  }
  for (var k = 0; k < glyphs.length && out.length < max; k++)
    if (!seen[glyphs[k].name]) out.push(glyphs[k])
  return out
}

// An icon is a short string (one glyph, an emoji, or a couple of letters)
// without control characters.
function validIcon(icon) {
  var s = String(icon === undefined || icon === null ? "" : icon)
  if (s === "" || Array.from(s).length > MAX_ICON_LENGTH) return false
  return !/[\u0000-\u001f\u007f]/.test(s)
}

// The settings file: { "version": 1, "icons": { "1": "", ... } }. Anything
// else in it is dropped, so a hand-edited file can only ever name icons for
// workspaces 1 to 10.
function normalize(raw) {
  var out = { version: 1, icons: {} }
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return out
  var icons = raw.icons
  if (!icons || typeof icons !== "object" || Array.isArray(icons)) return out
  for (var key in icons) {
    var n = Number(key)
    if (!(n >= 1 && n <= MAX_WORKSPACE && Math.floor(n) === n)) continue
    if (validIcon(icons[key])) out.icons[String(n)] = String(icons[key])
  }
  return out
}

function parseSettings(text) {
  try {
    return normalize(String(text || "").trim() === "" ? null : JSON.parse(text))
  } catch (e) {
    return normalize(null)
  }
}

function withIcon(settings, workspace, icon) {
  var next = normalize(settings)
  var key = String(workspace)
  if (validIcon(icon)) next.icons[key] = String(icon)
  else delete next.icons[key]
  return next
}

function serialize(settings) {
  return JSON.stringify(normalize(settings), null, 2) + "\n"
}
