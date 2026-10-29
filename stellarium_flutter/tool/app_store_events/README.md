# App Store In-App Events Sync

Creates Apple **in-app events** (the promotional cards on the App Store product
page) from `events.yaml`, generates the event card art with OpenAI
(`gpt-image-2`), uploads everything to App Store Connect, and submits each
event for review.

## Setup

```bash
cd tool/app_store_events
npm install
```

Required environment variables:

| Variable | What it is |
|---|---|
| `ASC_ISSUER_ID` | App Store Connect → Users and Access → Integrations → Issuer ID |
| `ASC_KEY_ID` | Key ID of an API key with **App Manager** (or Admin) role |
| `ASC_KEY_PATH` | Path to the downloaded `.p8` private key (keep outside git) |
| `ASC_APP_ID` | The app's numeric Apple ID (App Store Connect → App Information) |
| `OPENAI_API_KEY` | For event card image generation |
| `IMAGE_MODEL` | Optional, defaults to `gpt-image-2` |

## Usage

```bash
npm run dry-run                 # show what would be created, no API calls
node index.mjs                  # sync events due within the next 60 days
node index.mjs --only perseids-2026
node index.mjs --window-days 90
node index.mjs --skip-images    # create/submit without media (add art later)
```

Generated images are cached in `assets/` — delete a file to regenerate it.
Review the images before running the real sync (run once with `--dry-run`,
then generate images for one event with `--only <id>`).

## How it works

1. Loads `events.yaml`, keeps events whose `publishStart` is inside the window.
2. Lists existing events in ASC and skips any whose `referenceName` matches an
   event `id` (safe to re-run).
3. Per new event: creates the `appEvent`, generates 1920×1080 (card) and
   1080×1920 (details page) art via OpenAI + sharp cover-resize, creates the
   five `appEventLocalizations` (en/de/es/fr/zh-Hans), uploads the media per
   locale (reserve → chunked PUT → commit), then submits via a
   `reviewSubmission` with the event as its only item.

## Apple constraints

- ~10 approved events max at a time, 5 published on the product page at once.
- Events go through App Review — submit 1–2 weeks before `publishStart`.
- Badge/purpose values are fixed enums (see comments in `events.yaml`).
- **Verify astronomical dates** in `events.yaml` before submitting; the
  shipped entries are examples.
