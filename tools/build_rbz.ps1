param(
    # ru — русская сборка, en — английская, all — обе
    [ValidateSet('ru', 'en', 'all')][string]$Lang = 'all'
)

# Собирает distrchitools-<версия>-rus.rbz и -eng.rbz из src\ — как в RALNCS,
# area counter и PathCopy Advanced: языковой пакет — тот же исходник, в копии
# подменяется строка LANG в srcrchitools\lang.rb (Ruby) и
# srcrchitools\html\i18n.js (окна).
# Имя архива на идентичность расширения не влияет: SketchUp читает
# architools.rb из КОРНЯ архива, а версию — из constants.rb.
# Запуск:  powershell -ExecutionPolicy Bypass -File toolsuild_rbz.ps1 [-Lang en]

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression            # ZipArchive / ZipArchiveMode
Add-Type -AssemblyName System.IO.Compression.FileSystem # ZipFile / ZipFileExtensions

$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root 'src'
$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

# 1. Версия берётся из исходника, чтобы имя пакета не разъезжалось с кодом
$constants = Join-Path $src 'architools\constants.rb'
$match = Select-String -Path $constants -Pattern "VERSION\s*=\s*'([^']+)'" | Select-Object -First 1
if (-not $match) { throw "Не нашёл VERSION в $constants" }
$version = $match.Matches[0].Groups[1].Value

$suffix = @{ ru = 'rus'; en = 'eng' }
$langs  = if ($Lang -eq 'all') { @('ru', 'en') } else { @($Lang) }
$utf8   = New-Object System.Text.UTF8Encoding $false

# Записи добавляем поштучно: CreateFromDirectory в .NET Framework пишет пути
# через обратный слэш, а ZIP требует прямой — SketchUp такой архив разложит
# в один файл с именем "architools\tool.rb" вместо папки.
function Add-Tree($zipPath, $dir) {
    $archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $prefix = (Resolve-Path $dir).Path.TrimEnd('\') + '\'
        Get-ChildItem $dir -Recurse -File | Sort-Object FullName | ForEach-Object {
            $name = $_.FullName.Substring($prefix.Length).Replace('\', '/')
            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive, $_.FullName, $name, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    } finally {
        $archive.Dispose()
    }
}

foreach ($l in $langs) {
    $base  = 'architools-{0}-{1}' -f $version, $suffix[$l]
    $stage = Join-Path $env:TEMP ('architools_build_' + $l)
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    Copy-Item $src $stage -Recurse

    # 2. Язык: одна строка LANG в двух словарях
    foreach ($f in @('architools\lang.rb', 'architools\html\i18n.js')) {
        $p = Join-Path $stage $f
        $text = [System.IO.File]::ReadAllText($p, $utf8)
        $patched = $text -replace "LANG = '[a-z]{2}'", "LANG = '$l'"
        if ($patched -notmatch "LANG = '$l'") { throw "Не нашёл строку LANG в $f" }
        [System.IO.File]::WriteAllText($p, $patched, $utf8)
    }

    # 3. Пакет
    $rbz = Join-Path $dist "$base.rbz"
    Remove-Item $rbz -ErrorAction SilentlyContinue
    Add-Tree $rbz $stage
    Remove-Item $stage -Recurse -Force
    Write-Host "Собрано: $rbz"
}

Get-ChildItem $dist -File | ForEach-Object { Write-Host ("  {0,-44} {1,9} б" -f $_.Name, $_.Length) }
