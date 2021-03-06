﻿function Drop-Module ($Module) {
    Remove-Module $Module -Force -ErrorAction SilentlyContinue
    if ((Test-Path $UserModulePath/$Module/)){	
		Remove-Item $UserModulePath/$Module/ -Force -Recurse -ErrorAction SilentlyContinue
	}

    #Delete all installations of this module that are locatable via the PSModulePath
    Get-Module -Name $Module | foreach {
        Remove-Item $_.ModuleBase -Force -Recurse -ErrorAction SilentlyContinue 
    }

    $Env:PSModulePath -split ";"
}

function Install-ModuleOutOfProcess {
    param([string]$module, [string]$FunctionNameToVerify,[string]$PackageVersion)
    # run this test out-of-process so the binary module can be removed without locking issues
    & powershell -noprofile -command {
        param ($here,$module,$FunctionNameToVerify,$PAckageVersion,$Global)
        Import-Module -Name "$here\PsGet\PsGet.psm1"
    
        install-module -NugetPackageId $module -DoNotImport -PackageVersion $PAckageVersion -update -Global:$Global
        Import-Module -Name $module
        if (-not (Get-Command -Name $FunctionNameToVerify -Module $module)) {
            throw "$module not installed"
        }
    } -args $here,$module,$FunctionNameToVerify,$PAckageVersion,$Global

}

function Canonicolize-Path {
    param(
    [Parameter(Mandatory=$true)]
    [string]$Path)
    
    return [io.path]::GetFullPath(($path.Trim() + '\'))

}

function Get-TempDir {
    return (join-path -path ([IO.Path]::GetTempPath()) -child ([Guid]::NewGuid().ToString()) )
}

function Remove-PathFromPSModulePath {
    param(
    [System.EnvironmentVariableTarget]$Scope = [System.EnvironmentVariableTarget]::User,
    [Parameter(Mandatory=$true)]
    [string]$PathToRemove,
    [switch]$PersistEnvironment)
   
    $existingPathValue = [Environment]::GetEnvironmentVariable("PSModulePath", $Scope)    
    $pathToRemove = Canonicolize-Path $PathToRemove

    #Canonicolize and cliean up path variable
    $newPathValue = Remove-PathFromEnvironmentPath "$existingPathValue" $PathToRemove

    #Only update the environment variable
    if($existingPathValue -notlike $newPathValue) {
        if($PersistEnvironment) {
            #Set the new value
            [Environment]::SetEnvironmentVariable("PSModulePath",$newPathValue, $Scope)
        }
        
        ReImportPSModulePathToSession

        #Just print out the new value for verbose
        $newSessionValue = Get-Content "env:\PSModulePath"
        Write-Host "The new value of the '$Scope' environment variable 'PSModulePath' is '$newSessionValue'"
    } else {
        Write-Verbose  "The new value of the '$Scope' environment variable 'PSModulePath' is the same as the existing value, will not update"
    }

}

function Remove-PathFromEnvironmentPath {
    param(  [Parameter(Mandatory=$true)]
            [string]$path, 
            [string]$pathToRemove,
            [switch]$AsArray)
 
    $paths = $path.Split(";") | foreach { Canonicolize-Path $_ } 
    $pathToRemove = Canonicolize-Path $pathToRemove
    $finalPaths = $paths | where { $_ -notlike $pathToRemove}
    
    if(-not $AsArray) {
        [string]::Join(";", $finalPaths);
    } else {
        $paths
    }
<#
.SYNOPSIS
    Removes occurence of a path from a PTAH type environment variable (PATH, PSModulePath etc.).  Also canonicalizes the paths (just ensures a trailing slash)
.PARAMETER Path
    The path is of the format:

    c:\foo;c:\bar;c:\man\cow\;c:\foo\bar\;c:\foo\bar

.PARAMETER PathToRemove
    The single path to remove from the 'Path' parameter
.NOTES

#>
}

function ReImportPSModulePathToSession {
    
    $NewSessionValue = ([Environment]::GetEnvironmentVariable("PSModulePath", "User") + ";" +  [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")).Trim(';') 
    
    #Set the value in the current process
    [Environment]::SetEnvironmentVariable("PSModulePath", $NewSessionValue, "Process")
    Set-Content env:\PSModulePath $NewSessionValue
}

function Get-UserModulePath {
    return $global:UserModuleBasePath
}