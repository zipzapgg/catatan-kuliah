param(
    [ValidateSet('debug', 'release')][string]$Mode = 'debug',
    [string]$Jdk = (Split-Path (Split-Path (Get-Command java -ErrorAction Stop).Source -Parent) -Parent)
)

$ErrorActionPreference = 'Stop'
$taskPreviousGradleOptions = $env:GRADLE_OPTS
Push-Location (Join-Path $PSScriptRoot '..')
try {
    $env:GRADLE_OPTS = "$taskPreviousGradleOptions -Dorg.gradle.java.home=`"$Jdk`""
    flutter build apk "--$Mode" --no-pub
    if ($LASTEXITCODE -ne 0) { throw "Build APK gagal (exit $LASTEXITCODE)." }
} finally {
    $env:GRADLE_OPTS = $taskPreviousGradleOptions
    Pop-Location
}
