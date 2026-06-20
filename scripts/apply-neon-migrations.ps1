# Neon ga supabase/migrations SQL larni ketma-ket ishga tushirish.
# Talab: scripts/neon.env (DATABASE_URL)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $PSScriptRoot "neon.env"
$preflight = Join-Path $PSScriptRoot "neon-preflight.sql"
$migrationsDir = Join-Path $root "supabase\migrations"

if (-not (Test-Path $envFile)) {
    Write-Host "scripts/neon.env topilmadi." -ForegroundColor Red
    exit 1
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)\s*=\s*(.+)\s*$') {
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
}

$dbUrl = $env:DATABASE_URL
if ([string]::IsNullOrWhiteSpace($dbUrl)) {
    Write-Host "neon.env ichida DATABASE_URL yo'q." -ForegroundColor Red
    exit 1
}

$pgDumpDir = Join-Path $PSScriptRoot "tools\pgextract\pgsql\bin"
$psql = Join-Path $pgDumpDir "psql.exe"
if (-not (Test-Path $psql)) {
    $psqlCmd = Get-Command psql -ErrorAction SilentlyContinue
    if ($psqlCmd) { $psql = $psqlCmd.Source } else {
        Write-Host "psql topilmadi. PostgreSQL client o'rnating yoki scripts/tools/pgextract qo'shing." -ForegroundColor Red
        exit 1
    }
}

function Invoke-PsqlFile([string]$path, [string]$label) {
    Write-Host ">> $label" -ForegroundColor Cyan
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & $psql -d $dbUrl -v ON_ERROR_STOP=1 -f $path 2>&1 | ForEach-Object { Write-Host $_ }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    if ($code -ne 0) {
        Write-Host "Xato: $label (exit $code)" -ForegroundColor Red
        exit $code
    }
}

if (-not (Test-Path $preflight)) {
    Write-Host "neon-preflight.sql topilmadi: $preflight" -ForegroundColor Red
    exit 1
}

Invoke-PsqlFile $preflight "neon-preflight.sql (rollar, storage stub)"

$files = Get-ChildItem $migrationsDir -Filter "*.sql" | Sort-Object Name
if ($files.Count -eq 0) {
    Write-Host "Migration fayllar topilmadi: $migrationsDir" -ForegroundColor Red
    exit 1
}

foreach ($file in $files) {
    Invoke-PsqlFile $file.FullName $file.Name
}

Write-Host ""
Write-Host "Barcha migrationlar muvaffaqiyatli." -ForegroundColor Green
