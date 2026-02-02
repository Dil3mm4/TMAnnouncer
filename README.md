# Trackmania Announcer

An OpenPlanet plugin that adds voice announcements during races in Trackmania 2020.

## Features

- **Crash Sounds** - Plays a voice line when you crash or lose significant speed
- **Checkpoint Sounds** - Announces checkpoints with split-time feedback (faster/slower than PB)
- **Lap Sounds** - Announces lap completions and final lap warnings
- **Medal Sounds** - Celebrates when you earn a medal (Bronze, Silver, Gold, Author)
- **Custom Sounds** - Load your own .wav files instead of built-in voice lines

## Installation

1. Install [OpenPlanet](https://openplanet.dev/) for Trackmania 2020
2. Install the [MLFeedRaceData](https://openplanet.dev/plugin/mlfeedracedata) dependency
3. Download and install Trackmania Announcer from the OpenPlanet plugin manager

## Settings

### General
- **Master Volume** - Main volume control (0-100%)
- **Scale with In-game Volume** - Sync with Trackmania's audio settings
- **Sound Gain Multiplier** - Fine-tune if sounds are too loud/quiet

### Features
- **Enable Crash Sounds** - Toggle crash announcements
- **Enable Checkpoint Sounds** - Toggle checkpoint announcements
- **Always Play on Every Checkpoint** - Play on every CP instead of random intervals
- **Enable Lap Sounds** - Toggle lap announcements
- **Enable Medal Sounds** - Toggle medal celebrations

### Advanced
- **Crash Sensitivity** - How much speed loss triggers a crash sound (0.1-1.0)
- **Debug Mode** - Print debug info to the OpenPlanet log

## Sound Packs

Sound packs are downloadable voice line collections that can be installed with one click.

### Downloading Packs

1. Go to **Settings → Sound Packs** tab
2. Paste a pack URL (JSON manifest) in the input field
3. Click **Download Pack**
4. Wait for the download to complete
5. Select the pack from the dropdown

### How It Works

- Packs are defined by a JSON manifest file hosted online
- The plugin downloads individual `.wav` files from URLs specified in the manifest
- Files are saved to `PluginStorage/TMTurboAnnouncer/CustomSounds/{PackName}/`
- Downloads are rate-limited (3 concurrent downloads) to avoid server issues
- If a server returns HTTP 429 (Too Many Requests), the plugin backs off with exponential delay

### Creating a Sound Pack

See [example_pack.json](example_pack.json) for the full specification. Basic structure:

```json
{
    "packName": "MyVoicePack",
    "author": "YourName",
    "sounds": {
        "carhit": {
            "crash1.wav": "https://example.com/crash1.wav",
            "crash2.wav": "https://example.com/crash2.wav"
        },
        "checkpoint": { ... },
        "checkpoint-yes": { ... },
        "checkpoint-no": { ... },
        "lap": { ... },
        "medal": { ... }
    }
}
```

**Categories:**
| Category | Description | Special Rules |
|----------|-------------|---------------|
| `carhit` | Crash/collision sounds | Random selection |
| `checkpoint` | Generic checkpoint | When no PB comparison available |
| `checkpoint-yes` | Faster than PB | Green time |
| `checkpoint-no` | Slower than PB | Red time |
| `lap` | Lap completion | `final` in filename = final lap |
| `medal` | Medal celebrations | Must contain `author`/`gold`/`silver`/`bronze` |

**Hosting Requirements:**
- Files must be direct download URLs (no redirects to auth pages)
- Server should support concurrent downloads
- HTTPS recommended

---

## Custom Sounds (Manual)

You can also manually add your own `.wav` files without using packs.

### Folder Location
```
OpenplanetNext/PluginStorage/TMTurboAnnouncer/CustomSounds/
```

### Folder Structure
```
CustomSounds/
├── carhit/           # Crash sounds (random selection)
│   ├── crash1.wav
│   └── ouch.wav
├── checkpoint/       # Generic checkpoint (no PB comparison)
│   └── nice.wav
├── checkpoint-yes/   # Faster than PB
│   ├── great.wav
│   └── faster.wav
├── checkpoint-no/    # Slower than PB
│   └── slow.wav
├── lap/              # Lap sounds
│   ├── lap.wav
│   └── final.wav     # 'final' in filename = final lap
└── medal/            # Medal sounds
    ├── author.wav    # 'author' in filename
    ├── gold.wav      # 'gold' in filename
    ├── silver.wav    # 'silver' in filename
    └── bronze.wav    # 'bronze' in filename
```

### Notes
- Only `.wav` files are supported
- If a folder is empty, no sound plays for that category
- Use the **Reload Custom Sounds** button in settings after adding new files

## Dependencies

- [MLFeedRaceData](https://openplanet.dev/plugin/mlfeedracedata) - For race and ghost data

## Credits

- Original plugin by **TheGeekid**
- Voice lines from Trackmania Turbo

## License

This plugin is provided as-is for personal use with Trackmania 2020.
