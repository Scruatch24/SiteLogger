# Windows PowerShell equivalent of bin/dev
# Starts Rails server + Tailwind CSS watcher in parallel (like Procfile.dev)

Write-Host "Starting TalkInvoice development server..." -ForegroundColor Cyan

# Build Tailwind CSS first (ensures fresh build before watch starts)
Write-Host "Building Tailwind CSS..." -ForegroundColor Yellow
ruby bin/rails tailwindcss:build 2>$null

# Start Tailwind watcher in background
Write-Host "Starting Tailwind CSS watcher..." -ForegroundColor Yellow
$tailwindJob = Start-Job -ScriptBlock {
    Set-Location $using:PWD
    ruby bin/rails tailwindcss:watch 2>&1
}

# Give Tailwind a moment to start
Start-Sleep -Seconds 2

# Start Rails server in foreground
Write-Host ""
Write-Host "Starting Rails server on http://localhost:3000" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop both servers" -ForegroundColor DarkGray
Write-Host ""

try {
    ruby bin/rails server -p 3000
} finally {
    # Clean up Tailwind watcher when Rails server stops
    Write-Host "`nStopping Tailwind watcher..." -ForegroundColor Yellow
    Stop-Job $tailwindJob -ErrorAction SilentlyContinue
    Remove-Job $tailwindJob -Force -ErrorAction SilentlyContinue
    Write-Host "Done." -ForegroundColor Green
}
