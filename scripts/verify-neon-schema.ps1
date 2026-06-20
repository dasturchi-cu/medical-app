# Neon schema: kod vs bazani chuqur tekshiruv.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$backendApp = Join-Path $root "backend\fastapi\app"
$envFile = Join-Path $PSScriptRoot "neon.env"

if (-not (Test-Path $envFile)) {
    Write-Host "scripts/neon.env topilmadi." -ForegroundColor Red
    exit 1
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)\s*=\s*(.+)\s*$') {
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
}

$pgDumpDir = Join-Path $PSScriptRoot "tools\pgextract\pgsql\bin"
$psql = Join-Path $pgDumpDir "psql.exe"
if (-not (Test-Path $psql)) {
    $psql = (Get-Command psql -ErrorAction SilentlyContinue).Source
}
if (-not $psql) {
    Write-Host "psql topilmadi." -ForegroundColor Red
    exit 1
}

function Invoke-PsqlScalar([string]$sql) {
    $out = & $psql -d $env:DATABASE_URL -t -A -c $sql 2>&1
    if ($LASTEXITCODE -ne 0) { throw $out }
    return ($out | Out-String).Trim()
}

# Backend kodidan jadvallar (avtomatik).
$codeTables = @()
if (Test-Path $backendApp) {
    $codeTables = Get-ChildItem -Path $backendApp -Recurse -Filter "*.py" |
        Select-String -Pattern '\.table\("([^"]+)"\)' -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
}

# Flutter realtime jadvallari.
$flutterTables = @()
$libDir = Join-Path $root "lib"
if (Test-Path $libDir) {
    $flutterTables = Get-ChildItem -Path $libDir -Recurse -Filter "*.dart" |
        Select-String -Pattern "table:\s*'([^']+)'" -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
}

$requiredTables = ($codeTables + $flutterTables) | Sort-Object -Unique

$existing = Invoke-PsqlScalar "SELECT string_agg(tablename, ',' ORDER BY tablename) FROM pg_tables WHERE schemaname='public'"
$existingSet = [System.Collections.Generic.HashSet[string]]::new()
foreach ($t in ($existing -split ',')) {
    if ($t) { [void]$existingSet.Add($t.Trim()) }
}

$missingTables = @($requiredTables | Where-Object { -not $existingSet.Contains($_) })

# Muhim ustunlar (backend insert/select).
$requiredColumns = @{
    "courses"                  = @("instructor_name", "cover_image_url", "description_uz", "views", "sales", "image_url")
    "book_items"               = @("price_uzs", "purchase_contact_url", "author", "category_id", "cover_image_url")
    "course_banners"           = @("sort_order", "course_id", "image_url")
    "users"                    = @("login_count", "app_open_count", "phone", "full_name")
    "notifications"            = @("type", "route", "data")
    "book_categories"          = @("name", "slug")
    "user_book_entitlements"   = @("user_id", "book_id", "is_active")
    "pomodoro_sessions"        = @("user_id", "focus_minutes", "actual_focus_seconds", "completed_at", "status")
    "pomodoro_session_events"  = @("session_id", "user_id", "event_type", "meta")
    "rank_daily_lesson_watch"  = @("user_id", "lesson_id", "local_date", "watched_seconds")
    "rank_daily_watch"         = @("user_id", "local_date", "watched_seconds")
    "lesson_assets"            = @("preview_image_url", "file_url", "lesson_id")
    "video_progress"           = @("watched_sec", "completed", "updated_at")
    "user_devices"             = @("fcm_token", "device_id")
    "user_entitlements"        = @("source", "granted_by", "is_active")
    "app_comments"             = @("parent_id", "replies_count", "course_key")
    "app_ratings"              = @("content_key", "stars")
}

$missingCols = @()
foreach ($entry in $requiredColumns.GetEnumerator()) {
    $table = $entry.Key
    if (-not $existingSet.Contains($table)) { continue }
    foreach ($col in $entry.Value) {
        $hit = Invoke-PsqlScalar @"
SELECT count(*)::text FROM information_schema.columns
WHERE table_schema='public' AND table_name='$table' AND column_name='$col';
"@
        if ($hit -ne "1") { $missingCols += "${table}.${col}" }
    }
}

# Storage stub.
$storageOk = $true
$storageIssues = @()
try {
    $bucketCount = Invoke-PsqlScalar "SELECT count(*)::text FROM storage.buckets"
    if ([int]$bucketCount -lt 1) { $storageIssues += "storage.buckets bo'sh" }
    $contentAssets = Invoke-PsqlScalar "SELECT count(*)::text FROM storage.buckets WHERE id='content-assets'"
    if ($contentAssets -ne "1") { $storageIssues += "content-assets bucket yo'q" }
} catch {
    $storageOk = $false
    $storageIssues += "storage schema yo'q yoki ulanish xatosi"
}

# RPC (ixtiyoriy — Python fallback bor).
$optionalRpc = @("get_daily_ranking", "get_overall_ranking", "get_pomodoro_ranking")
$missingRpc = @()
foreach ($fn in $optionalRpc) {
    $hit = Invoke-PsqlScalar "SELECT count(*)::text FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND p.proname='$fn'"
    if ($hit -ne "1") { $missingRpc += $fn }
}

# Natija.
Write-Host ""
Write-Host "=== Neon chuqur tekshiruvi ===" -ForegroundColor Cyan
Write-Host "Kod jadvallari: $($requiredTables.Count) | Bazada: $($existingSet.Count)"

if ($missingTables.Count -eq 0) {
    Write-Host "Yetishmayotgan jadval: yo'q" -ForegroundColor Green
} else {
    Write-Host "Yetishmayotgan jadvallar ($($missingTables.Count)):" -ForegroundColor Red
    $missingTables | ForEach-Object { Write-Host "  - $_" }
}

if ($missingCols.Count -eq 0) {
    Write-Host "Yetishmayotgan ustun: yo'q" -ForegroundColor Green
} else {
    Write-Host "Yetishmayotgan ustunlar ($($missingCols.Count)):" -ForegroundColor Red
    $missingCols | ForEach-Object { Write-Host "  - $_" }
}

if ($storageOk -and $storageIssues.Count -eq 0) {
    Write-Host "Storage (R2 stub): OK (content-assets bucket bor)" -ForegroundColor Green
} else {
    Write-Host "Storage muammosi:" -ForegroundColor Yellow
    $storageIssues | ForEach-Object { Write-Host "  - $_" }
}

if ($missingRpc.Count -eq 0) {
    Write-Host "Ranking RPC: bor" -ForegroundColor Green
} else {
    Write-Host "Ranking RPC yo'q (normal - backend Python fallback ishlatadi):" -ForegroundColor Yellow
    $missingRpc | ForEach-Object { Write-Host "  - $_" }
}

$extraInDb = @($existingSet | Where-Object { $_ -notin $requiredTables })
if ($extraInDb.Count -gt 0) {
    Write-Host "Bazada qo'shimcha jadvallar (kod ishlatmaydi, xato emas): $($extraInDb.Count)" -ForegroundColor DarkGray
}

if ($missingTables.Count -gt 0 -or $missingCols.Count -gt 0) {
    Write-Host ""
    Write-Host "Yechim: .\scripts\apply-neon-migrations.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Schema to'liq mos - chiqib qoladigan jadval/ustun yo'q." -ForegroundColor Green
