# Compresses + crops the raw 1080x1080 Dreamina mp4s in assets/video/
# into web-ready mp4 + webm, generates poster JPGs in assets/img/.
#
# Stashes raw originals in assets/video/_raw/ on first run so re-runs work
# (re-runs pull from the stash, not from the already-compressed output).
#
# If you drop NEW raw videos in after a run, delete assets/video/_raw/ first
# so the stash gets refreshed.
#
# Run from anywhere:
#   powershell -ExecutionPolicy Bypass -File .\compress-videos.ps1
# Test mode (just generates first-frame JPGs in _crop-test/ to verify crop):
#   powershell -ExecutionPolicy Bypass -File .\compress-videos.ps1 -Test

param(
    [switch]$Test
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$videoDir = Join-Path $repoRoot "assets\video"
$imgDir   = Join-Path $repoRoot "assets\img"
$rawDir   = Join-Path $videoDir "_raw"
$testDir  = Join-Path $repoRoot "_crop-test"

$ffmpeg = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpeg) {
    Write-Host "ffmpeg not on PATH. Install: winget install Gyan.FFmpeg, then open a new terminal." -ForegroundColor Red
    exit 1
}

# Crops are expressed as a fraction of source height (works across 960/1080/1440 sources).
# Standard: drop ~4.6% top + ~4.6% bottom. 50/1080 keeps decorative halos/sparkles
# in frame; the Dreamina "Ai" badge stays out of the kept area at this crop too.
# Scan:     same fraction so the sparkle ring above Glo stays fully visible.
$standardTopFrac = 50 / 1080
$scanTopFrac     = 50 / 1080

$videos = @(
    # hero-loop is chromakey'd separately (see git history) — skipping in this batch script.
    @{name="scan-loop";     topFrac=$scanTopFrac},
    @{name="chat-loop";     topFrac=$standardTopFrac},
    @{name="progress-loop"; topFrac=$standardTopFrac},
    @{name="routine-loop";  topFrac=$standardTopFrac},
    @{name="splash";        topFrac=$standardTopFrac}   # compressed but not wired into index.html
)

function Get-CropForVideo($videoPath, $topFrac) {
    $height = & ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 $videoPath
    if (-not $height) { return $null }
    $h = [int]$height
    $top = [int][Math]::Round($h * $topFrac)
    $kept = $h - 2 * $top
    return @{ crop = "crop=iw:$kept" + ":0:$top"; sourceHeight = $h; topPx = $top; keptPx = $kept }
}

if ($Test) {
    New-Item -ItemType Directory -Force -Path $testDir | Out-Null
    Write-Host "TEST MODE - writing first-frame JPGs to $testDir`n" -ForegroundColor Yellow
    foreach ($item in $videos) {
        $name = $item.name
        $src = Join-Path $videoDir "$name.mp4"
        $rawCopy = Join-Path $rawDir "$name.mp4"
        $input = if (Test-Path $rawCopy) { $rawCopy } else { $src }
        if (-not (Test-Path $input)) {
            Write-Host "  skip $name (not found)" -ForegroundColor DarkYellow
            continue
        }
        $info = Get-CropForVideo $input $item.topFrac
        $outJpg = Join-Path $testDir "$name-test.jpg"
        Write-Host ("  {0,-15} src={1}px  crop top={2}px keep={3}px  ({4})" -f $name, $info.sourceHeight, $info.topPx, $info.keptPx, $info.crop) -ForegroundColor Cyan
        & ffmpeg -loglevel error -y -i $input -vf $info.crop -vframes 1 -q:v 2 $outJpg
    }
    Write-Host "`nOpen the JPGs in $testDir and verify watermark is gone + Glo is well-framed." -ForegroundColor Green
    exit 0
}

New-Item -ItemType Directory -Force -Path $rawDir | Out-Null

foreach ($item in $videos) {
    $name = $item.name
    $src = Join-Path $videoDir "$name.mp4"
    $rawCopy = Join-Path $rawDir "$name.mp4"

    if (-not (Test-Path $src) -and -not (Test-Path $rawCopy)) {
        Write-Host "skip $name (no source at $src or $rawCopy)" -ForegroundColor Yellow
        continue
    }

    # Stash the raw original on first run so subsequent runs use it (not the compressed output)
    if (-not (Test-Path $rawCopy)) {
        Copy-Item $src $rawCopy
    }
    $input = $rawCopy

    $info = Get-CropForVideo $input $item.topFrac
    $crop = $info.crop

    $outMp4    = Join-Path $videoDir "$name.mp4"
    $outWebm   = Join-Path $videoDir "$name.webm"
    $outPoster = Join-Path $imgDir   "$name-poster.jpg"
    $tmpMp4    = Join-Path $videoDir "$name.tmp.mp4"

    Write-Host ("[{0,-15}] src={1}px  top={2}px keep={3}px  {4}" -f $name, $info.sourceHeight, $info.topPx, $info.keptPx, $crop) -ForegroundColor Cyan

    # MP4 (H.264). Write to tmp first because ffmpeg cannot read and write the same path.
    & ffmpeg -loglevel error -y -i $input -vf $crop -vcodec libx264 -crf 28 -preset slow -movflags +faststart -an $tmpMp4
    if ($LASTEXITCODE -ne 0) { Write-Host "  mp4 FAILED" -ForegroundColor Red; continue }
    Move-Item -Force $tmpMp4 $outMp4

    # WebM (VP9)
    & ffmpeg -loglevel error -y -i $input -vf $crop -c:v libvpx-vp9 -crf 35 -b:v 0 -an $outWebm
    if ($LASTEXITCODE -ne 0) { Write-Host "  webm FAILED" -ForegroundColor Red; continue }

    # Poster JPG (first frame, high quality)
    & ffmpeg -loglevel error -y -i $input -vf $crop -vframes 1 -q:v 2 $outPoster
    if ($LASTEXITCODE -ne 0) { Write-Host "  poster FAILED" -ForegroundColor Red; continue }

    Write-Host "  done" -ForegroundColor Green
}

Write-Host "`nVideo dir:" -ForegroundColor Yellow
Get-ChildItem $videoDir -File | Sort-Object Name | Format-Table Name, @{Name="Size (KB)";Expression={[math]::Round($_.Length/1KB, 1)}}

Write-Host "Posters in img dir:" -ForegroundColor Yellow
Get-ChildItem $imgDir -Filter "*-poster.jpg" | Sort-Object Name | Format-Table Name, @{Name="Size (KB)";Expression={[math]::Round($_.Length/1KB, 1)}}

Write-Host "`nDone. Raw originals preserved in $rawDir (gitignored)." -ForegroundColor Green
