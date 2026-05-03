# gloskin-site

Marketing site for GloSkin — [gloskin.app](https://gloskin.app)

Static site, deployed via GitHub Pages. The `CNAME` file pins the custom domain.

The HTML pages (`index`, `privacy`, `terms`, `support`) are sourced from
`docs/landing-page/` in the [glowi-skincare-coach](https://github.com/dasuya0101/glowi-skincare-coach)
repo. If you update content there, copy the latest versions over.

## Structure

```
gloskin-site/
├── CNAME                ← gloskin.app
├── index.html           ← landing page (inline CSS)
├── privacy.html
├── terms.html
├── support.html
├── 404.html             ← fallback page
└── assets/
    ├── img/             ← Glo mascot cutouts + app-home screenshot (and posters)
    └── video/           ← .mp4/.webm loops (empty until videos arrive)
```

## Adding the videos

The landing page has placeholder media frames marked with `data-mp4-target="..."` for:
`scan`, `chat`, `progress`, `routine` (and a hero block). When the compressed
Seedance loops are ready, drop them into `assets/video/` and wire each
`<div class="media-frame" data-mp4-target="X">` to swap the placeholder for a
real `<video>` element. Each loop should ship as both `.mp4` and `.webm`,
and a `*-poster.jpg` (extracted via FFmpeg) should live in `assets/img/`.

Example wiring inside a `.media-frame`:

```html
<video class="media-video" autoplay muted loop playsinline preload="metadata"
       poster="assets/img/scan-loop-poster.jpg">
  <source src="assets/video/scan-loop.webm" type="video/webm" />
  <source src="assets/video/scan-loop.mp4"  type="video/mp4"  />
</video>
```

Generate posters from videos:

```
ffmpeg -i assets/video/scan-loop.mp4 -vframes 1 -q:v 3 assets/img/scan-loop-poster.jpg
```

## Local preview

Any static server works:

```
python -m http.server 8000
# or
npx serve .
```

Then open http://localhost:8000.
