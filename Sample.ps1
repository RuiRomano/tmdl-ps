$ErrorActionPreference = "Continue"

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Set-Location $currentPath

Import-Module ".\TMDLPS.psm1" -Force

try {

    ConvertTo-TMDL -tmslPath ".\Sales.bim" -outputPath ".\output\Sales"
    #ConvertFrom-TMDL -tmdlPath ".\output\Sales"-outputPath ".\output\sales.bim"
    #Publish-TMDL -tmdlPath ".\Sales" -serverConnection "powerbi://api.powerbi.com/v1.0/myorg/TMDL Test" -datasetName "Sales"

}
catch {
    $ex = $_.Exception
    Write-Host $ex.ToString()
    
}
