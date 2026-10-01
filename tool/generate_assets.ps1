<#
.SYNOPSIS
    Derives every store and launcher image asset for the Calculator app from one
    source image, Assets/Icon.png.

.DESCRIPTION
    Assets/Icon.png is the single source of truth for the app's mark - a 2x2 grid
    of operator keys (plus, minus, multiply, equals) with the left column in the
    gray and the right column in the orange - on a full-bleed black field.

    This script scales that one image to every size the Android platform and the
    Play Store want:

      * Assets/icon_source/icon_legacy_rounded.png, the legacy launcher source
        that flutter_launcher_icons downsamples into mipmap-*/ic_launcher.png;
      * store/play/icon-512.png, the 512x512 Play listing icon;
      * store/play/feature-graphic-1024x500.png, with the mark beside the
        wordmark;
      * the alpha-flattening pass over the store screenshots.

    The launcher icons themselves are NOT drawn here. That step belongs to
    flutter_launcher_icons, configured in pubspec.yaml, because a second
    generator writing into the same mipmap-* directories would mean two answers
    to "what is the launcher icon" - and the loser would be whichever ran last.
    Run this script first, then the command it prints at the end.

    Determinism is the reason the mark is scaled rather than redrawn. Scaling a
    fixed bitmap is a pure function of the size argument, and it is the only way
    the artwork the designer approved is the artwork that ships. The previous
    version of this script rebuilt the mark from circles and bars out of
    lib/core/design/app_colors.dart tokens; that coupled the icon to the
    in-app palette, so any colour-token edit silently became an icon change.

.PARAMETER ProjectRoot
    Repository root. Defaults to the parent of this script's directory.

.EXAMPLE
    powershell -NoProfile -ExecutionPolicy Bypass -File tool\generate_assets.ps1
#>
[CmdletBinding()]
param(
    [string] $ProjectRoot = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Resolved in the body rather than as a param default: Windows PowerShell 5.1
# does not bind $PSScriptRoot in time to evaluate a param default, and the
# fallback keeps the script runnable via -File, -Command, and dot-sourcing.
if (-not $ProjectRoot) {
    $here = $PSScriptRoot
    if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
    $ProjectRoot = Split-Path -Parent $here
}

# ---------------------------------------------------------------------------
# Source of truth
# ---------------------------------------------------------------------------

# Kept as a variable rather than sprinkled through the script so the "one source
# of truth" claim is a single line to change, and so the validation below can
# name the file it rejected.
$Script:SourceIconRelativePath = 'Assets\Icon.png'

# Corner radius for the legacy launcher bitmap, as a fraction of the icon's
# edge. This is the same 0.22 the geometry version used, so the pre-API-26 icon
# keeps the silhouette it had; only the artwork inside it changed.
#
# The rounding is needed at all because a launcher on API < 26 applies no mask
# of its own. Below API 26 the bitmap *is* the icon, so a full-bleed square
# source would be shown as a hard square. From API 26 the launcher draws its own
# mask and neither this file nor the adaptive foreground carries a corner.
$Script:LegacyCornerRadius = 0.22

# Supersampling factor, applied when scaling the source. Play shows the 512px
# listing icon at 48px, and a circle edge rasterised straight to that size
# visibly stair-steps, so the source is scaled up before it is scaled down.
#
# Taken as the larger of "target * SS" and the source's own width, so a small
# target never upsamples only to downsample again, and a large one still gets
# the supersampled path.
$Script:SS = 6

# The feature graphic's field. Black, not the keypad's #1E1E1E, and the reason
# is the new source: Icon.png is full-bleed black, so on a #1E1E1E field the
# 300px mark would read as a subtly darker square sitting on a lighter one. On
# black it has no edge at all. #000000 is also AppColors.background, which is
# what the store screenshots already are, so the whole listing now sits on one
# colour instead of two.
$Script:FeatureField = [System.Drawing.Color]::FromArgb(255, 0x00, 0x00, 0x00)

# Text colours for the feature graphic. AppColors.textSecondary is #B3B3B3 in
# the app's light theme; on this dark field that reads at low contrast next to a
# 76px wordmark, so the tagline gets the mid gray instead and stays clearly
# subordinate.
$Script:FeatureWordmark = [System.Drawing.Color]::FromArgb(255, 0xFF, 0xFF, 0xFF)
$Script:FeatureTagline  = [System.Drawing.Color]::FromArgb(255, 0xB3, 0xB3, 0xB3)

function New-RoundedRectPath {
    param([System.Drawing.RectangleF] $Rect, [float] $Radius)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $Radius * 2
    $path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    return $path
}

<#
    Loads Assets/Icon.png and refuses anything this script cannot scale without
    distorting or guessing.

    Square is the only hard requirement: every output is square, so a non-square
    source would have to be either cropped or letterboxed, and both are design
    decisions that belong to whoever supplied the artwork, not to this script.
    Resolution is not required to be a specific number - the outputs here are all
    at most 512px - but a source at or below 512 cannot produce the 512px store
    icon without upsampling, so it is worth saying rather than shipping blur.
#>
function Get-IconSource {
    $path = Join-Path $ProjectRoot $Script:SourceIconRelativePath
    if (-not (Test-Path $path)) {
        throw ("Icon source not found: {0}. The launcher icon, the store icon, and the " -f $path) +
              'feature graphic all derive from this one file.'
    }

    $src = [System.Drawing.Bitmap]::FromFile($path)
    if ($src.Width -ne $src.Height) {
        $w = $src.Width; $h = $src.Height
        $src.Dispose()
        throw ("Icon source must be square: {0} is {1}x{2}. Every output of this " -f $path, $w, $h) +
              'script is square, so a non-square source would have to be cropped.'
    }
    if ($src.Width -lt 512) {
        $w = $src.Width
        $src.Dispose()
        throw ("Icon source must be at least 512px on a side: {0} is {1}px. Play shows " -f $path, $w) +
              'the 512x512 listing icon at 48px, so upsampling here ships blur.'
    }
    return $src
}

<#
    Scales the source icon to $Pixels square.

    -Shape 'Full' returns it as-is. -Shape 'Rounded' clips it to a rounded
    square and leaves the corners transparent, which is what the pre-API-26
    launcher bitmaps need.

    Drawn large and resampled down rather than rasterised at the target size,
    for the circle-edge reason in $Script:SS. The intermediate is discarded
    before returning, so the caller only ever holds the final bitmap.
#>
function Convert-IconSource {
    param(
        [System.Drawing.Bitmap] $Source,
        [int] $Pixels,
        [ValidateSet('Rounded', 'Full')] $Shape = 'Full'
    )

    $big = [Math]::Max($Pixels * $Script:SS, $Source.Width)

    $bmp = New-Object System.Drawing.Bitmap($big, $big, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $G = [System.Drawing.Graphics]::FromImage($bmp)
    $G.Clear([System.Drawing.Color]::Transparent)
    $G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $G.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $G.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $G.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    if ($Shape -eq 'Rounded') {
        # SetClip rather than drawing the background then the art: the source is
        # opaque, so clipping is what leaves the corners transparent instead of
        # black.
        $clip = New-RoundedRectPath -Rect (New-Object System.Drawing.RectangleF(0, 0, $big, $big)) `
                                  -Radius ($big * $Script:LegacyCornerRadius)
        $G.SetClip($clip)
        $clip.Dispose()
    }

    $G.DrawImage($Source, 0, 0, $big, $big)
    $G.Dispose()

    $small = New-Object System.Drawing.Bitmap($Pixels, $Pixels, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $G2 = [System.Drawing.Graphics]::FromImage($small)
    $G2.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $G2.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $G2.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $G2.Clear([System.Drawing.Color]::Transparent)
    $G2.DrawImage($bmp, 0, 0, $Pixels, $Pixels)
    $G2.Dispose(); $bmp.Dispose()

    return $small
}

function Save-Png {
    param([System.Drawing.Bitmap] $Bmp, [string] $Path)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host ("  {0,-62} {1,7:N1} KB" -f $Path.Replace("$ProjectRoot\", ''), ((Get-Item $Path).Length / 1KB))
}

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
$storeDir      = Join-Path $ProjectRoot 'store\play'
$iconSourceDir = Join-Path $ProjectRoot 'Assets\icon_source'

Write-Host "Deriving store and launcher assets from $Script:SourceIconRelativePath" -ForegroundColor Cyan
Write-Host ""

$source = Get-IconSource
Write-Host ("  source is {0}x{1}" -f $source.Width, $source.Height)

# ---------------------------------------------------------------------------
# 1. Legacy launcher source
#
# Emitted once, at a size above every density, and downsampled from here by
# flutter_launcher_icons into mipmap-{mdpi..xxxhdpi}/ic_launcher.png. The
# pubspec config names this file as image_path_android, which is what makes the
# rounding reproducible rather than a one-off committed binary nobody can
# explain.
#
# 512 rather than 192 (the largest legacy density) so the five launcher sizes are
# all true downscales of a single raster.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Legacy launcher source (input to flutter_launcher_icons):"
$legacyPath = Join-Path $iconSourceDir 'icon_legacy_rounded.png'
$bmp = Convert-IconSource -Source $source -Pixels 512 -Shape 'Rounded'
Save-Png -Bmp $bmp -Path $legacyPath
$bmp.Dispose()

# ---------------------------------------------------------------------------
# 2. Play Store icon - 512x512, 32-bit PNG with alpha, <= 1024 KB
#
# Full square with no rounded corners and no shadow, because Play masks it
# itself at a 30% radius. A pre-rounded icon would be rounded twice, and the
# corners of the uploaded square would show as clipped.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Play Store listing assets:"
$bmp = Convert-IconSource -Source $source -Pixels 512 -Shape 'Full'
Save-Png -Bmp $bmp -Path (Join-Path $storeDir 'icon-512.png')
$bmp.Dispose()

# ---------------------------------------------------------------------------
# 3. Play feature graphic - 1024x500, no alpha
#
# Play shows this as the first image on the store listing, so it is the one asset
# that has to carry the app's name legibly. The mark sits on the left at roughly
# the size it occupies on a phone screen, with the wordmark and positioning line
# beside it. At 300px it is full-bleed black on a black field, so it reads as
# artwork floating on the background rather than as a pasted tile.
#
# Play rejects PNGs with an alpha channel here (it flattens them against an
# unpredictable background), so this one is written as a 24-bit RGB bitmap
# rather than the ARGB bitmaps used for the icons.
# ---------------------------------------------------------------------------

# Roboto is the app's typeface (see pubspec.yaml), and the Flutter SDK ships it
# in its cache. Loading it from there rather than by family name keeps the
# feature graphic's wordmark in the same face as the running app, and stops the
# script from silently falling back to Times New Roman on a machine where
# Roboto is not installed system-wide.
#
# Roboto-Medium is the weight AppTypography uses for display text, so the
# wordmark here matches the app's own headings.
function Get-RobotoFont {
    $sdk = (Get-Content (Join-Path $ProjectRoot 'android\local.properties') |
        Where-Object { $_ -like 'flutter.sdk=*' } |
        Select-Object -First 1) -replace '^flutter\.sdk=', '' -replace '\\\\', '\'
    if (-not $sdk) { throw 'flutter.sdk not found in android/local.properties' }

    # The cache uses lowercase filenames, but tolerate either spelling.
    $dir = Join-Path $sdk 'bin\cache\artifacts\material_fonts'
    $ttf = $null
    foreach ($name in @('Roboto-Medium.ttf', 'roboto-medium.ttf')) {
        if (Test-Path (Join-Path $dir $name)) { $ttf = Join-Path $dir $name; break }
    }
    if (-not $ttf) { throw "Roboto-Medium not found under $dir" }

    # PrivateFontCollection is the supported way to use a font file directly;
    # FontFamily has no constructor that accepts a path.
    $collection = New-Object System.Drawing.Text.PrivateFontCollection
    $collection.AddFontFile($ttf)
    return [pscustomobject]@{
        Collection = $collection
        Family     = $collection.Families[0]
    }
}

$w = 1024; $h = 500
$fg = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$G = [System.Drawing.Graphics]::FromImage($fg)
$G.Clear($Script:FeatureField)
$G.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$G.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# Left-hand mark. Square, not rounded: the field is the same black, so a rounded
# corner would reveal the field through it and make the mark look clipped.
$markSize = 300
$markBmp = Convert-IconSource -Source $source -Pixels $markSize -Shape 'Full'
$G.DrawImage($markBmp, 90, ($h - $markSize) / 2)
$markBmp.Dispose()

$font = Get-RobotoFont
$titleSize = New-Object System.Drawing.Font($font.Family, 76, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$subSize   = New-Object System.Drawing.Font($font.Family, 34, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

$text = 'Calculator'
$G.DrawString($text, $titleSize, (New-Object System.Drawing.SolidBrush $Script:FeatureWordmark), 440, 186)
$G.DrawString('Fast, offline, nothing leaves your phone', $subSize, (New-Object System.Drawing.SolidBrush $Script:FeatureTagline), 443, 282)

# Fail loudly rather than shipping a feature graphic with clipped text: Play
# renders this 1024px wide and the right-hand edge is hard.
$measured = $G.MeasureString($text, $titleSize)
if ((443 + $measured.Width) -gt 984) {
    throw ("Wordmark overruns the safe area by {0:N0}px (ends at {1:N0}, limit 984)" -f `
        (443 + $measured.Width - 984), (443 + $measured.Width))
}

$G.Dispose()
$titleSize.Dispose(); $subSize.Dispose()
$font.Collection.Dispose()
Save-Png -Bmp $fg -Path (Join-Path $storeDir 'feature-graphic-1024x500.png')
$fg.Dispose()

$source.Dispose()

# ---------------------------------------------------------------------------
# 4. Flatten store screenshots to 24-bit RGB
#
# Play rejects store screenshots that carry an alpha channel - it flattens them
# against an unpredictable background, and a PNG with transparency can render
# with a black or checkered matte. The golden files Flutter writes always have
# alpha, so every screenshot is re-saved here as 24-bit RGB.
#
# The flatten colour is the app's own screen background (#000000,
# AppColors.background), not an arbitrary matte: the screenshots are the dark
# theme, and the anti-aliased edges around text are blended with whatever was
# *transparent* underneath them. Flattening onto a colour the app never paints
# would leave a visible fringe around every glyph, so this is read from the
# screenshot's own corner rather than guessed. A mismatch here is loud, not
# subtle, which is the point - it fails the eye, not a checksum.
# ---------------------------------------------------------------------------
$screenshotDir = Join-Path $ProjectRoot 'store\play\screenshots'
if (Test-Path $screenshotDir) {
    $shots = @(Get-ChildItem $screenshotDir -Filter '*.png' | Sort-Object Name)
    if ($shots.Count -gt 0) {
        Write-Host ""
        Write-Host "Flattening store screenshots to 24-bit RGB:"
        foreach ($shot in $shots) {
            $src = [System.Drawing.Bitmap]::FromFile($shot.FullName)
            # Sample the bottom-left corner of the image itself as the matte, so
            # the flatten can never disagree with what the app painted there.
            $matte = $src.GetPixel(4, $src.Height - 4)
            $dst = New-Object System.Drawing.Bitmap($src.Width, $src.Height, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
            $G = [System.Drawing.Graphics]::FromImage($dst)
            $G.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
            $G.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $G.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $G.Clear($matte)
            $G.DrawImage($src, 0, 0, $src.Width, $src.Height)
            $G.Dispose()

            $tmp = [System.IO.Path]::Combine($shot.DirectoryName, 'flatten-tmp.png')
            $dst.Save($tmp, [System.Drawing.Imaging.ImageFormat]::Png)
            $dst.Dispose(); $src.Dispose()
            Move-Item -Force -LiteralPath $tmp -Destination $shot.FullName
            $kb = (Get-Item $shot.FullName).Length / 1KB
            Write-Host ('  {0,-46} {1,7:N1} KB' -f $shot.Name, $kb)
        }
    } else {
        Write-Host ''
        Write-Host 'No screenshots in store\play\screenshots - run the generator test first.' -ForegroundColor Yellow
    }
}

# ---------------------------------------------------------------------------
# 5. The launcher icons themselves
#
# Deliberately not generated above. flutter_launcher_icons owns every file under
# android/app/src/main/res/mipmap-* and drawable-* that makes up the launcher
# icon, so writing them here as well would mean two generators answering the
# same question, with whichever ran last winning - which is how a launcher icon
# silently goes stale.
#
# This script must run first: it produces the legacy source the generator reads.
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "Launcher icons are generated by flutter_launcher_icons, not by this script." -ForegroundColor Yellow
Write-Host "Run:" -ForegroundColor Yellow
Write-Host "  flutter pub get" -ForegroundColor Yellow
Write-Host "  dart run flutter_launcher_icons:generate" -ForegroundColor Yellow

Write-Host ""
Write-Host "All assets generated." -ForegroundColor Green
