#requires -Version 7

$currentPath = (Split-Path $MyInvocation.MyCommand.Definition -Parent)

Write-Host "Loading Module Assemblies"

$libraryPath = "C:\@Repos\Github\tmdl-sample\Libs"

$nugets = @(
    @{
        name = "Microsoft.AnalysisServices.NetCore.retail.amd64"
        ;
        version = "19.61.1.4"
        ;
        path = @("lib\netcoreapp3.0\Microsoft.AnalysisServices.Tabular.dll"
        , "lib\netcoreapp3.0\Microsoft.AnalysisServices.Tabular.Json.dll"
        )
    }
    # There is a bug with this package, need to manual download and place it on the Nuget folder
    ,
    @{
        name = "Microsoft.AnalysisServices.Tabular.Tmdl.NetCore.retail.amd64"
        ;
        version = "19.61.1.4-TmdlPreview"
        ;
        path = @("lib\netcoreapp3.0\Microsoft.AnalysisServices.Tabular.Tmdl.dll")
    }
)

foreach ($nuget in $nugets)
{
    Write-Host "Installing nuget: $($nuget.name)"

    if (!(Test-Path "$currentPath\Nuget\$($nuget.name)*" -PathType Container)) {
        Install-Package -Name $nuget.name -ProviderName NuGet -Destination "$currentPath\Nuget" -RequiredVersion $nuget.Version -SkipDependencies -AllowPrereleaseVersions -Scope CurrentUser  -Force
    }
    
    foreach ($nugetPath in $nuget.path)
    {
        $path = Resolve-Path (Join-Path "$currentPath\Nuget\$($nuget.name).$($nuget.Version)" $nugetPath)
        Add-Type -Path $path -Verbose | Out-Null
    }
   
}

Function ConvertTo-TMDL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$tmslPath
        ,
        [Parameter(Mandatory = $true)]
        [string]$outputPath
	)

    Write-Host "Read TMSL"

    $tmslText = Get-Content $tmslPath

    $database = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::DeserializeDatabase($tmslText)

    Write-Host "Serialize to TMDL"

    [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::SerializeModel($database.Model, $outputPath)
}

Function ConvertFrom-TMDL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$tmdlPath
        ,
        [Parameter(Mandatory = $true)]
        [string]$outputPath
	)

    Write-Host "Read TMDL"

    $model = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeModel($tmdlPath)

    Write-Host "Serialize to TMSL"

    $options = New-Object Microsoft.AnalysisServices.Tabular.SerializeOptions

    $options.SplitMultilineStrings = $true
    
    $tmslText = [Microsoft.AnalysisServices.Tabular.JsonSerializer]::SerializeDatabase($model.Database,$options)

    $tmslText | Out-File $outputPath
}

Function Publish-TMDL
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$tmdlPath
        ,
        [Parameter(Mandatory = $true)]
        [string]$serverConnection
        ,
        [Parameter(Mandatory = $true)]
        [string]$datasetName
	)

    Write-Host "Read TMDL"

    $model = [Microsoft.AnalysisServices.Tabular.TmdlSerializer]::DeserializeModel($tmdlPath)

    try {
        
        $server = New-Object Microsoft.AnalysisServices.Tabular.Server

        $server.Connect($serverConnection)

        $remoteDatabase = $server.Databases.FindByName($datasetName)

        if ($remoteDatabase)
        {
            Write-Host "Updating dataset '$datasetName'"

            $model.CopyTo($remoteDatabase.Model)

            $result = $remoteDatabase.Model.SaveChanges()
        }
        else {
            Write-Host "Creating new dataset '$datasetName'"

            $model.Database.Name = $datasetName

            $remoteDatabase = $server.Databases.Add($model.Database)

            $model.Database.Update([Microsoft.AnalysisServices.UpdateOptions]::ExpandFull)
        }
    }
    finally {
        if ($remoteDatabase)
        {
            $remoteDatabase.Dispose()
        }

        if ($server)
        {
            $server.Dispose()
        }
    }

    
}