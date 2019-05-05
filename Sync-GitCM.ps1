set-gitpath
{
<#
.synopsis
	Checks to see if GIT is in the system path
.Description
	If git is in the system path then return $true
	if git is not in the system path then put it in the system path.
if git is still not setup then return false
.PARAMETER GitPath
	The path of the directory that git is in.
If GIT Path is not specifified then it will not specify a new git path.
.Output
Bool outputs true or false
example
set-get path -getpath c:\git\bin
#checks to see if the git path is setup. and if it’s not then set it to c:\git\bin.
#>
[cmdletbinding()]
param(
$GitPath
)
begin{
$windows_path = $env:path
$PathItems = $windows_path -split ‘;’
$gitPath = $pathitems|where-Object {$_ -like ‘*git*’}
if($GitPath.Count -ge 1)
{
$setup = $true
}
else
{
$setup = $false
}
}
Process
{
if(!$Setup)
{
$env:path += $gitPath
[Enviroment]::SetEnvironmentVariable(“Path”,$env:Path,[System.EnvironmentVariableTarget]::Machine)
}
$windows_path = $env:path
$PathItems = $windows_path -split ‘;’
$gitPath = $pathitems|where-Object {$_ -like ‘*git*’}
if($GitPath.Count -ge 1)
{
$setup = $true
}
else
{
$setup = $false
}
}
End
{
$setup
}
}

#Get InvokeGit function

function Remove-CMScriptSigning
{
<#
.Synopsis
Removed the “# EncodedScript # Begin Configuration Manager encoded script block” block from text.
.Description
In some scripts the “# EncodedScript # Begin Configuration Manager encoded script block” block is inserted.
The scripts in GIT won’t have the encoded script block.
This script will remove the encoded script block.
.Parameter Text
The string to remove encoded script block from

#>
[cmdletBinding()]
param(
$scriptText,
$Find = “# EncodedScript # Begin Configuration Manager encoded script block”
)
begin
{
$Ending = ScriptText | select-string $find
}
process
{
if($ending.length -gt 0)
{
$linenumber = 0
foreach($end in $ending){
if($lineNumber -eq 0){
$linenumber = $end.linenumber
}
elseif($linenumber -gt $end.LineNumber)
{
$lineNumber = $end.linenumber
}
$LineNumber++ #Finds the line number that the signing block is on.
$text = @()
$counter = 0
while($counter -lt $linenumber)
{
$text+=$scriptText[$counter]
$counter++
}
}
else
{
$text = $scriptText
$text = Remove-BlankLines $text
}
end{
$text
}
}
Function Remove-BlankLines{
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
begin
{
	[system.collections.arraylist] $Text = $text
	$output = @()
}
process
{
	foreach($line in $text)
	{
		$line = $line.trim()
		if($line -ne "")
		{
			$output +=$line
		}
	}
}
end
{
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
	begin
	{
		$errorText = "error","fatal"
		$output = $true
	}
	process
	{
		foreach($errorObj in $ErrorText){
			foreach($GitObj in $GitText)
			{
				if($GitObj -like "$errorObj*")
				{
					$output = $false
				}
			}
		}
	}
	end
	{
		$output
	}
}
function Git-CIBranchFromGit
{
	param(
		$BranchName,
		$RepoDirectory = "c:\temp\git"
	)
	begin
	{
		$GitURL = "TODO: GithubURL"
		$repoSetup = test-path $repoDirectory
		$GitText = @()
	}
	process{
		if($repoSetup)
		{
			set-location $repoDirectory
			$GitText += invoke-git checkout $branchName
			$GitText += invoke-git pull origin $branchName
		}
		else
		{
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
	end{
		$output
	}
}
function Get-WFCI
{
	param(
		$SiteCode,
		$SMSServer,
		$creds
	)
	$CIs = get-CMWQLQuery TODO: Finish This line
	$CIs
}
function get-cmwqlquery {
	param(
		$siteCode,
		$SMSServer,
		$WQLQuery,
		$Creds
	)
	get-wmiobject -query $WQLQuery -namespace "root\sms\site_$SiteCode" -ComputerName $SMSServer -credential $Creds | foreach-object {$_.get(); $_}
}