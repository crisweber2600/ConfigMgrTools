#region Functions
Function Invoke-Git {
    <#
    .SYNOPSIS
        Wrapper to invoke git and return streams

    .FUNCTIONALITY
        CI/CD

    .DESCRIPTION
        Wrapper to invoke git and return streams

    .PARAMETER Arguments
        If specified, call git with these arguments.

        This takes a positional argument and accepts all value afterwards for a more natural 'git-esque' use.

    .PARAMETER Path
        Working directory to launch git within.  Defaults to current location

    .PARAMETER RedirectStandardError
        Whether to capture standard error.  Defaults to $true

    .PARAMETER RedirectStandardOutput
        Whether to capture standard output.  Defaults to $true

    .PARAMETER UseShellExecute
        See System.Diagnostics.ProcessStartInfo.  Defaults to $false

    .PARAMETER Raw
        If specified, return an object with the command, output, and error properties.

        Without Raw or Quiet, we return output if there's output, and we write an error if there are errors

    .PARAMETER Split
        If specified, split output and error on this.  Defaults to `n

    .PARAMETER Quiet
        If specified, do not return output

    .PARAMETER GitPath
        Path to git.  Defaults to git (i.e. git is in $ENV:PATH)

    .EXAMPLE
        Invoke-Git rev-parse HEAD

        # Get the current commit hash for HEAD

    .EXAMPLE
        Invoke-Git rev-parse HEAD -path C:\sc\PSStackExchange

        # Get the current commit hash for HEAD for the repo located at C:\sc\PSStackExchange

    .LINK
        https://github.com/RamblingCookieMonster/BuildHelpers

    .LINK
        about_BuildHelpers
    #>
    [cmdletbinding()]
    param(
        [parameter(Position = 0,
            ValueFromRemainingArguments = $true)]
        $Arguments,

        $NoWindow = $true,
        $RedirectStandardError = $true,
        $RedirectStandardOutput = $true,
        $UseShellExecute = $false,
        $Path = $PWD.Path,
        $Quiet,
        $Split = "`n",
        $Raw,
        [validatescript( {
                if (-not (Get-Command $_ -ErrorAction SilentlyContinue)) {
                    throw "Could not find command at GitPath [$_]"
                }
                $true
            })]
        [string]$GitPath = 'git'
    )

    $Path = (Resolve-Path $Path).Path
    # http://stackoverflow.com/questions/8761888/powershell-capturing-standard-out-and-error-with-start-process
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    if (!$PSBoundParameters.ContainsKey('GitPath')) {
        $GitPath = (Get-Command $GitPath -ErrorAction Stop)[0].Path
    }
    $pinfo.FileName = $GitPath
    $Command = $GitPath
    $pinfo.CreateNoWindow = $NoWindow
    $pinfo.RedirectStandardError = $RedirectStandardError
    $pinfo.RedirectStandardOutput = $RedirectStandardOutput
    $pinfo.UseShellExecute = $UseShellExecute
    $pinfo.WorkingDirectory = $Path
    if ($PSBoundParameters.ContainsKey('Arguments')) {
        $pinfo.Arguments = $Arguments
        $Command = "$Command $Arguments"
    }
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $null = $p.Start()
    $p.WaitForExit()
    if ($Quiet) {
        return
    }
    else {
        #there was a newline in output...
        if ($stdout = $p.StandardOutput.ReadToEnd()) {
            if ($split) {
                $stdout = $stdout -split "`n" | Where-Object { $_ }
            }
            $stdout = foreach ($item in @($stdout)) {
                $item.trim()
            }
        }
        if ($stderr = $p.StandardError.ReadToEnd()) {
            if ($split) {
                $stderr = $stderr -split "`n" | Where-Object { $_ }
            }
            $stderr = foreach ($item in @($stderr)) {
                $item.trim()
            }
        }

        if ($Raw) {
            [pscustomobject]@{
                Command = $Command
                Output  = $stdout
                Error   = $stderr
            }
        }
        else {
            if ($stdout) {
                $stdout
            }
            if ($stderr) {
                foreach ($errLine in $stderr) {
                    Write-Error $errLine.trim()
                }
            }
        }
    }
}
function Remove-CMScriptSigning {
    <#
.Synopsis 
Removed the "# EncodedScript # Begin Configuration Manager encoded script block” block from text.
.Description
In some scripts the "# EncodedScript # Begin Configuration Manager encoded script block” block is inserted.
The scripts in GIT won’t have the encoded script block.
This script will remove the encoded script block.
.Parameter Text
The string to remove encoded script block from

#>
    [cmdletBinding()]
    param(
        $scriptText,
        $Find = "# EncodedScript # Begin Configuration Manager encoded script block"
    )
    begin {
        $Ending = ScriptText | select-string $find
    }
    process {
        if ($ending.length -gt 0) {
            $linenumber = 0
            foreach ($end in $ending) {
                if ($lineNumber -eq 0) {
                    $linenumber = $end.linenumber
                }
                elseif ($linenumber -gt $end.LineNumber) {
                    $lineNumber = $end.linenumber
                }
                $LineNumber = $lineNumber - 1 #Finds the line number that the signing block is on.
            }
            $text = @()
            $counter = 0
            while ($counter -lt $linenumber) {
                $text += $scriptText[$counter]
                $counter++
            }
        }         
        else {
            $text = $scriptText
        }
        $text = Remove-BlankLines $text
    }
    end {
        $text
    }
}
Function Remove-BlankLines {
    <#
.SYNOPSIS
	Removes blank lines so that you can compare two scripts without worrying about blank lines.
.Description
Trims the spaces from the end of the lines.
If the line is a blank line then remove the line.
.Parameter Text
The string to remove blank lines from.
#>
    [CmdletBinding()]
    param(
        $Text
    )
    begin {
        try {
            [system.collections.arraylist] $Text = $text

        }
        catch {
            $text = $text #Not needed
        }
        $output = @()
    }
    process {
        foreach ($line in $text) {
            $line = $line.trim()
            if ($line -ne "") {
                $output += $line
            }
        }
    }
    end {
        $output
    }
}
function Get-GitErrors {
    <#
	.Synopsis
	Searches for the words error or fatal. if occurs then returns true. else returns false.
	.Parameter GitText
	This should be from the output of the git commands
	.Outputs
	Bool
	$true - There are no errors in the process
	$false - errors were detected.
	#>
    [cmdletBinding()]
    param(
        $GitText
    )
    begin {
        $errorText = "error", "fatal"
        $output = $true
    }
    process {
        foreach ($errorObj in $ErrorText) {
            foreach ($GitObj in $GitText) {
                if ($GitObj -like "$errorObj*") {
                    $output = $false
                }
            }
        }
    }
    end {
        $output
    }
}
function Get-CIBranchFromGit {
    <#
    .SYNOPSIS
        Updates the local copy of GIT with the branch you specify.
    .DESCRIPTION
        CHecks to see if the local repo is setup.
        If it is not setup then it clones the GIT Repo, Changes to the branch specified and pulls down the latest changes.
        If the repo is setup it changes to the branch specified and pulls down the latest changes.
        It checks for any errors and if there were no errors it outputs $True. If errors occured then it outputs $false.
    .PARAMETER BranchName
        The name of the branch that will be updated locally.
    .PARAMETER RepoDirectory
        The local path where the repo is setup or will be setup.
    #>
    param(
        $BranchName,
        $RepoDirectory = "c:\temp\git"
    )
    begin {
        $GitURL = "https://github.com/crisweber2600/ConfigurationItems.git" #TODO: Change to param
        $repoSetup = test-path $repoDirectory
        $GitText = @()
    }
    process {
        if ($repoSetup) {
            set-location $repoDirectory
            $GitText += invoke-git checkout $branchName 
            $GitText += invoke-git pull origin $branchName
        }
        else {
            $ParentDirectory = split-path -path $repoDirectory -parent
            #TODO:Check if parent DIR exists
            set-location $parentDirectory
            $GitText += invoke-git clone $gitURL
            set-location $repoDirectory
            $GitText += invoke-git checkout $branchName
            $GitText += invoke-git pull
        }
        $output = get-GitErrors $GitText
    }
    end {
        $output
    }
}
function Get-CMCI {
    param(
        $SiteCode,
        $SMSServer,
        $creds
    )
    $CIs = get-CMWQLQuery -SiteCode $SiteCode -SMServer $SMSServer -credentials $Creds -WQLQuery 'Select * from SMS_ConfigurationItemLatest where CIType_ID IN (3,4,5) AND IsHidden = 0 AND IsExpired = 0'
    $CIs
}
function get-cmwqlquery {
    param(
        $siteCode,
        $SMSServer,
        $WQLQuery,
        $Creds
    )
    get-wmiobject -query $WQLQuery -namespace "root\sms\site_$SiteCode" -ComputerName $SMSServer -credential $Creds | foreach-object { $_.get(); $_ }
}
Function Get-CIName {
    param(
        $name,
        $CIs
    )
    $CI = $CIs | where-object { $_.LocalizedDisplayName -eq $name }
    $CI
}
function get-CIDiscoveryScript {
    param(
        $CI
    )
    begin {
        [XML]$XML = $CI.SDMPackageXML
        $simpleSettings = $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting
        foreach ($simpleSetting in $simpleSettings) {
            $DisplayName = $SimpleSettings.annotation.DisplayName.Text
            if ($DisplayName -eq "Script") {
                try {
                    $DiscoveryScript = $simpleSetting.ScriptDiscoverySource.DiscoveryScriptBody.'#text'
                }
                catch {
                    $DiscoveryScript = $false
                }
            }	
        }
    }
    process {
        if ($discoveryScript -ne $false) {
            $DiscoveryScript | out-file "$env:TEMP/DiscoveryScript.ps1" -Force
            try {
                [System.Collections.ArrayList] $DiscoveryScript = get-content "$env:TEMP/DiscoveryScript.ps1"
            }
            catch {
                $DiscoveryScript = Get-Content "$env:TEMP/DiscoveryScript.ps1"
            }
            $DiscoveryScript = Remove-CMScriptSigning -scriptText $DiscoveryScript
        }
		
    }
    end {
        $DiscoveryScript
    }
}
function get-CIRemediationScript {
    param(
        $CI
    )
    begin {
        [XML]$XML = $CI.SDMPackageXML
        $SimpleSettings = $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting
        foreach ($simpleSetting in $simpleSettings) {
            $DisplayName = $SimpleSettings.annotation.DisplayName.Text
            if ($DisplayName -eq "Script") {
                try {
                    $RemediationScript = $simpleSetting.ScriptDiscoverySource.RemediationScriptBody.'#text'
                }
                catch {
                    $RemediationScript = $false
       
                }
            }
        }
		
    }
    process {
        if ($RemediationScript -ne $false) {
            $RemediationScript | out-file "$env:TEMP/RemediationScript.ps1" -force
            [System.Collections.ArrayList] $RemediationScript = get-content "$env:TEMP/RemediationScript.ps1"
            $RemediationScript = Remove-CMScriptSigning -ScriptText $RemediationScript
        }
    }
    end {
        $RemediationScript
    }
}
function Compare-Scripts {
    param
    (
        $FirstScript,
        $SecondScript
    )
    $firstScript | out-file "$env:TEMP\FirstScript.ps1" -force
    $secondScript | out-file "$env:TEMP\SecondScript.ps1" -force
    $FirstHash = (Get-fileHash "$env:TEMP\FirstScript.ps1").Hash
    $SecondHash = (Get-fileHash "$env:TEMP\SecondScript.ps1").Hash
    remove-item "$env:TEMP\FirstScript.ps1" -Force
    remove-item "$env:TEMP\SecondScript.ps1" -Force
    if ($FirstHash -eq $SecondHash) {
        $output = $true
    }
    else {
        $output = $false
    }
    $output
}
function Set-DiscoveryScriptFile {
    param(
        $CI,
        $discoveryScriptFile
    )
    $output = $true
    [XML] $XML = $CI.SDMPackageXML
    $counter = 0
    $SimpleSettings = $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting
    foreach ($SimpleSetting in $simpleSettings) {
        $DisplayName = $SimpleSetting.annotation.DisplayName.Text
        if ($DisplayName -eq "Script") {
            try {
                $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting[$counter].ScriptDiscoverySource.DiscoveryScriptBody."#text" = ([string]$discoveryScriptFile)
            }
            catch {
                try {
                    $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting.ScriptDiscoverySource.DiscoveryScriptBody."#text" = ([string]$discoveryScriptFile)
                }
                catch {
                    $output = $false
                }
            }
        }
        $counter++
    }
    try {
        $XML.Save("$env:TEMP\CIXML.xml")
        $XMLString = get-content "$env:TEMP\cixml.xml" -raw
        $CI.SDMPackageXML = $XMLString
        Remove-Item "$env:TEMP\cixml.xml" -force
    }
    catch {
        $output = $false
    }
    if ($output -ne $false) {
        $output = $CI
    }
    $output
}
function Set-RemediationScriptFile {
    param(
        $CI,
        $RemediationScriptFile
    )
    $output = $true
    [XML] $XML = $CI.SDMPackageXML
	
    $counter = 0
    $simpleSettings = XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting
    foreach ($simpleSetting in $simpleSettings) {
        $DisplayName = $SimpleSetting.annotation.DisplayName.Text
        if ($DisplayName -eq "Script") {
            try {
                $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting[$counter].ScriptDiscoverySource.RemediationScriptBody.'#text' = ([string]$RemediationScriptFile)
            }
            catch {
                try {
                    $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting.ScriptDiscoverySource.RemediationScriptBody.'#text' = ([string]$RemediationScriptFile)
                }
                catch {
                    try {
                        #Create With Counter
                        $RemediationScriptBodyElement = $XML.CreateElement("RemediationScriptBody", $XML.DocumentElement.NamespaceURI)
                        $ScriptTypeAttribute = $XML.CreateAttribute("ScriptType")
                        $ScriptTypeAttribute.Value = "PowerShell"
                        $XMLText = $XML.CreateTextNode("")
                        $RemediationScriptBodyElement.AppendChild($XMLText) | out-null
                        $RemediationScriptBodyElement.Attributes.Append($ScriptTypeAttribute) | out-null
                        $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting.ScriptDiscoverySource.AppendChild($RemediationScriptBodyElement) | Out-Null
                        $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting[$counter].ScriptDiscoverySource.RemediationScriptBody."#text" = ([string]$RemediationScriptFile)
						
                    }
                    catch {
                        try {
                            #create without counter
                            $RemediationScriptBodyElement = $XML.CreateElement("RemediationScriptBody", $XML.DocumentElement.NamespaceURI)
                            $ScriptTypeAttribute = $XML.CreateAttribute("ScriptType")
                            $ScriptTypeAttribute.Value = "PowerShell"
                            $XMLText = $XML.CreateTextNode("")
                            $RemediationScriptBodyElement.AppendChild($XMLText) | out-null
                            $RemediationScriptBodyElement.Attributes.Append($ScriptTypeAttribute) | out-null
                            $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting.ScriptDiscoverySource.AppendChild($RemediationScriptBodyElement) | Out-Null
                            $XML.DesiredConfigurationDigest.OperatingSystem.Settings.RootComplexSetting.SimpleSetting.ScriptDiscoverySource.RemediationScriptBody."#text" = ([string]$RemediationScriptFile)
							
                        }
                        catch {
                            $output = $false
                        }
                    }
                }
			
			
            }
        }
        $Counter++
    }
    try {
        $XML.Save("$env:TEMP\CIXML.XML")
        $XMLString = get-content "$env:TEMP\cixml.xml" -raw
        $CI.SDMPackageXML = $XMLString
        remove-item "$env:TEMP\cixml.xml" -force
    }
    catch {
        $output = $false
    }
    if ($output) {
        $Output = $CI
    }
    $output
}
function set-ci {
    param(
        $CI
    )
    begin {
        [XML]$XML = $CI.SDMPackageXML
        [int]$version = $XML.DesiredConfigurationDigest.OperatingSystem.Version
        $Version++
        $XML.DesiredConfigurationDigest.OperatingSystem.Version = ([String]$version)
        $XML.save("$env:TEMP\CIXML.xml")
        $XMLString = get-content "$env:TEMP\CIXML.xml" -raw
        $CI.SDMPackageXML = $XMLString
        Remove-Item "$env:TEMP\cixml.xml" -force
    }
    process {
        $output = $CI.put()
    }
    end {
        $output
    }
}

function initialize-Git {
    param(
        $branchName
    )
    $GitSync = Get-CIBranchFromGit -BranchName $branchName
    $creds = Get-Credential
    $creds
}
function Sync-GitCM {
    param(
        $creds,
        $CIName,
        $CIs,
        [bool]$LogOnly
    )
    
    $CI = Get-CIName -CIs $CIs -name $CIName

    $DiscoveryScript = Get-CIDiscoveryScript -CI $CI
    $DiscoveryScriptFileRaw = get-content ".\$CIName\DiscoveryScript.ps1" -Raw
    $DiscoveryScriptFileContent = get-content ".\$CIName\DiscoveryScript.ps1"
    $DiscoveryScriptFile = Remove-CMScriptSigning -ScriptText $DiscoveryScriptFileContent
    $DiscoveryScriptMatch = Compare-Scripts -FirstScript $discoveryScript -SecondScript $discoveryScriptFile
    $RemediationScript = Get-CIRemediationScript -CI $CI
    $RemediationScriptFileRaw = Get-Content ".\$CIName\RemediationScript.ps1" -Raw
    $RemediationScriptContent = Get-Content ".\$CIName\RemediationScript.ps1"
    $RemediationScriptFile = Remove-CMScriptSigning -ScriptText $RemediationScriptContent
    $RemediationScriptMatch = Compare-Scripts -FirstScript $RemediationScript -SecondScript $RemediationScriptFile
    function Out-CILog {
        [CmdletBinding()]
        param (
            $CI,
            $DiscoveryScriptInfo,
            $RemediationScriptInfo
        )
    
        begin {
            $properties = @{
                CIName                = $CI.LocalizedDisplayName
                DiscoveryScriptInfo   = $DiscoveryScriptInfo
                RemediationScriptInfo = $RemediationScriptInfo
            }
        }
    
        process {
        
            $Object = New-Object psobject -Property $properties
            
        }
    
        end {
            $Object | ConvertTo-Csv -NoTypeInformation | Out-File $env:TEMP\CILog.csv -Append
        }
    }
    if ($RemediationScriptMatch -eq $false -or $discoveryScriptMatch -eq $False) {
        if ($null -ne $CI) {
            if ($LogOnly) {
                Out-CILog -CI $CI -DiscoveryScriptInfo $DiscoveryScriptMatch -RemediationScriptInfo $RemediationScriptMatch
            }
            else {
                try {
                    
                    $CI = set-discoveryScriptFile -CI $CI -DiscoveryScriptFile $DiscoveryScriptFileRaw
                    $CI = Set-RemediationScriptFile -CI $CI -RemediationScriptFile $RemediationScriptFileRaw
                    Set-CI -CI $CI
                    Out-CILog -CI $CI -DiscoveryScriptInfo "Successful" -RemediationScriptInfo "Successful"
                }
                catch {
                    
                    Out-CILog -CI $CI -DiscoveryScriptInfo "Error" -RemediationScriptInfo "Error"
                }
            
            } 
        }
        else {
            
            Out-CILog -CI $CI -DiscoveryScriptInfo "Error" -RemediationScriptInfo "Error"
        }
    }
}
$creds = initialize-Git -branchName "QA"

$CILocation = "C:\temp\ConfigurationItems"
$folders = Get-ChildItem $CILocation
$CIs = get-CMCI -SiteServer "cmps1.contoso.com" -SiteCode "PS1" -Credentials $Creds
foreach ($folder in $folders) {
    $CIName = $folder.name
    Write-Verbose "CIName: $CIName"
    Sync-GitCM -creds $creds -CIName $CIName -CIs $CIs
}