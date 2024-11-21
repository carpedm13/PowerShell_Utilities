param (
	[parameter (mandatory=$true,  Position = 0)]
	[string[]] $userIdentifier
)

# Get Hive Information for items under profile list
$gci = Get-ChildItem 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList'
$returnArray = @()

foreach ($userId in $userIdentifier){

# Parse Each entry for relevant data
foreach ($ci in $gci){
	$value = $ci.GetValue('ProfileImagePath')
		if ($value -like "*$userId*"){
			$userInfoArray = New-Object -TypeName System.Object
			$userInfoArray | Add-Member -MemberType NoteProperty -Name 'UserIdentifier' -Value $userId
			$userInfoArray | Add-Member -MemberType NoteProperty -Name 'ProfilePath' -Value $ci.name
			$returnArray += $userInfoArray
		}
	}
}

if ($returnArray -match "\S"){
	return $returnArray
}
else {
	return $null
}