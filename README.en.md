# Evaporate

*[Русская версия](README.md)*

A desktop game launcher built with Flutter: a library, BitTorrent downloads,
and — the point of the whole thing — save files you can pick up as a single
file and carry to another machine.

The app ships **no content catalogue**. You provide the source for every game
yourself: a magnet link, a `.torrent` file, or a folder that is already on disk.

## What it does

- **Library** — games, states, time played, last launch date.
- **Downloads** — magnet links and `.torrent` files through a pure-Dart client
  (`dtorrent_task_v2`): DHT, a reorderable queue, pause and resume, and
  **SOCKS5 all the way down to peer connections**. The queue survives a restart.
- **Launching** — finds the executable inside a downloaded folder, runs the
  `.app` on macOS, the `.exe` on Windows, the binary on Linux, and counts
  play time.
- **Saves** — `.evsave` snapshots, an automatic snapshot after you quit a game,
  restore with a safety backup, export and import, a sync folder, and moving
  the whole library's saves in one action.
- **Save locations** — found automatically through the bundled Ludusavi and a
  built-in path database, so you rarely have to type a path by hand.

## Controls: mouse, keyboard, gamepad

The entire interface is reachable without a mouse. Keyboard and gamepad both
reduce to one set of actions (`NavAction`), so they behave identically.

| Action           | Keyboard              | Gamepad             |
|------------------|-----------------------|---------------------|
| Navigate         | arrows, Tab           | D-pad, left stick   |
| Select           | Enter / Space         | A                   |
| Back             | Escape                | B                   |
| Play / Download  | Cmd+Enter, Ctrl+Enter | X                   |
| Search           | `/`, Cmd+F            | Y                   |
| Switch sections  | Ctrl+Tab, Cmd+[ / ]   | LB / RB             |
| Scroll           | PageUp / PageDown     | right stick         |

The focused element is outlined, the list scrolls to keep it visible, and the
bottom bar shows hints — gamepad buttons when a controller is connected,
keys otherwise.

Controllers are read through the `gamepads` package, which normalises them to
the Xbox layout using the SDL database, so PlayStation, Xbox and
Switch-compatible pads work with no setup. You can still remap:
**Settings → Controls → Assign** waits for a button press and remembers it.
The same place turns the gamepad off entirely and tunes stick dead zones.

Holding a direction repeats the step (400 ms before the first repeat, then
every 110 ms), and the sticks use hysteresis: the release threshold sits below
the trigger threshold so the input does not chatter at the boundary.

## Proxy

**Settings → Proxy**: type (SOCKS5 or HTTP), host, port, username, password.
It applies on a button press — changing the proxy restarts active tasks,
because connections that are already open would otherwise keep bypassing it.

The difference between the two types is fundamental, and the UI says so:

- **SOCKS5** — peer traffic goes through the proxy too (`useForPeers: true`),
  so the torrent traffic is genuinely hidden;
- **HTTP** — covers trackers and plain downloads only; peer connections go
  out directly.

This is exactly why the engine is `dtorrent_task_v2` rather than aria2:
**aria2 has no SOCKS support at all**, and its HTTP proxy only covers tracker
requests in torrents.

The proxy password is stored in the settings file as plain text — the UI says
this out loud.

## Notifications

The rule is simple: **a SnackBar for what the user just did; a system
notification for what finished in the background.** A torrent runs for tens of
minutes and the window is usually minimised by then, so a toast inside an
invisible window helps nobody.

Three things arrive as system notifications:

- a download finished and the game is ready to launch;
- a download failed, with the reason;
- the automatic save snapshot after quitting a game **failed** — that snapshot
  is silent by design, and without the notification you would find out only
  after losing progress.

A failed download notifies once, on the transition into the failed state, not
on every engine poll (it is polled once a second).

Turn them off in **Settings → Notifications**, which also has a "Test" button
and, on macOS, "Request permission": the system asks once, and the app does it
on a button press rather than silently at first launch. Linux notifications go
through D-Bus, Windows through the system toast mechanism.

## Moving saves between machines

The core idea: a game's profile stores **not an absolute path** but a template
with a placeholder — `{APPSUPPORT}/MyGame/Saves`. On another machine, and on
another OS, the same template expands into the correct local path.

An `.evsave` file is an ordinary zip:

```
manifest.json          metadata: game, device, platform, path rules
data/<ruleId>/...      the save files themselves
```

On restore, rules are matched by identifier first and **then by label** — which
is why a snapshot taken on Windows lands in the macOS path of the same game,
as long as both rules carry the same label (say, "Saves").

Three ways to move them:

1. **By hand** — "Export file", copy the `.evsave` anywhere, then "Import" →
   "Restore" on the other machine.
2. **Through a sync folder** — point the settings at a Dropbox / iCloud /
   Syncthing folder. New snapshots land there automatically, and on the other
   machine they show up in the Saves tab with an "Apply" button (import and
   restore in one action).
3. **The whole library at once** — "Export all" writes a package per game into
   one folder; "Import all" reads that folder back, matching packages to games
   by title.

A restore always takes a backup of the current saves first.

**Bulk import will not silently overwrite newer progress.** It compares the
package's timestamp against the newest local save file, and skips games where
this machine is ahead — a package from another device can easily be the older
one, and a backup is thin comfort if you never learn it happened. A two-minute
tolerance keeps clock skew between machines from raising false alarms, and the
dialog lets you override the check deliberately.

## Finding save locations

Typing save paths by hand for every game is the tedium this feature removes.

**Ludusavi ships with the app**, so there is nothing extra to install. It knows
where games are installed and which store accounts exist, so it resolves paths
that a manifest alone cannot. If it is missing or cannot run, the app falls
back to the built-in path database, which covers fewer cases but needs nothing.

The bundled copy gets its own configuration directory, so it never rewrites the
settings of a Ludusavi you installed yourself. A copy you point at explicitly
keeps its own configuration, which may know about non-standard game folders.

The binary is not stored in this repository: it is downloaded at a pinned
version and verified against a checksum, and the build refuses to proceed
without one. License texts ship alongside it, as the MIT license requires.

One limitation worth stating: the macOS release of Ludusavi is **arm64 only**,
so on Intel Macs the bundled copy will not run and the built-in database takes
over. The app handles that quietly — a copy that cannot run is simply skipped.

## System integration

- **Launch at login** — a launchd job on macOS, an XDG entry on Linux, the
  current user's Run key on Windows. The system is the source of truth: if you
  remove the entry with system tools, the toggle follows.
- **Window geometry** — size and position come back the way you left them, with
  a separate option to always start maximised. A position from a monitor that
  no longer exists is discarded, since a window off the edge of the screen
  looks like an app that failed to start.
- **Update check** — the app asks GitHub whether a newer release exists and
  tells you. It never downloads or installs anything on its own: silent
  self-updates are a surprise nobody asked for, and on Linux the app may well
  live in a system directory it cannot write to.

## Requirements

- Flutter 3.47+ (verified on 3.47.2, Dart 3.13.2).
- No external programs needed: the download engine is built into the app.
- Building for Linux needs `libayatana-appindicator3-dev` — the tray icon
  will not compile without it.

Building for macOS needs **full Xcode** (not just the Command Line Tools) and
CocoaPods:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## Running

```bash
flutter run -d macos
```

Tests:

```bash
flutter test
```

Fetch the bundled Ludusavi before building a release:

```bash
python3 tool/fetch_ludusavi.py
```

Redraw the application icon:

```bash
python3 tool/make_icon.py
```

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) — five jobs:

| Job | Runner | What it does |
|-----|--------|--------------|
| Analyse and test | ubuntu | `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` |
| Build macOS | macos | the `.app`, with Ludusavi nested and re-signed, packed with `ditto` |
| Build Linux | ubuntu | a bundle with every dependency, packed as `.tar.gz` |
| Build Windows | windows | the Release directory, packed as `.zip` |
| Attach to release | ubuntu | uploads the archives to the release for a `v*` tag |

A push to `main` runs the analysis and the tests only. The three platform
builds run on a `v*` tag, and that is when the finished archives are attached
to the release. On a push they would establish what the tests already do, and
take four times as long doing it: the macOS build runs for minutes, while
“the tests passed” is wanted at once.

To check a build without cutting a release, run the workflow by hand
(`workflow_dispatch`) — the builds run there too. They still wait for the
tests to pass (`needs: analyze`).

Most tests need neither Xcode, nor the network, nor a gamepad: the engine is
created with `autoStart: false` and the queue is exercised without a single
connection, while controller events are fed straight past the plugin. Two
checks are the exception and run only where they can: the registry side of
launch-at-login runs on the Windows job, and the parsing of Ludusavi's real
output runs wherever the bundled binary matches the architecture.

The Flutter version is pinned in `env.FLUTTER_VERSION`. To always take the
latest stable, drop `flutter-version` and keep `channel: stable`.

The built `.app` is ad-hoc signed: it runs on your own machine, but Gatekeeper
will ask for "Open anyway" elsewhere. Proper signing needs an Apple Developer
certificate in the repository secrets.

## Code layout

```
lib/
  bloc/          SettingsBloc, LibraryBloc, DownloadsBloc, NavigationBloc
  core/          app paths, save path templates, JSON store, formatting
  input/         NavAction, gamepad binding, input service, InputScope
  models/        Game, AppSettings, SaveProfile, SaveSnapshot, DownloadTask
  services/
    download/    DownloadEngine (abstraction) + dtorrent: queue and proxy
    saves/       snapshot packing, Ludusavi manifest and CLI, path discovery
    launch/      running games, finding executables
    metadata/    release-name cleanup, Steam catalogue lookup
    system/      autostart, window geometry, update check
  ui/            shell, library, downloads, saves, settings
tool/            icon generation, fetching and bundling Ludusavi
```

## State: Bloc with events, plus provider

Four blocs — `SettingsBloc`, `LibraryBloc`, `DownloadsBloc`, `NavigationBloc`.
Each feature lives in its own folder (`bloc/<feature>/`) as three files —
events, state and handlers — tied together with `part`. States are immutable
(`Equatable`).

`flutter_bloc` is itself built on `provider`, so both packages are used for
what they are good at: `BlocProvider` hands out blocs, plain `Provider` hands
out stateless services such as `GamepadService`.

The event model is not ceremony here: external sources raise events on equal
footing with user input. The launcher reports a finished process through
`GameExited`; the download engine reports through `EngineTasksChanged`,
`EngineStatusChanged` and `EngineStatsChanged`. The handler decides what that
means and edits state in one place.

Asynchronous work never throws into widgets. A bloc keeps a set of in-flight
operation keys (`state.isBusy(...)`) and a one-shot `Notice`, and a single
`BlocListener` in the shell shows it as a SnackBar. That is why screens carry
no `bool _busy` and no `try/catch` around calls. `Notice` has a `seq` counter:
without it, two identical messages in a row would count as the same state and
the second would never appear.

An event returns nothing, and that changes a couple of places. The add-game
dialog generates the identifier itself and passes it into `GameAdded` so it
knows immediately which game to select. And before starting a download it waits
for the game to actually appear in state — otherwise two blocs could disagree
about the order things happened in.

## Appearance

There are two themes, light and dark, plus "follow the system", which is the
default. The dark one is unchanged from where the app started: it lives in a
full-screen window next to games.

The dark theme is built on the palette `FFFCF2 / CCC5B9 / 403D39 / 252422 /
EB5E28`, the light one on `264653 / 2A9D8F / E9C46A / F4A261 / E76F51`.

Contrast was not eyeballed: a test measures the ratio for every colour against
every surface and demands WCAG levels — 4.5 for captions and accents, 7 for
body text. That test is also what forced the departures from the source values
where text would otherwise be unreadable. The light palette contains no light
background at all, and three of its colours are fills rather than type: sandy
`E9C46A` scores 1.5 against a light background where 4.5 is required, a third
of the mark, so those three are darkened with their hue preserved. In the dark
theme the orange is lightened by four percent, because a status label is set in
it, not just a border. Everything else is used as given.

Colours come from a theme extension (`context.colors.textSecondary`) rather
than constants, because two schemes cannot both be constants. There is one
exception: the scrim over a game's cover art, where the backdrop is a picture
rather than the app background, so white text stays white in either theme.

Three fonts, all bundled rather than fetched at runtime: Nunito Sans for the
interface, Nunito for headings, JetBrains Mono for paths and sizes. They are
variable fonts, one file per family. The application icon is generated by
`tool/make_icon.py` rather than stored as an opaque binary — there is a macOS
variant with the margins that platform expects, and a Windows `.ico` with every
size inside.

Animations are short and few on purpose. The app is driven by a gamepad too,
where the user holds a direction and expects an immediate response, and any
transition there reads as lag. Sections cross-fade, progress bars glide toward
their new value, and selection highlights ease in — the detail panel
deliberately does not animate, because people flick through it quickly.

## License

Evaporate is distributed under the [MIT license](LICENSE). It ships with work
by others under their own terms — Ludusavi under MIT and three fonts under the
OFL; they are all listed in [NOTICE.md](NOTICE.md).

## Platform notes

- **macOS**: the sandbox is disabled in the `*.entitlements` files — with it on,
  the app can neither launch games nor reach other applications' save folders.
  A build like this is not meant for the App Store.
- `.evsave` packages arrive from elsewhere, so unpacking checks for paths that
  escape the destination folder (zip-slip). There is a test for it.
- File names are sanitised without stripping non-Latin letters. In Dart `\w`
  means Latin only, and cleaning by it turned every Cyrillic title into the same
  row of underscores — which made different games overwrite each other's
  exports until a test caught it.
