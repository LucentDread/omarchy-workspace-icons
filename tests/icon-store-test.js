// Run: node tests/icon-store-test.js
const fs = require("fs")
const path = require("path")
const assert = require("assert")

// IconStore.js is a QML JS library; drop its pragma and load it as a script.
const src = fs.readFileSync(path.join(__dirname, "..", "IconStore.js"), "utf8").replace(".pragma library", "")
const S = new Function(src + "; return { parseGlyphs, searchGlyphs, validIcon, normalize, parseSettings, withIcon, serialize }")()

const glyphs = S.parseGlyphs(fs.readFileSync(path.join(__dirname, "..", "glyphs.tsv"), "utf8"))
assert(glyphs.length > 10000, "glyph index loads")
assert(glyphs.every(g => Array.from(g.glyph).length === 1), "one glyph per row")

const names = q => S.searchGlyphs(glyphs, q, 5).map(g => g.name)
assert.equal(names("fire")[0].endsWith("-fire"), true, "whole-word match first: " + names("fire"))
assert(names("firefox").some(n => n.includes("firefox")))
assert(S.searchGlyphs(glyphs, "terminal linux", 50).every(g => g.name.includes("terminal") && g.name.includes("linux")))
assert.equal(S.searchGlyphs(glyphs, "zzzznotaglyph", 5).length, 0)
assert.deepStrictEqual(S.searchGlyphs(glyphs, "", 3).map(g => g.name), ["md-firefox", "fa-chrome", "md-web"], "suggestions first")
assert.equal(S.searchGlyphs(glyphs, "", 500).length, 500)

assert(S.validIcon("") && S.validIcon("🔥") && S.validIcon("IDE"))
assert(!S.validIcon("") && !S.validIcon("a\nb") && !S.validIcon("way too long label"))

let s = S.parseSettings('{"icons":{"1":"","3":"x","11":"y","0":"z","2.5":"w","4":"bad\\u0007"},"other":true}')
assert.deepStrictEqual(s, { version: 1, icons: { "1": "", "3": "x" } })
assert.deepStrictEqual(S.parseSettings("{oops"), { version: 1, icons: {} })
assert.deepStrictEqual(S.parseSettings(""), { version: 1, icons: {} })

s = S.withIcon(s, 10, "")
assert.equal(s.icons["10"], "")
s = S.withIcon(s, 1, "")
assert(!("1" in s.icons))
assert.deepStrictEqual(S.parseSettings(S.serialize(s)), s)
console.log("icon store tests passed")
