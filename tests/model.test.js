var assert = require("assert")
var Model = require("../Model.js")

var passed = 0
function test(name, fn) {
  try { fn(); passed++ } catch (e) {
    console.error("FAIL: " + name + "\n  " + (e && e.message ? e.message : e))
    process.exitCode = 1
  }
}

function store(items, sections) {
  return JSON.stringify({ version: 3, items: items || [], sections: sections || [], settings: {} })
}

function text(id, order, extra) {
  var item = { id: id, kind: "text", text: "item " + id, done: false, order: order, createdAt: order }
  for (var key in (extra || {})) item[key] = extra[key]
  return item
}

test("an absent store reads as empty rather than an error", function () {
  var parsed = Model.parseStore("")
  assert.deepStrictEqual(parsed.items, [])
  assert.strictEqual(parsed.error, "")
})

test("unreadable JSON is reported, not thrown", function () {
  var parsed = Model.parseStore("{\"items\": [")
  assert.strictEqual(parsed.items.length, 0)
  assert.ok(parsed.error)
})

test("a JSON scalar is reported rather than read as a store", function () {
  assert.ok(Model.parseStore("42").error)
})

test("items are sorted by order, not by position in the file", function () {
  var parsed = Model.parseStore(store([text("b", 2000), text("a", 1000)]))
  assert.deepStrictEqual(parsed.items.map(function (i) { return i.id }), ["a", "b"])
})

test("items missing an id are dropped instead of rendering blank rows", function () {
  var parsed = Model.parseStore(store([{ kind: "text", text: "orphan" }, text("a", 1000)]))
  assert.deepStrictEqual(parsed.items.map(function (i) { return i.id }), ["a"])
})

test("done items are not open", function () {
  var items = [text("a", 1000), text("b", 2000, { done: true })]
  assert.deepStrictEqual(Model.openItems(items).map(function (i) { return i.id }), ["a"])
})

test("groups follow section order and untagged items come last", function () {
  var items = [
    text("plain", 1000),
    text("r", 2000, { tag: "Research" }),
    text("t", 3000, { tag: "Todo" })
  ]
  var sections = [{ name: "Todo", order: 2000 }, { name: "Research", order: 1000 }]
  var groups = Model.groupItems(items, sections).groups
  assert.deepStrictEqual(groups.map(function (g) { return g.name }), ["Research", "Todo", ""])
})

test("a tag matches its section case-insensitively", function () {
  var items = [text("r", 1000, { tag: "research" })]
  var groups = Model.groupItems(items, [{ name: "Research", order: 1000 }]).groups
  assert.strictEqual(groups.length, 1)
  assert.strictEqual(groups[0].name, "Research")
})

test("an item whose section no longer exists still shows, as untagged", function () {
  var groups = Model.groupItems([text("a", 1000, { tag: "Gone" })], []).groups
  assert.deepStrictEqual(groups.map(function (g) { return g.name }), [""])
})

test("the limit caps what is shown and counts what is not", function () {
  var items = [text("a", 1000), text("b", 2000), text("c", 3000)]
  var result = Model.groupItems(items, [], 2)
  assert.strictEqual(result.shown, 2)
  assert.strictEqual(result.total, 3)
  assert.strictEqual(result.hidden, 1)
})

test("an empty section is not drawn", function () {
  var groups = Model.groupItems([text("a", 1000)], [{ name: "Empty", order: 1000 }]).groups
  assert.deepStrictEqual(groups.map(function (g) { return g.name }), [""])
})

test("an image is labelled by its caption", function () {
  var image = { id: "i", kind: "image", file: "i.png", caption: "a screenshot", done: false, order: 1 }
  assert.strictEqual(Model.itemLabel(image), "a screenshot")
})

test("a caption-less clip still says something", function () {
  var image = { id: "i", kind: "image", file: "i.png", caption: "", done: false, order: 1 }
  assert.strictEqual(Model.previewText(image, 40), "Untitled clip")
})

test("preview text is collapsed to one line and truncated", function () {
  var item = text("a", 1000)
  item.text = "one\ntwo   three"
  assert.strictEqual(Model.previewText(item), "one two three")
  assert.strictEqual(Model.previewText(item, 8).length, 8)
})

test("an image path is resolved under the images directory", function () {
  var image = { id: "i", kind: "image", file: "i.png" }
  assert.strictEqual(Model.imagePathFor("/home/u/.config/coffer/images", image),
    "/home/u/.config/coffer/images/i.png")
})

test("a file name that tries to escape the images directory is refused", function () {
  var image = { id: "i", kind: "image", file: "../../.ssh/id_rsa" }
  assert.strictEqual(Model.imagePathFor("/home/u/.config/coffer/images", image), "")
})

test("a text item has no image path", function () {
  assert.strictEqual(Model.imagePathFor("/images", text("a", 1)), "")
})

test("the badge is empty at zero and capped above ninety-nine", function () {
  assert.strictEqual(Model.badgeText(0), "")
  assert.strictEqual(Model.badgeText(7), "7")
  assert.strictEqual(Model.badgeText(120), "99+")
})

test("the tooltip is singular for one item", function () {
  assert.ok(Model.tooltipFor(1).indexOf("1 open item") !== -1)
  assert.ok(Model.tooltipFor(3).indexOf("3 open items") !== -1)
})

test("the hero says how many items the limit is holding back", function () {
  var result = Model.groupItems([text("a", 1), text("b", 2)], [], 1)
  assert.ok(Model.heroMeta(result).indexOf("1 not shown") !== -1)
})

test("a QML sequence is treated as a list, not discarded", function () {
  var sequence = { length: 2, 0: text("a", 1000), 1: text("b", 2000) }
  assert.strictEqual(Model.openItems(sequence).length, 2)
})

if (!process.exitCode) console.log(passed + " model tests passed")
