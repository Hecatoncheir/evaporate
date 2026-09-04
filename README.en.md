# Evaporate

*[Русская версия](README.md)*

A desktop game launcher built with Flutter: a library, BitTorrent downloads,
and — the point of the whole thing — save files you can pick up as a single
file and carry to another machine.

The app ships **no content catalogue**. You provide the source for every game
yourself: a magnet link, a `.torrent` file, or a folder that is already on disk.

## What it does

- **Library** — a grid of portrait covers, the way Steam does it: the All,
  Installed and Not installed shelves, locally cached Steam cover art,
  states, time played, last launch date.
- **Find installed games** — choose a parent folder such as `Games` or
  `steamapps/common`, then select the discovered games to add. Folders
  already in the library are excluded.
- **Downloads** — magnet links and `.torrent` files through a pure-Dart client
  (`dtorrent_task_v2`): DHT, a reorderable queue, pause and resume, and
  **SOCKS5 all the way down to peer connections**. The queue survives a restart.
- **Drag and drop** — a game folder or a `.torrent` can be dropped straight
  into the library window: the folder is added as an installed game, the
  torrent goes into the download queue.
- **Launching** — finds the executable inside a downloaded folder, runs the
  `.app` on macOS, the `.exe` on Windows, the binary on Linux, and counts
  play time.
- **Saves** — `.evsave` snapshots, an automatic snapshot after you quit a game,
  restore with a safety backup, export and import, a sync folder, and moving
  the whole library's saves in one action.
- **Save locations** — found automatically from an open database of known
  paths, so you rarely have to type a path by hand.

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

Adding an installed game or completing a download starts a one-time Steam
lookup for its ID, description and cover file, followed by a Ludusavi lookup
using that ID. Results and attempt markers remain until the game is removed
from the library. Failed requests and missing matches are not retried on
restart. Use the Steam and database buttons in the game details to retry
manually; the database button refreshes the manifest explicitly.

Path patterns are retained even before the first launch. Wildcards are
expanded locally before snapshots and bulk exports, without network access.
Cover art is displayed from disk. When a Steam ID is known, Ludusavi does not
fall back to another game's similar title.

The source is the [Ludusavi manifest](https://github.com/mtkennerly/ludusavi-manifest):
an open database compiled from [PCGamingWiki](https://www.pcgamingwiki.com/wiki/Home).
Fifty-three thousand games, MIT licensed. It is downloaded on demand and kept
in the cache; nothing ships in the repository or in the builds.

The database writes paths with placeholders rather than ready-made. Two of them
are resolved on the spot:

- `<base>` — the game's own folder, **the most common placeholder in the
  database**. The launcher knows it exactly: it installed the game. It becomes
  `{GAME}` in the rule and expands to the local folder on any other machine.
- the "any profile" wildcard (`*`) is expanded against what is actually on
  disk, so the rule ends up holding concrete paths.

What stays unresolvable are the paths that go through a store account
(`<storeUserId>`) or another launcher's root (`<root>`). That is Steam cloud;
the games Evaporate installs do not have it.

### Watching the session

The database does not know every game: torrent releases, obscure titles and
anything outside Steam are simply not in it. But a game creates its own save
folder, and the app knows exactly when it was running — it started it.

After the game exits, Evaporate looks at what changed during that window in
the places games keep saves, and inside the game's own folder. What it finds
shows up under "Save folders" as an offer, not as a silent decision: games
write logs, shader caches and telemetry right next to their saves, and telling
them apart with certainty is not possible.

Several signals are weighed at once: a name resembling the game's title, being
inside the game folder, a known games location such as "My Games", file
extensions. Known caches and logs are dropped by name, and a folder that
gained hundreds of files during one session loses weight — that is a cache,
not a save. Sessions shorter than thirty seconds are not examined at all:
those are usually failed launches.

The database knows the Windows registry keys too. The app cannot transfer them,
but it does not keep quiet either: when a game keeps its saves in the registry,
it says so — otherwise the snapshot would come out incomplete without a word.

**Ludusavi** itself used to ship alongside — the binary that resolved `<base>`
by walking Steam and GOG folders. A launcher that installs the games has
nothing to guess, so the binary is gone, and with it the pinned checksums, the
subprocess, and the fact that the macOS release of Ludusavi is arm64 only.

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

Rebuild icon sizes from the saved source (on macOS, using `sips`):

```bash
python3 tool/make_icon.py
```

## CI

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) — five jobs:

| Job | Runner | What it does |
|-----|--------|--------------|
| Analyse and test | ubuntu | `dart format --set-exit-if-changed`, `flutter analyze`, `flutter test` |
| Build macOS | macos | the `.app`, packed with `ditto` |
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
connection, while controller events are fed straight past the plugin. One
check is the exception: the registry side of launch-at-login runs on the
Windows job and is skipped everywhere else.

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
    saves/       snapshot packing, the path database, path discovery
    launch/      running games, finding executables
    metadata/    release-name cleanup, Steam catalogue lookup
    system/      autostart, window geometry, update check
  ui/            shell, library, downloads, saves, settings
tool/            icon generation and helper scripts
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
EB5E28`. The light theme uses the icon's ivory paper and midnight indigo,
with flowing magenta, gold, turquoise and violet accents.

Contrast was not eyeballed: a test measures the ratio for every colour against
every surface and demands WCAG levels — 4.5 for captions and accents, 7 for
body text. That test is also what forced the departures from the source values
where text would otherwise be unreadable. Saturated icon colours belong to
the decorative layer; their text variants are darker. The dark theme uses a
lighter orange because it labels status as well as outlining focus.

The "Living library" setting enables magnetic particles and holographic foil
on the active card. A gentle perspective tilt repeats every 7 seconds,
synchronized with the rainbow reflection and specular streak.
The normal focus border stays; liquid distortion and the flowing backdrop
are removed. Gradients and Matrix4 implement the effect directly in Flutter,
without Dough, sensors, or additional foil/xl dependencies.
Particles follow the cursor and orbit card edges: proximity increases their
density, brightness and turbulence, never their radius. Distant dots wander
in `#2f0346` on light backgrounds or `#e6dbc7` on dark backgrounds, without glow.
Close to a target both themes use the same saturated ink palette.
The 1200 ambient dots remain visible when motion is disabled. The simulation
is capped at 3200 particles, painting independently of the grid.
Grid gaps are 36 pixels horizontally and 40 vertically.
Reduced motion leaves static foil without tilt; disabling effects removes
the foil entirely. Animations pause on hidden tabs or when the app is inactive.
Select the light theme in Settings if your system is dark; existing preferences
are not changed automatically.

In search, Down, Enter and Escape return to the selected game (or the first
filtered result); Left/Right still edit the query. Gamepad Down, A and B
return to the grid too, without clearing the query.
Cover size is adjustable from 75–150% using −/+ above the grid or in Settings.
The independent 85–125% interface scale enlarges text, icons, controls and
dialogs together, leaving the window controls unchanged. Both preferences
persist; clicking a percentage resets that scale to 100%.

Closer to the target, a stronger spring and radial damping pack particles
into a tight cursor cloud or perimeter band. Fast tangential turbulence
remains, with a speed limit of 360 pixels/s; point size and distant motion are unchanged.
The library and game pages share the same 26-line wave background based on
the [#wave reference](https://hecatoncheir.github.io/).
The gold/magenta Play button uses
[bokeh_lava_gradient](https://pub.dev/packages/bokeh_lava_gradient):
10 soft coloured blobs at 30 fps, with a contrast scrim under the label.
The lines bend smoothly near the pointer. Everything renders locally in
Flutter, without loading the website or rebuilding page content each frame.
Disabling Living library or enabling reduced motion leaves static artwork;
animations pause on hidden pages and while the window is inactive.

Colours come from a theme extension (`context.colors.textSecondary`) rather
than constants, because two schemes cannot both be constants. There is one
exception: the scrim over a game's cover art, where the backdrop is a picture
rather than the app background, so white text stays white in either theme.

Three fonts, all bundled rather than fetched at runtime: Nunito Sans for the
interface, Nunito for headings, JetBrains Mono for paths and sizes. They are
variable fonts, one file per family. The new imagegen-created icon uses cream
and midnight indigo with three vivid multicolor vapor ribbons forming the
Evaporate mark, offset-color outlines, and a textured print finish.
The artwork and prompts live in `docs/branding/`; `tool/make_icon.py` exports
macOS sizes, the Linux PNG, and multi-size Windows and tray ICO files.

The app draws its own title bar and window controls. Drag the title area to
move, double-click to maximize/restore, and drag an edge to resize. Corners
are rounded on macOS, requested from DWM on Windows 11, and drawn through
transparent pixels on Linux (requires a compositing window manager).
Windows 10 uses square corners, as do maximized and fullscreen windows.

Animations are short and few on purpose. The app is driven by a gamepad too,
where the user holds a direction and expects an immediate response, and any
transition there reads as lag. Sections cross-fade, progress bars glide toward
their new value, and selection highlights ease in — the detail panel
deliberately does not animate, because people flick through it quickly.

## Contributing

Bug reports, translation fixes and notes about clumsy wording are welcome —
[CONTRIBUTING.md](CONTRIBUTING.md) explains how it works.

## License

Evaporate is distributed under the [MIT license](LICENSE). It ships with work
by others under their own terms — the path database under MIT and three fonts under the
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
