param(
    [switch]$IncludeEnergyCommunityFiles
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$samplesDir = Join-Path $root "samples"
$downloadsDir = Join-Path $root "downloads"

New-Item -ItemType Directory -Force -Path $samplesDir, $downloadsDir | Out-Null

function Save-Url {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$OutFile
    )

    Write-Host "Downloading $Url"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $OutFile
}

# 1. Mesa Del Sol lightweight artifact
$mesaReadme = Join-Path $samplesDir "mesa_del_sol_README.md"
Save-Url `
    -Url "https://zenodo.org/api/records/8339403/files/README.md/content" `
    -OutFile $mesaReadme

# 2. EMSx lightweight artifact
$emsxMetadata = Join-Path $samplesDir "emsx_metadata.csv"
Save-Url `
    -Url "https://zenodo.org/api/records/5510400/files/metadata.csv/content" `
    -OutFile $emsxMetadata

# 3. NASA POWER sample aligned with the Prattico reference site
# Reggio Calabria approximate coordinates: lat 38.11, lon 15.65
$nasaSample = Join-Path $samplesDir "nasa_power_reggio_calabria_june_2025.csv"
$nasaUrl = "https://power.larc.nasa.gov/api/temporal/hourly/point?parameters=ALLSKY_SFC_SW_DWN,WS10M,T2M&community=RE&longitude=15.65&latitude=38.11&start=20250601&end=20250630&format=CSV"
Save-Url -Url $nasaUrl -OutFile $nasaSample

# 4. Optional: lightweight community dataset package
if ($IncludeEnergyCommunityFiles) {
    $communityDir = Join-Path $downloadsDir "energy_community"
    New-Item -ItemType Directory -Force -Path $communityDir | Out-Null

    Save-Url `
        -Url "https://zenodo.org/api/records/11351017/files/General%20description.docx/content" `
        -OutFile (Join-Path $communityDir "General_description.docx")

    Save-Url `
        -Url "https://zenodo.org/api/records/11351017/files/EC_EV_dataset%20(fixed%20error).xlsx/content" `
        -OutFile (Join-Path $communityDir "EC_EV_dataset_fixed_error.xlsx")
}

Write-Host ""
Write-Host "Done."
Write-Host "Artifacts saved under: $samplesDir"
if ($IncludeEnergyCommunityFiles) {
    Write-Host "Optional community files saved under: $(Join-Path $downloadsDir 'energy_community')"
}
