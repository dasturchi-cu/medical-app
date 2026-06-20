# Supabase PostgreSQL backup
# Birinchi marta: scripts\backup.env yarating (backup.env.example dan nusxa).

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $PSScriptRoot "backup.env"
$outDir = Join-Path $root "backups"
$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$sqlOut = Join-Path $outDir "supabase-$stamp.sql"

if (-not (Test-Path $envFile)) {
    Write-Host ""
    Write-Host "backup.env topilmadi." -ForegroundColor Yellow
    Write-Host "1) scripts\backup.env.example ni scripts\backup.env ga nusxalang"
    Write-Host "2) Supabase Connect > Session pooler > DATABASE_URL ni qoying"
    Write-Host ""
    exit 1
}

Get-Content $envFile | ForEach-Object {                                                                                                                                                                                                                                                                                                                                                                                                                              
    if ($_ -match '^\s*([^#=]+)\s*=\s*(.+)\s*$') {
        [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
    }
}

$dbUrl = $env:DATABASE_URL
if ([string]::IsNullOrWhiteSpace($dbUrl)) {
    Write-Host "backup.env ichida DATABASE_URL yoq." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if ($dbUrl -match 'db\.[^.]+\.supabase\.co') {
    Write-Host ""
    Write-Host "Ogohlantirish: Direct connection (db.*.supabase.co) Windows da IPv6 talab qiladi." -ForegroundColor Yellow
    Write-Host "Session pooler URI ishlating: Connect -> Session pooler -> URI" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host "Backup boshlandi..."
Write-Host "Fayl: $sqlOut"

$pgDumpCandidates = @(
    (Join-Path $PSScriptRoot "tools\pgextract\pgsql\bin\pg_dump.exe"),
    (Join-Path $PSScriptRoot "tools\pg_dump.exe")
)
$pgDump = $null
foreach ($candidate in $pgDumpCandidates) {
    if (Test-Path $candidate) { $pgDump = $candidate; break }
}
if (-not $pgDump) {
    $pgDumpCmd = Get-Command pg_dump -ErrorAction SilentlyContinue
    if ($pgDumpCmd) { $pgDump = $pgDumpCmd.Source }
}

if ($pgDump) {
    $pgBin = Split-Path -Parent $pgDump
    $env:PATH = "$pgBin;$env:PATH"
    & $pgDump --dbname=$dbUrl --no-owner --no-acl --file=$sqlOut 2>&1 | Tee-Object -Variable pgDumpLog | Out-Host
    if ($LASTEXITCODE -ne 0) {
        $logText = ($pgDumpLog | Out-String)
        if ($logText -match 'tenant/user.*not found|Payment Required|restricted') {
            Write-Host ""
            Write-Host "Supabase loyihasi cheklangan bo'lishi mumkin (egress limiti / to'lov)." -ForegroundColor Yellow
            Write-Host "Dashboard: loyihani tiklash (Pro upgrade) yoki Database -> Backups dan yuklab oling."
            Write-Host ""
        }
        throw "pg_dump xato (kod $LASTEXITCODE)"
    }
} elseif (Get-Command supabase -ErrorAction SilentlyContinue) {
    & supabase db dump --db-url $dbUrl -f $sqlOut --keep-comments
    if ($LASTEXITCODE -ne 0) { throw "supabase db dump xato (kod $LASTEXITCODE). Docker Desktop kerak bo'lishi mumkin." }
} else {
    Write-Host "pg_dump yoki supabase CLI kerak." -ForegroundColor Red
    exit 1
}

$sizeMb = [math]::Round((Get-Item $sqlOut).Length / 1MB, 2)
Write-Host ""
Write-Host "Tayyor! Backup: $sqlOut ($sizeMb MB)" -ForegroundColor Green
Write-Host "Bu faylni GitHub ga yuklamang. Ichida foydalanuvchi malumotlari bor."
