# build_roblox_plugin.ps1
# This script automatically downloads Rojo (if needed) and compiles the Roblox Plugin (.rbxmx)

$ErrorActionPreference = "Stop"
$PluginName = "BlenderAnimationsAI.rbxmx"
$RojoDir = "rojo_bin"
$RojoExe = "$RojoDir\rojo.exe"
$RojoVersion = "v7.7.0"
$RojoUrl = "https://github.com/rojo-rbx/rojo/releases/download/$RojoVersion/rojo-7.7.0-windows-x86_64.zip"

Write-Host "Checking for Rojo compiler..."
if (-not (Test-Path -Path $RojoExe)) {
    Write-Host "Rojo not found locally. Downloading Rojo $RojoVersion..."
    Invoke-WebRequest -Uri $RojoUrl -OutFile "rojo.zip"
    
    Write-Host "Extracting Rojo..."
    Expand-Archive -Path "rojo.zip" -DestinationPath $RojoDir -Force
    Remove-Item -Path "rojo.zip" -Force
}

# Ensure default.project.json exists for the build
if (-not (Test-Path -Path "default.project.json")) {
    Write-Host "Creating default.project.json..."
    $ProjectJson = @'
{
  "name": "BlenderAnimationsAI",
  "tree": {
    "$className": "Folder",
    "BlenderAnimationsInternal": {
      "$className": "Folder",
      "$path": "ServerScriptService/BlenderAnimationsInternal"
    }
  }
}
'@
    Set-Content -Path "default.project.json" -Value $ProjectJson
}

Write-Host "Building plugin $PluginName..."
& $RojoExe build -o $PluginName

if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful! Created $PluginName"
    
    # Optionally install it directly to local plugins if the folder exists
    $PluginsDir = "$env:LOCALAPPDATA\Roblox\Plugins"
    if (Test-Path -Path $PluginsDir) {
        Copy-Item -Path $PluginName -Destination "$PluginsDir\$PluginName" -Force
        Write-Host "Successfully installed $PluginName to your Roblox Plugins folder!"
    }
} else {
    Write-Host "Build failed with exit code $LASTEXITCODE" -ForegroundColor Red
}

Write-Host "Done."
