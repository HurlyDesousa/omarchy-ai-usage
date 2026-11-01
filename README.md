# AI Usage

Shared SpaceXAI plan limits for Cursor, Grok Bot, and SuperGrok in one Omarchy bar panel: how much of the shared allowance you have used, when it resets, and a per-product breakdown.

![AI Usage panel with sample numbers](preview.png)

Plugin id: `io.github.hurlydesousa.ai-usage`

## Install

```sh
omarchy plugin add https://github.com/HurlyDesousa/omarchy-ai-usage.git --enable
```

Place it on the bar if needed:

```sh
omarchy bar move io.github.hurlydesousa.ai-usage --section right
```

## Usage

Click the `󰚩` icon to open the panel; Escape closes it. The refresh button fetches fresh numbers. While the panel is open it refreshes every five minutes, and opening it refreshes anything older than that.

The panel shows one **SpaceXAI** meter for the shared Cursor / Grok Bot / SuperGrok allowance, then a **Usage breakdown** with each product's reading. Sign-ins already on this machine are what feed the numbers.

| Source | Needs | Reads | Asks |
|---|---|---|---|
| Cursor | Cursor, signed in | Cursor's session token from its `state.vscdb` | Cursor's usage dashboard (`api2.cursor.sh`) |
| Grok Bot | Cursor, signed in | the same Cursor token | Cursor's usage dashboard, weekly Grok Bot allowance |
| SuperGrok | the grok CLI after `grok login` | `~/.grok/auth.json` and local grok session logs | grok's billing endpoints (`cli-chat-proxy.grok.com`, `grok.com`) |

Tokens only go to the service that issued them. Nothing is sent anywhere else.

## Renewing a lapsed grok sign-in (opt-in)

The grok CLI renews its saved sign-in only while it runs, so a panel that just watches usage can find it expired within hours and stop updating SuperGrok. When that happens the section says how old its numbers are and offers **Renew this sign-in automatically**.

Pressing it is your consent for AI Usage to renew that sign-in the way the app itself does (`auth.x.ai`) and to write the result back to `~/.grok/auth.json`. The file is replaced atomically and kept owner-only, and a newer sign-in the app saved in the meantime is never overwritten. Nothing is written before you press the button.

Turn renewal off again (or on, without the button):

```sh
~/.config/omarchy/plugins/io.github.hurlydesousa.ai-usage/omarchy-ai-usage consent grok off
```

## Settings

Optional keys on the widget's entry in `bar.layout` in `~/.config/omarchy/shell.json`:

| Key | Default | Effect |
|---|---|---|
| `showSpaceXai` | `true` | Hide the SpaceXAI section |
| `spaceXaiLabel` | your plan | Text to the right of the SpaceXAI title |
| `footerTitle`, `footerDetail`, `footerLabel` | none | A note row under the sections |

```json
{ "id": "io.github.hurlydesousa.ai-usage", "spaceXaiLabel": "Grok 4.6 · 1.5T" }
```

## Dependencies

- Python 3 (standard library only); the panel runs the bundled `omarchy-ai-usage` script
- Whichever of Cursor and the grok CLI you want to see

## Files it writes

- `~/.local/state/omarchy/agents/usage/cursor.json`, `grokbot.json`, and `grok.json`: usage snapshots
- `~/.local/state/omarchy/ai-usage/consent.json`: your renewal choices
- Only after you allow renewal: `~/.grok/auth.json`, as described above

## Remove

```sh
omarchy plugin remove io.github.hurlydesousa.ai-usage
```

That removes the plugin files. To drop its state as well:

```sh
rm -f ~/.local/state/omarchy/agents/usage/{cursor,grokbot,grok}.json
rm -rf ~/.local/state/omarchy/ai-usage
```

## License

MIT. See [LICENSE](LICENSE).
