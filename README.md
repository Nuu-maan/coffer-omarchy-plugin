# Coffer for Omarchy

Coffer's capture queue in the Omarchy bar. A count of what is still open, a
panel that lists it grouped by section, and the two capture actions without
leaving what you are doing.

[Coffer](https://github.com/Nuu-maan/coffer) is a capture buffer and prompt
queue for AI-assisted work: stash a text selection, clip a screen region, then
work the list down by copying each item into Claude, ChatGPT, or Cursor and
ticking it off. This plugin puts the list where you can see it.

## Install

```bash
git clone https://github.com/Nuu-maan/coffer-omarchy-plugin
cd coffer-omarchy-plugin
./dev-install.sh
omarchy plugin enable io.github.nuu-maan.coffer right
```

`dev-install.sh` copies the tree into `~/.config/omarchy/plugins/` — the shell
only discovers plugins exactly one level down, and a symlink is not a
substitute because the hot-reload watcher does not follow one.

Coffer itself is not required for the bar to work. Without it the panel says so
and the capture buttons report that they could not find it.

## Settings

Both live on the widget's entry in `shell.json` and are editable from Omarchy's
bar settings.

| Setting | Default | What it does |
| --- | --- | --- |
| Hide the icon when the queue is empty | off | Leave the icon in place and dim it, or take it out of the bar entirely until something is stashed. |
| Items shown in the panel | 20 | How many open items the panel lists before it stops and says how many more there are. The bar count is always the full number. |

## How it reads Coffer

The queue comes from `~/.config/coffer/store.json`, watched with a Quickshell
`FileView` — no polling, no daemon, no IPC. Coffer writes that file atomically,
so a read never lands on a half-written document. Image thumbnails are loaded
straight out of `~/.config/coffer/images/`.

Nothing here ever writes the store. The running app holds it in memory and
debounce-saves, so an outside write would be clobbered on its next save. Every
mutation has to go through Coffer, which is what `bin/omarchy-coffer` is for:
it forwards `--stash` and `--clip` to the running instance through Electron's
single-instance handler.

That leaves one gap worth knowing about. `FileView` cannot watch a file that
does not exist, so on a machine that has never run Coffer the service retries
the read every five seconds until the file appears, then stops for good. It is
the one timer in the plugin, and it never runs once a store exists.

### Finding Coffer

`bin/omarchy-coffer` resolves the executable in this order, and stops at the
first hit:

1. `$COFFER_BIN`
2. `coffer` on `$PATH`
3. the `Exec=` line of `coffer.desktop` or `com.coffer.app.desktop` in the XDG
   data directories
4. the usual install paths — `~/Applications/Coffer/`, the AppImage, `/opt`,
   `/usr/bin`

An AppImage install puts nothing on `$PATH`, which is why step 3 exists. Set
`COFFER_BIN` if yours lives somewhere unusual.

## Development

```bash
./dev-install.sh                  # install and hot-reload
node tests/manifest.test.js       # manifest rules the shell actually enforces
node tests/model.test.js          # store parsing, grouping, limits
```

`Model.js` is plain functions of their arguments — no QML types, no file
access — which is what lets `Panel.qml`, `Service.qml`, and node all use it.

Panel state lives in `Panel.qml`, which is built once per monitor. Anything
there can only be one of — the file watcher, the process launcher — lives in
`Service.qml`, which the shell loads once per session.

## Licence

MIT.
