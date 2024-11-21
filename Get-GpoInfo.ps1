[cmdletbinding()]
param (
    [parameter (mandatory=$true,  Position = 0)]
    [string] $computerName,

    [parameter (mandatory=$false,  Position = 1)]
    [string] $domainName = $env:USERDNSDOMAIN
)

function Set-ConsolePosition {
    [cmdletbinding()]
    param (
        [parameter (mandatory=$true,  Position = 0)]
        [int] $X,
        
        [parameter (mandatory=$true,  Position = 1)]
        [int] $Y
    )
    # Get current cursor position and store away
    $position=$host.ui.rawui.cursorposition

    # Store new X and Y Co-ordinates away
    $position.x=$x
    $position.y=$y

    # Place modified location back to $HOST
    $host.ui.rawui.cursorposition=$position

}

function Write-LineToHost {
    [cmdletbinding()]
    param (
        [parameter (mandatory=$true,  Position = 0)]
        [int] $x,
        [parameter (mandatory=$true,  Position = 1)]
        [int] $y,
        [parameter (mandatory=$true,  Position = 2)]
        [int] $length,
        [parameter (mandatory=$false,  Position = 3)]
        [bool] $vertical = $false
    )
    # Move to assigned X/Y position in Console 
    set-ConsolePosition $x $y
    # Draw the Beginning of the line
    write-host '|' -nonewline 
    # Is this vertically drawn?  Set direction variables and appropriate character to draw 
    If ([boolean] $vertical){
        $linechar='|'
        $vert=1
        $horz=0
    }
    else{
        $linechar='='
        $vert=0
        $horz=1
    } 
    # Draw the length of the line, moving in the appropriate direction 
        foreach ($count in 1..($length-1)) { 
            set-ConsolePosition (($horz*$count)+$x) (($vert*$count)+$y)
            write-host $linechar -nonewline
        }
    # Bump up the counter and draw the end
    $count++
    set-ConsolePosition (($horz*$count)+$x) (($vert*$count)+$y) 
    write-host '|' -nonewline
}
New-Alias -Name 'Draw-Line' -Value 'Write-LineToHost'

function Get-DomainController {
    param(
        [parameter (mandatory=$true,  Position = 0)]
        [string] $domainName
    )

    $domainControllers = Get-ADDomainController -DomainName $domainName -Discover -NextClosestSite
    $domainController = $domainControllers.HostName[0]

    return $domainController
}

$computer = Get-ADComputer $computerName -Server (Get-DomainController -domainName $domainName)
$servername= ('{0},' -f $computer.DistinguishedName.Split(',')[0])
$ouDn = $computer.DistinguishedName.Replace("$servername",'')
# $OU = Get-ADOrganizationalUnit -Identity $ouDn

# Write Link Info to Screen
$string = "Linked OU: $ouDN"
Write-Host "Computer Name: $computerName"
Write-Host "$string`n"
Draw-Line -x 0 -y ($y = $host.ui.RawUI.CursorPosition.Y) -length ($string.Length * 1.8)
Write-Host "`n`nGroup Policy Info: "

# Get list of GPOs
$inheritedLinks = Invoke-Command -Session $(Get-PSSession -Name WinPSCompatSession) -ScriptBlock {(Get-GPInheritance -Target $using:ouDn -Domain $using:domainName).InheritedGpoLinks}

# Generate Empty Array
$array = @()

foreach ($inheritedLink in $inheritedLinks){
    # Get GUID From Link
    $guid = $inheritedLink.GpoId.Guid
    $linkedOU = $inheritedLink.Target

    # Pull XML Report Of GPO
    [xml]$gpo = Get-GPOReport -Guid $guid -ReportType XML -Domain $domainName

    # Set GPO Name
    $gpoName = $gpo.GPO.name

    # Parse for Group Names
    if ($gpo.GPO.Computer.ExtensionData.Extension.RestrictedGroups){
        foreach ($memberItem in $gpo.GPO.Computer.ExtensionData.Extension.RestrictedGroups){
            if ($memberItem.GroupName.Name.'#text' -like "BUILTIN\*"){
                $LocalGroup = $memberItem.GroupName.Name.'#text'
                foreach ($adGroup in $memberItem.Member.name.'#text'){
                    $informationArray = New-Object -TypeName System.Object
                    $informationArray | Add-Member -MemberType NoteProperty -Name 'Linked OU Location' -Value $linkedOU
                    $informationArray | Add-Member -MemberType NoteProperty -Name 'GPO Name' -Value $gpoName
                    $informationArray | Add-Member -MemberType NoteProperty -Name 'Local Group' -Value $LocalGroup
                    $informationArray | Add-Member -MemberType NoteProperty -Name 'Domain Group' -Value $adGroup
                    $array += $informationArray
                }
            }
            elseif ($memberItem.MemberOf.Name.'#text' -like "BUILTIN\*"){
                $LocalGroup = $memberItem.MemberOf.Name.'#text'
                foreach ($adGroup in $memberItem.GroupName.name.'#text'){
                    $informationArray = New-Object -TypeName System.Object
                    $informationArray | Add-Member -MemberType NoteProperty -Name 'Linked OU Location' -Value $linkedOU
                    $informationArray | Add-Member -MemberType NoteProperty -Name 'GPO Name' -Value $gpoName
                    $informationArray | Add-Member -MemberType NoteProperty -Name 'Local Group' -Value $LocalGroup
                    $informationArray | Add-Member -MemberType NoteProperty -Name 'Domain Group' -Value $adGroup
                    $array += $informationArray
                }
            }
        }
    }
}

$array = $array | sort 'Linked OU Location'

return $array