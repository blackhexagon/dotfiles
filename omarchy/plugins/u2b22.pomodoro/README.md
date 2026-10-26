# Calendar Pomodoro

An Omarchy bar widget whose pomodoros are the timed events on one Google
calendar, selected by name (`Work` by default).

- **Bar:** during a block, a tomato and the time left (`24:12`, or `1:05:03`
  for blocks of an hour or longer). The block title is in the tooltip.
  Between blocks, a tomato and the next start time (`🍅 14:00`), not highlighted.
  After the last block, the tomato alone, dimmed. If a sync fails, a warning
  mark.
- **Click:** today's pomodoros. Finished ones are dimmed, and the current one
  shows the time left.
- **Break screen:** when a block ends and the next one starts exactly 5 or 15
  minutes later, a full-screen countdown covers every monitor until the next
  block. It shows the description of the block that just ended, which is a
  place for break instructions such as exercises, and the next block's title.
  Formatting from Google Calendar becomes plain text with line breaks and
  bullets. The only way to leave a break early is to type the skip phrase
  shown on the screen. Case and spaces don't matter, Backspace deletes, and
  Esc clears what you typed.

The countdown and the skip input stay on screen regardless of the description
length. Each numbered exercise or bullet has its own column. Long columns
scroll vertically, and extra columns scroll horizontally. Use the mouse wheel
or the scrollbars to read them. Descriptions without a list use one scrollable
column. The plugin keeps the full description instead of cutting it at 2000
characters.

All-day events are ignored. Overlapping blocks count down the one that started
last. Calendar data is fetched for today only: at shell start, every 5 minutes,
when a block ends, and when the list opens. Nothing is cached, so a failed sync
shows an error instead of an old day.

## Setup

1. Install from the dotfiles repo:

   ```bash
   ./scripts/install-pomodoro-plugin.sh
   ```

2. Click the widget and choose **Connect Google**. Sign-in happens in the
   browser with read-only calendar scopes. The refresh token is kept in the
   Secret Service keyring (`secret-tool`, service `u2b22-pomodoro`).

### OAuth client

By default the plugin borrows the desktop OAuth client that Calendar Agenda
publishes at `omarchy.alexinslc.com`, as Calendar Agenda does, and keeps a
private copy in `~/.local/state/u2b22-pomodoro/oauth-client.json`. That copy is
refreshed daily, and an older copy is used if the server is unreachable.

To stop depending on that server, create your own client in Google Cloud (an
OAuth client of type **Desktop app**, with the Google Calendar API enabled).
Save the downloaded JSON as `~/.config/omarchy/u2b22-pomodoro/oauth.json`,
`chmod 600` it, and choose **Connect Google** again, because a token belongs
to the client that issued it. When that file exists it always wins. See
`oauth.example.json` for the expected fields.

## Settings

On the widget's entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "u2b22.pomodoro", "calendar": "Work", "skipPhrase": "…" }
```

`calendar` is the calendar's display name. If no calendar has that name, or
more than one does, the widget shows an error. `skipPhrase` is optional and
replaces the default skip phrase.

## Shortcut and IPC

```bash
omarchy-shell shell toggle u2b22.pomodoro   # open or close today's list
omarchy-shell u2b22-pomodoro status         # JSON status
omarchy-shell u2b22-pomodoro sync           # sync now
omarchy-shell u2b22-pomodoro previewBreak   # show the break screen for a minute
omarchy-shell u2b22-pomodoro hideBreak      # hide the preview (not a real break)
```

`previewBreak` uses the most recently finished block's description, so you
can check how break instructions read before a real break.

## Files

```
manifest.json        plugin manifest (service + bar widget)
Service.qml          sync loop and day state; IPC target u2b22-pomodoro
BreakScreen.qml      bounded countdown, exercise columns and skip input
BarWidget.qml        bar label and today's list
DayModel.js          pure logic: current, next, break gaps, formatting
pomodoro_sync.py     Google sign-in and today's events as JSON (stdlib only)
oauth.example.json   shape of the private OAuth client file
tests/               offline tests for descriptions and screen layout
```

The source of truth is `omarchy/plugins/u2b22.pomodoro/` in the dotfiles repo.
The installed copy in `~/.config/omarchy/plugins/` is overwritten on every
install, so edit the repo copy.

## Tests

Run these tests from the plugin directory. They use Python, Node.js, Quickshell
and the installed Omarchy QML components. They do not connect to Google or open
windows on your desktop. The layout tests use long descriptions, multiple
screen sizes and long skip phrases.

```bash
python3 -m unittest discover -s tests -v
```
