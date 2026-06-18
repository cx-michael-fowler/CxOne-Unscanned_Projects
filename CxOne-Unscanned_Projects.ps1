#--------------------------------------------------------------------------------------------------------------------------------------------------------------
#region Help

<#
.Synopsis
Script to create a CSV report of projects whose last scan was greater than 90 days ago

.Description
Creates a CSV with the following details for every project whose last scan was greater than 90 days ago and writes the results to the same 
directory as the script with the name Unscanned_Projects.csv

    Project Name, Primary Brnach, Last Scan Date, Branch Scanned, Engines Used

The days parameter will override the 90 day default option
The filePath pameter will over ride the default path and filename option.

NOTE: The script required the CxOneAPIModule to run. 

Usage
Help
    .\Unscanned_Projects.ps1 -help [<CommonParameters>]

Report
    .\Unscanned_Projects.ps1 [-days <Int>] [-filePath <String>] [-silentLogin -apiKey <string>] [<CommonParameters>] 
    
.Notes
Version:     1.0
Date:        18/06/2026
Written by:  Michael Fowler
Contact:     michael.fowler@checkmarx.com

Change Log
Version    Detail
-----------------
1.0        Original version

  
.PARAMETER help
Display help

.PARAMETER silentLogin
Log into Checkmarx One using the provided API Key. Is optional and if not used a prompt will appear for the key

.PARAMETER apiKey
The API Key used to log into Checkamrx One. Is mandatory with silentLogin

.PARAMETER days
Optional override for the number of days since last scan

.PARAMETER filePath
Optional file path for the output file. Must include the filename with CSV extension 


#>

#endregion
#--------------------------------------------------------------------------------------------------------------------------------------------------------------
#region Parameters

[CmdletBinding(DefaultParametersetName='Help')] 
Param (

    [Parameter(ParameterSetName='Help',Mandatory=$false, HelpMessage="Display help")]
    [switch]$help,

    [Parameter(ParameterSetName='CxOne',Mandatory=$false,HelpMessage="Logon silently using provided API Key")]
    [switch]$silentLogin,

    [Parameter(ParameterSetName='CxOne',Mandatory=$false,HelpMessage="Days Since Last Scan")]
    [int]$days=90,
      
    [Parameter(ParameterSetName='CxOne',Mandatory=$false, HelpMessage="Enter Full path for the output report")]
    [string]$filePath = "$PSScriptRoot\Unscanned_Projects.csv"

)

#endregion
#--------------------------------------------------------------------------------------------------------------------------------------------------------------
#region Dynamic Parameters

DynamicParam {
    if ($silentLogin) {
        # Define parameter attributes
        $paramAttributes = New-Object -Type System.Management.Automation.ParameterAttribute
        $paramAttributes.Mandatory = $true
        $paramAttributes.HelpMessage = "The API Key used to login"

        # Create collection of the attributes
        $paramAttributesCollect = New-Object -Type System.Collections.ObjectModel.Collection[System.Attribute]
        $paramAttributesCollect.Add($paramAttributes)

        # Create parameter with name, type, and attributes
        $dynParam = New-Object -Type System.Management.Automation.RuntimeDefinedParameter("apiKey", [string], $paramAttributesCollect)

        # Add parameter to parameter dictionary and return the object
        $paramDictionary = New-Object -Type System.Management.Automation.RuntimeDefinedParameterDictionary
        $paramDictionary.Add("apiKey", $dynParam)
        return $paramDictionary
    }
}

#endregion
#--------------------------------------------------------------------------------------------------------------------------------------------------------------
#region Begin

Begin {
    
    Import-Module $PSScriptRoot\CxOneAPIModule
    $apiKey = $PSBoundParameters['apiKey']
}

#endregion
#--------------------------------------------------------------------------------------------------------------------------------------------------------------
#region Process

Process {

    #Display help if called
    if ($help) {
        Get-Help $MyInvocation.InvocationName -Full | Out-String
        exit
    }

    Write-Host "=========="
    $start = Get-Date
    Write-Host "Processing Started at $(Get-Date -Format "HH:mm:ss")"

    # Log onto Checkmarx One 
    Write-Host "Logging on Checkmarx One"
    if ($silentLogin) { $conn = New-SilentConnection $apiKey }
    else { $conn = New-Connection }
    Write-Host "Login completed"

    Write-Host "Retrieving Projects"
    $projects = Get-AllProjects $conn
    Write-Host "Projects Retrieved"

    Write-Host "Retrieving Last Scans"
    $scans = Get-LastScans $conn $projects
    Write-Host "Scans Retrieved"

    Write-Host "Filtering scans and writing output"
    $threshold = (Get-Date).AddDays(-$days)
    $output = New-Object System.Collections.Generic.List[object]
    Foreach ($projectId in $scans.keys) {
        if($scans[$projectId].CreatedAt -lt $threshold) {
            $obj = [PSCustomObject]@{ 
                "Project_Name" = $projects[$projectId].ProjectName
                "Project_Primary_Branch" = $projects[$projectId].MainBranch
                "Last_Scan_Date" = $scans[$projectId].CreatedAt
                "Branch_Scanned" = $scans[$projectId].Branch
                "Scan_Engines" = $scans[$projectId].EnginesString
            }
            $output.Add($obj)            
        }
    }
    $output | export-csv $filepath -NoTypeInformation
    Write-Host "Results written to $filepath"
        
    $end = Get-Date
    $runtime = (New-TimeSpan –Start $start –End $end).ToString("hh\:mm\:ss")
    Write-Host "Processing Completed at $(Get-Date -Format "HH:mm:ss") with a runtime of $runtime"
    Write-Host "=========="
}

#endregion
#--------------------------------------------------------------------------------------------------------------------------------------------------------------