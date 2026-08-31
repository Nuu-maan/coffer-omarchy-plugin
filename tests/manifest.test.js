var assert = require("assert")
var fs = require("fs")
var path = require("path")

var root = path.join(__dirname, "..")
var manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"))

var passed = 0
function test(name, fn) {
  try { fn(); passed++ } catch (e) {
    console.error("FAIL: " + name + "\n  " + (e && e.message ? e.message : e))
    process.exitCode = 1
  }
}

test("schemaVersion is the number 1, not a string", function () {
  assert.strictEqual(manifest.schemaVersion, 1)
})

test("every required field is present", function () {
  ;["id", "name", "version", "kinds", "entryPoints"].forEach(function (key) {
    assert.notStrictEqual(manifest[key], undefined, "missing " + key)
  })
})

test("the id is well formed and outside the reserved namespace", function () {
  assert.ok(/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(manifest.id), "bad id: " + manifest.id)
  assert.strictEqual(manifest.id.indexOf("omarchy."), -1)
})

test("kinds is a non-empty array of known kinds", function () {
  var known = ["bar-widget", "panel", "overlay", "menu", "service", "bar"]
  assert.ok(Array.isArray(manifest.kinds) && manifest.kinds.length > 0)
  manifest.kinds.forEach(function (k) {
    assert.notStrictEqual(known.indexOf(k), -1, "unknown kind: " + k)
  })
})

test("every declared kind has an entry point that exists on disk", function () {
  var keyFor = { bar: "bar", "bar-widget": "barWidget", menu: "menu",
                 overlay: "overlay", panel: "panel", service: "service" }
  manifest.kinds.forEach(function (kind) {
    var target = manifest.entryPoints[keyFor[kind]]
    assert.ok(target, "no entryPoints." + keyFor[kind] + " for kind " + kind)
    assert.ok(fs.existsSync(path.join(root, target)), "missing file: " + target)
  })
})

test("entry points are relative paths that cannot escape the plugin directory", function () {
  Object.keys(manifest.entryPoints).forEach(function (key) {
    var target = manifest.entryPoints[key]
    assert.strictEqual(target.indexOf(".."), -1, "escaping path: " + target)
    assert.notStrictEqual(target.charAt(0), "/", "absolute path: " + target)
  })
})

test("the bar widget declares a section the shell recognises", function () {
  assert.notStrictEqual(["left", "center", "right"].indexOf(manifest.barWidget.defaultSection), -1)
})

test("every default has a matching schema entry, and the values agree", function () {
  var schema = manifest.barWidget.schema
  var defaults = manifest.barWidget.defaults
  Object.keys(defaults).forEach(function (key) {
    var entry = schema.filter(function (s) { return s.key === key })[0]
    assert.ok(entry, "no schema entry for default " + key)
    assert.deepStrictEqual(defaults[key], entry.defaultValue, "default mismatch for " + key)
  })
})

test("schema entries use types the settings UI can render", function () {
  var known = ["boolean", "integer", "string", "enum", "path", "multiselect"]
  manifest.barWidget.schema.forEach(function (entry) {
    assert.ok(entry.key, "schema entry without a key")
    assert.notStrictEqual(known.indexOf(entry.type), -1, "unknown type: " + entry.type)
    if (entry.type === "integer") {
      assert.ok(entry.defaultValue >= entry.min && entry.defaultValue <= entry.max,
        entry.key + " default is outside its own range")
    }
  })
})

test("the action launcher ships executable", function () {
  var launcher = path.join(root, "bin", "omarchy-coffer")
  assert.ok(fs.existsSync(launcher), "missing bin/omarchy-coffer")
  assert.ok(fs.statSync(launcher).mode & 0o111, "bin/omarchy-coffer is not executable")
})

if (!process.exitCode) console.log(passed + " manifest tests passed")
