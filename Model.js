function asList(value) {
  if (!value) return []
  if (Array.isArray(value)) return value
  if (typeof value !== "object") return []
  var n = Number(value.length)
  if (!isFinite(n) || n <= 0) return []
  var out = []
  for (var i = 0; i < n; i++) out.push(value[i])
  return out
}

function itemLabel(item) {
  if (!item) return ""
  return String((item.kind === "image" ? item.caption : item.text) || "")
}

function byOrder(a, b) {
  var da = Number(a.order), db = Number(b.order)
  if (!isFinite(da)) da = 0
  if (!isFinite(db)) db = 0
  if (da !== db) return da - db
  return Number(a.createdAt || 0) - Number(b.createdAt || 0)
}

function normalizeItem(raw) {
  if (!raw || typeof raw !== "object") return null
  var id = String(raw.id || "")
  if (!id) return null
  var kind = raw.kind === "image" ? "image" : "text"
  var item = {
    id: id,
    kind: kind,
    done: raw.done === true,
    order: isFinite(Number(raw.order)) ? Number(raw.order) : 0,
    createdAt: isFinite(Number(raw.createdAt)) ? Number(raw.createdAt) : 0,
    tag: typeof raw.tag === "string" && raw.tag.trim() ? raw.tag : ""
  }
  if (kind === "image") {
    item.file = String(raw.file || "")
    item.caption = String(raw.caption || "")
    item.width = Number(raw.width) || 0
    item.height = Number(raw.height) || 0
  } else {
    item.text = String(raw.text || "")
  }
  return item
}

function normalizeSection(raw) {
  if (!raw || typeof raw !== "object") return null
  var name = String(raw.name || "")
  if (!name) return null
  return { name: name, order: isFinite(Number(raw.order)) ? Number(raw.order) : 0 }
}

function parseStore(raw) {
  var empty = { items: [], sections: [], error: "" }
  var text = String(raw === undefined || raw === null ? "" : raw).trim()
  if (!text) return empty

  var parsed
  try {
    parsed = JSON.parse(text)
  } catch (e) {
    return { items: [], sections: [], error: "store.json is not valid JSON" }
  }
  if (!parsed || typeof parsed !== "object") {
    return { items: [], sections: [], error: "store.json is not a Coffer store" }
  }

  var items = []
  var rawItems = asList(parsed.items)
  for (var i = 0; i < rawItems.length; i++) {
    var item = normalizeItem(rawItems[i])
    if (item) items.push(item)
  }
  var sections = []
  var rawSections = asList(parsed.sections)
  for (var s = 0; s < rawSections.length; s++) {
    var section = normalizeSection(rawSections[s])
    if (section) sections.push(section)
  }
  items.sort(byOrder)
  sections.sort(byOrder)
  return { items: items, sections: sections, error: "" }
}

function openItems(items) {
  var list = asList(items)
  var out = []
  for (var i = 0; i < list.length; i++) {
    if (list[i] && list[i].done !== true) out.push(list[i])
  }
  return out
}

function sameTag(a, b) {
  return String(a || "").toLocaleLowerCase() === String(b || "").toLocaleLowerCase()
}

function groupItems(items, sections, limit) {
  var open = openItems(items)
  var max = isFinite(Number(limit)) && Number(limit) > 0 ? Math.floor(Number(limit)) : open.length
  var shown = open.slice(0, max)

  var ordered = asList(sections).slice().sort(byOrder)
  var groups = []
  var taken = {}

  for (var s = 0; s < ordered.length; s++) {
    var members = []
    for (var i = 0; i < shown.length; i++) {
      if (!taken[shown[i].id] && sameTag(shown[i].tag, ordered[s].name)) {
        taken[shown[i].id] = true
        members.push(shown[i])
      }
    }
    if (members.length) groups.push({ name: ordered[s].name, items: members })
  }

  var untagged = []
  for (var u = 0; u < shown.length; u++) {
    if (!taken[shown[u].id]) untagged.push(shown[u])
  }
  if (untagged.length) groups.push({ name: "", items: untagged })

  return { groups: groups, shown: shown.length, total: open.length, hidden: open.length - shown.length }
}

function flatten(groups) {
  var list = asList(groups)
  var out = []
  for (var g = 0; g < list.length; g++) {
    var members = asList(list[g].items)
    for (var i = 0; i < members.length; i++) out.push(members[i])
  }
  return out
}

function indexOfId(items, id) {
  var list = asList(items)
  for (var i = 0; i < list.length; i++) {
    if (list[i] && String(list[i].id) === String(id)) return i
  }
  return -1
}

function badgeText(count) {
  var n = Number(count)
  if (!isFinite(n) || n <= 0) return ""
  return n > 99 ? "99+" : String(Math.floor(n))
}

function tooltipFor(count) {
  var n = Number(count)
  if (!isFinite(n) || n <= 0) return "Coffer — nothing open"
  return "Coffer — " + n + (n === 1 ? " open item" : " open items")
}

function heroMeta(result) {
  if (!result || !result.total) return "Nothing open"
  var meta = result.total + (result.total === 1 ? " open item" : " open items")
  if (result.hidden > 0) meta += "  ·  " + result.hidden + " not shown"
  return meta
}

function previewText(item, limit) {
  var label = itemLabel(item).replace(/\s+/g, " ").trim()
  var max = isFinite(Number(limit)) && Number(limit) > 0 ? Number(limit) : 0
  if (!label) return item && item.kind === "image" ? "Untitled clip" : "Empty item"
  if (max && label.length > max) return label.slice(0, max - 1) + "…"
  return label
}

function imagePathFor(imagesDir, item) {
  if (!item || item.kind !== "image" || !item.file) return ""
  if (String(item.file).indexOf("/") !== -1) return ""
  return String(imagesDir).replace(/\/+$/, "") + "/" + item.file
}

if (typeof module !== "undefined") module.exports = {
  asList, itemLabel, byOrder, normalizeItem, normalizeSection,
  parseStore, openItems, sameTag, groupItems, flatten, indexOfId,
  badgeText, tooltipFor, heroMeta, previewText, imagePathFor
}
