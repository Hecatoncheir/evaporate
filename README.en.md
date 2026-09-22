<a href="https://hecatoncheir.github.io/evaporate/"><img src="site/assets/app-icon.png" alt="Evaporate — the project website" width="112" height="112" /></a>

# Evaporate

*[Русская версия](README.md)*

A desktop game launcher built with Flutter: a library, BitTorrent downloads,
and — the point of the whole thing — save files you can pick up as a single
file and carry to another machine.

The app ships **no content catalogue**. You provide the source for every game
yourself: a magnet link, a `.torrent` file, or a folder that is already on disk.

## What it looks like

![Library: a large cover on top, shelves, and a grid of portrait covers](site/assets/screenshots/library.jpg)

**Library.** On top, the game you are coming back to: a large still, the play
key, and time played. Below it the All / Installed / Not installed shelves and
a grid of portrait covers. The colour in the window comes from the games
themselves — the ambient light takes its hue from the selected one.

![Game page: the cover as a dimmed backdrop, the Steam rating, launch buttons, and save folders](site/assets/screenshots/game.jpg)

**Game page.** The cover runs under the header as a blurred backdrop and fades
out by the middle of the screen, so the page answers whose it is before you
finish reading the title. Under the description sits the rating: Steam's verdict
in words, the share of positive reviews, both counts, and Metacritic. Play on
the left; Add to Steam and Refresh from Steam on the right. Below, the save folders — paths are shown as templates
(`{HOME}/...`), because that is how they are stored, and that is why they
travel to another machine.

![Downloads: speed readouts, the queue, and a chart for each task](site/assets/screenshots/downloads.jpg)

**Downloads.** The section opens with readouts: speed, upload, how many are
running, how many are waiting. Every task gets its own chart — the network as a
line, the disk as bars. On the left, the "Ready to download" queue; anything
unwanted goes with the cross, and a `.torrent` can be dropped straight into the
window.

![Saves: readouts, whole-library transfer, and the snapshot list](site/assets/screenshots/saves.jpg)

**Saves.** How many snapshots, how much space, when the last one was taken.
Next to that, moving the whole library in one action and the sync folder. Each
snapshot shows which machine it came from.

![Settings: interface scale and the gamepad layout](site/assets/screenshots/settings.jpg)

**Settings.** Interface scale, and cover scale separately. Below, the gamepad:
stick dead zone and rebinding any button by pressing it.

![Light scheme: the same library on a pale chassis](site/assets/screenshots/library-light.jpg)

**Light scheme.** Not a brightened dark theme but a look of its own: flat
saturated colour without gradients, and black lettering on orange.

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
  A downloaded torrent can be saved back out as a `.torrent` file — including
  one that arrived as a magnet link, assembled from the metadata it fetched.
  Each task's progress is shown as a chart: the network as a line, the disk as
  bars. The "Ready to download" queue is editable in place, and deleting asks
  separately whether the downloaded files should go with it.
- **Drag and drop** — a game folder or a `.torrent` can be dropped straight
  into the window: the folder is added as an installed game, the torrent goes
  into the download queue. Both sections accept a drop, Library and Downloads —
  whichever is on screen.
- **Launching** — finds the executable inside a downloaded folder, runs the
  `.app` on macOS, the `.exe` on Windows, the binary on Linux, and counts
  play time.
- **Steam shortcut** — Add to Steam puts the game into Steam's non-Steam
  shortcut list together with its artwork: portrait, landscape, hero and logo.
  From there it launches from Steam itself, from Big Picture, and from a TV
  over Steam Link. Steam has to be closed for this: it rewrites its own
  shortcut list on exit and would wipe what was added.
- **Rating** — a game's page shows how it was received: Steam's verdict in
  words, the share of positive reviews, both counts, and the Metacritic press
  score where the game has one.
- **Saves** — `.evsave` snapshots, an automatic snapshot after you quit a game,
  restore with a safety backup, export and import, a sync folder, and moving
  the whole library's saves in one action.
- **Save locations** — found automatically from an open database of known
  paths, so you rarely have to type a path by hand.

## Installing

Ready-made builds live on the [releases page][releases]. Nothing needs
building; each system has its own file:

| System | File | What to do |
|--------|------|------------|
| Windows | `evaporate-<version>-windows-setup.exe` | run it: Next, Next, Finish |
| macOS | `evaporate-<version>-macos.dmg` | open it and drag Evaporate into Applications |
| Debian, Ubuntu | `evaporate-<version>-linux-amd64.deb` | double-click, or `sudo apt install ./file.deb` |
| Other Linux | `evaporate-<version>-linux-x86_64.run` | `chmod +x file.run && ./file.run` |
| Linux, by hand | `evaporate-<version>-linux-x64.tar.gz` | unpack anywhere (it holds an `evaporate` folder) and run `evaporate/evaporate` |

The app uses the `-macos.zip` archive for an in-place macOS update. On Windows
it downloads and runs `-windows-setup.exe` instead; `-windows.zip` remains for
manual installation and diagnostics.

Neither the Windows installer nor the macOS bundle is signed — certificates
cost money. So the first run brings up SmartScreen ("Windows protected your
PC" → More info → Run anyway) and, on macOS, Gatekeeper: open the app from
its context menu once.

The `.run` is a plain self-extracting installer: it puts the app in
`~/.local/share/evaporate`, adds a menu entry and an `evaporate` command, and
never asks for root. Remove it with `evaporate-uninstall`; settings, library
and save snapshots stay. It also takes `--prefix DIR` and `--extract DIR` if
installing is not what you want.

The app can update itself: a button in the settings downloads the new
version, checks its checksum and replaces the installation. The `.deb` is the
deliberate exception — it lands in `/opt`, which needs root to write, and
what a package manager installed a package manager should update. A `.run`
install lives in the user's own directory, where updating works.

[releases]: https://github.com/Hecatoncheir/evaporate/releases/latest

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

In search, Down, Enter and Escape return focus to the selected game (or to the
first filtered result), while Left and Right keep editing the query; on a
gamepad, Down, A and B do the same. The query is not cleared: you searched in
order to get somewhere, not to start over.

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
  tells you. Download and installation start only after a user click. If a
  Linux copy lives in a system directory, the app tells you to update it the
  same way it was installed.

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

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) — six jobs:

| Job | Runner | What it does |
|-----|--------|--------------|
| Format and analyse | ubuntu | `dart format`, `flutter analyze`, `bloc lint`, the plugin registrant check, the `CHANGELOG` section on a tag |
| Tests | ubuntu, macOS, Windows | `flutter test` in random order; on ubuntu with coverage and its threshold |
| Build macOS | macos | the `.app`: a `ditto` archive and a `.dmg` image |
| Build Linux | ubuntu | a bundle with every dependency: a `.tar.gz`, a `.deb` and a `.run` |
| Build Windows | windows | the Release directory: a `.zip` and an Inno Setup installer |
| Attach to release | ubuntu | uploads the files and `SHA256SUMS` for a `v*` tag |

An update started by the user looks for `-macos.zip`, `-linux-x64.tar.gz`, or
`-windows-setup.exe` in the release. On macOS and Linux, a detached helper
swaps the installation directory. On Windows, the app starts Inno Setup itself
as a detached process; after the silent installation, the installer relaunches
Evaporate. [`release_artifacts_test.dart`](test/tool/release_artifacts_test.dart)
keeps the names from drifting apart. The packaging recipes sit next to the
platform code: [`windows/installer.iss`](windows/installer.iss),
[`tool/package_macos.sh`](tool/package_macos.sh),
[`tool/package_linux.sh`](tool/package_linux.sh),
[`tool/package_run.sh`](tool/package_run.sh) — all of them run by hand too.

A push to `main` runs the analysis and the tests only. The three platform
builds run on a `v*` tag, and that is when the finished files are attached
to the release — and once a week on a schedule: the tests compile neither the
plugin runners nor the installer, so a broken build would otherwise surface on
release day. On a push they would establish what the tests already do, and
take four times as long doing it: the macOS build runs for minutes, while
“the tests passed” is wanted at once.

To check a build without cutting a release, run the workflow by hand
(`workflow_dispatch`) — the builds run there too. They still wait for the
analysis and the tests to pass (`needs: [analyze, test]`). Everything the
analysis and test jobs check on every change runs locally as
`dart tool/gate.dart`.

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
operation keys (`state.isBusy(...)`) and a one-shot `Notice`, and only the
shell shows it as a SnackBar, with one listener per bloc that has messages. That is why screens carry
no `bool _busy` and no `try/catch` around calls. `Notice` has a `seq` counter:
without it, two identical messages in a row would count as the same state and
the second would never appear.

An event returns nothing, and that changes a couple of places. `AddGameBloc`
generates the identifier itself and passes it into `GameAdded` so it
knows immediately which game to select. And before starting a download it waits
for the game to actually appear in state — otherwise two blocs could disagree
about the order things happened in.

## Appearance

There are two schemes, and they are **two looks of their own**, not one palette
with the brightness inverted. The night one is the inky chassis of a cinema:
warm gold on the primary action, cold signal blue on the readouts. The day one
is the pale chassis of a measuring instrument: flat saturated colour without
gradients, black lettering on orange, and a key sitting on its own dark edge. A
brightened copy of the night scheme would look washed out, and the reverse would
too. Pick one in Settings — dark, light, or "follow the system", which is the
default.

Contrast was not eyeballed: `test/ui/theme/theme_test.dart` measures the ratio for every
colour against every surface and demands WCAG levels — 4.5 for captions, 7 for
body text. That test is also what forced the departures from the source values
where text would otherwise be unreadable.

**The brand colour is split into two roles, and they must not be confused.**
`primary` is for text and icons, and it is contrast-checked on every surface;
`primaryFill` is for fills, and you write `onPrimary` on it. The split was paid
for by the light scheme: saturated orange is good as a block under a label and
falls short of the threshold as text on a pale background, so a single token for
both roles would mean either dull buttons or unreadable captions. `accent` and
`accentFill` are separated the same way. Three more tokens describe **material**
rather than meaning: `glow` (the halo — transparent by day, since a pale chassis
does not glow), `depth` (the edge under a key — transparent at night) and
`shadow`.

Colours are handed out by a theme extension (`context.colors.textSecondary`)
rather than as constants: the two schemes could not otherwise coexist. All of
them are defined in `lib/ui/theme/` — the schemes in `palette.dart`, the decoration and game colours in `decor_colors.dart` — and a test rejects new colour
literals elsewhere in the application. The geometry of the chassis is three radii
in `EvaporateTheme`, shared by both schemes: different corners would read as two
different applications, and numbers are never written into
`BorderRadius.circular(…)` on the spot. Motion is tokens too
(`EvaporateMotion`): four duration steps and the curves that go with them, and
that is also where the system's request not to animate is honoured — checking it
in every widget would mean forgetting it somewhere.

Three fonts, all bundled rather than fetched at runtime: **Unbounded** for
headings and primary keys (wide and geometric — it sounds like lettering on a
chassis), **Golos Text** for body text and captions, **JetBrains Mono** for
paths, sizes and readouts. All three were drawn with Cyrillic from the start;
they are variable fonts, one file per family. Headings are set in capitals with
**positive** tracking: Unbounded's capitals crowd each other, and the negative
tracking that suits narrow faces ruins the very thing the font was chosen for.
Section labels are capitals only to the eye — a screen reader gets the ordinary
word, because some readers spell capitals out letter by letter.

**Sections open with readouts, not with details.** One panel divided into a few
columns by hairlines: on Saves, how many snapshots, how much space, when the
last one was taken; on Downloads, speed, upload, how many are running, how many
are waiting. This is not decoration: the same numbers used to be scattered
across the corners of cards, and the screen did not answer the section's main
question. They are set in monospace with tabular figures, or the line would
twitch on every update, and a dimmed column means there is nothing to show.

**The colour in the shell comes from the games, not from the chassis.** Three
large gradients in the selected game's colours wash the window, and the panel
over them is deliberately not opaque — a solid fill would snuff out the only
colour in the window. The hue comes from the title, not from the cover's pixels:
reading the image would mean decoding it on every move through the shelf, and
the light is blurred to a smudge anyway. And the hues are not the whole wheel
but six vetted anchors: a free hue from a hash sooner or later produces swamp
green, and the shell stops looking personal and starts looking broken.

On a game's page the cover itself does the same job: blurred, dimmed, fading out
by the middle of the screen. Three layers, each of them needed — the blur so
that no detail under the text invites reading, the dimming so white text over a
pale cover stays text, and the fade so the backdrop has an ending rather than a
cut edge. It is the same file already shown on the page: Flutter keeps its
decoded form in cache, so showing it twice costs nothing.

Decorations are **not one switch but a flag each**: sparks, waves, foil on the
cover, card tilt, particles, droplets, the selection frame, ambient light, the
sweep of light across the large cover, the cover backdrop on a game's page. They
differ in cost and in taste, and a single switch would mean all or nothing. The
old shared flag is still read, for profiles already written to disk.

There are two scales and they are independent: the whole interface at 85–125%,
library tiles at 75–150%. The interface one does not merely turn a text scale
factor: the layout is computed at the enlarged logical size and then scaled as a
whole — otherwise icons, hit areas and dialogs given in pixels would not grow
along with the text. The window controls stay outside it: they belong to the
system. Clicking the percentage returns that scale to 100%.

The library's large cover does not hide wherever there is simply less room:
below 760 logical pixels of height it is drawn as a strip — title on one line,
keys to the right — and it is removed only below 520, where there would
otherwise be no room for the shelf itself. Wide screens are capped in width and
centred: past that the description line stops reading, a task card turns into a
bar, and the speed chart into wallpaper.

The app draws its own title bar and window controls. Drag the title area to
move, double-click to maximize or restore, and drag an edge to resize. Corners
are rounded on macOS, requested from DWM on Windows 11, and drawn through
transparent pixels on Linux (requires a compositing window manager). Windows 10
uses square corners, as do maximized and fullscreen windows.

Animations are short and few on purpose. The app is driven by a gamepad too,
where the user holds a direction and expects an immediate response, and any
transition there reads as lag. One clock drives every decorative frame, and it
stops itself on the system's reduce-motion request, on a minimized window, on a
disabled `TickerMode` and on an inactive route: decoration has no business
burning battery behind your back.

The icon is drawn in vector rather than begged from an image generator: an "E"
monogram whose top bar loses its substance — the blocks get shorter, lower and
further apart, with sparks trailing after them. The app's name said by the
letter itself. It is filled with a liquid rainbow running from yellow through
pink to a cold blue: the one place where the app departs from its own palette,
because an icon is allowed to be louder than the interface.

There are two source drawings, and that is a necessity rather than a
convenience. Large sizes take the one with the glow and the sparks; small ones
take the drawing with no effects at all, a shorter gradient and the farthest
block removed — the halo lights up the plate and at 16 px it blurs the outline
by exactly the width the letter is drawn with. Both live in `docs/branding/`
next to the write-up ([brand.md](docs/branding/brand.md)), and
`tool/make_icon.py` renders every size from them anew: macOS sizes, the Linux
PNG, and multi-size Windows and tray ICO files. A headless browser does the
rendering, so packaging works on all three systems instead of macOS only, as it
did with `sips`.

Screenshots for this file and for the website are taken by
[`tool/capture_window.ps1`](tool/capture_window.ps1): it captures the window
rather than the screen, and **refuses to run** if it could not bring that window
to the front — otherwise someone else's window would silently land in the frame,
and you would only catch the swap by looking.

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
