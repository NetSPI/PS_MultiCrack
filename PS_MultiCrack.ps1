##########################################################################################
# PS_MultiCrack.ps1
#		Fully cracks LM Half Chall passwords from an input file using Rcrack_mt and John
#
# Usage: PS_MultiCrack.ps1 INPUT_FILE OUTPUT_FILE
#
# Requirements: 
#				-Hashes need to be in this format:
#				 Domain\User:::LMHASH:NTLMHASH:1122334455667788
#
# To Add:
#		 - Stats for number of hashes cracked, number not found, total time
#
# Written by Karl Fosaaen
#	Twitter: @kfosaaen
#
##########################################################################################

#Setup your local directories for stuff here
#This should be your John\Run directory
$John_DIR = "C:\tools\rcracki_mt_0.6.6_win32_mingw\john179j5\run\"
#Where your rcrack_mt.exe lives
$rcrack_DIR = "C:\tools\rcracki_mt_0.6.6_win32_mingw\rcracki_mt_0.6.6_win32_mingw\rcracki_mt.exe"
#Where your halflmchall Rainbow are
$rtables_DIR = "C:\tools\RainbowTables\halflmchall\"
#Where your perl.exe lives
$perl_DIR = "C:\Perl64\bin\perl.exe"


#Checks your ARGS
if ($args[0] -and $args[1]){
$input_file = $args[0]
$output_file = $args[1]

#Writes your output file to the dir that you run this from
$file_to_write = ""+$(get-location)+"\"+$output_file+""
$home_DIR = ""+$(get-location)+"\"
$half_hash_loc = ""+$(get-location)+"\halfhash.txt"
}
else{
Write-Host "You're missing an input or output file name.`nUsage: PS_MultiCrack.ps1 INPUT_FILE OUTPUT_FILE"
break
}
 
$LineNum=1
$LineValid="true"
#Verify the hashes in the file before trying to open them
Get-Content $args[0] | Foreach-Object {
	#Check if it's DOMAIN\User
	$username_check = $_.Split(“:”)[0]
	#Length of 48
	$lmhash_check=$_.Split(“:”)[3]
	#Length of 48
	$ntlmhash_check=$_.Split(“:”)[4]
	#Length of 16
	$salt_check=$_.Split(“:”)[5]
			
	if ($username_check -notlike "*\*"){
		Write-Host "Line"$LineNum" is not properly formatted at the Domain\Username Add a \`n"$_"`n"
		break
	}
	if($lmhash_check.length -ne 48){
		Write-Host "Line"$LineNum" is not properly formatted at the LMHASH`n"$_"`n`nCheck your hashes and/or your colons`n"
		break
	}
	if($ntlmhash_check.length -ne 48){
		Write-Host "Line"$LineNum" is not properly formatted at the NTLMHASH`n"$_"`n`nCheck your hashes and/or your colons`n"
		break
	}
	if($salt_check.length -ne 16){
		Write-Host "Line"$LineNum" is not properly formatted at the SALT`n"$_"`n`nCheck your hashes and/or your colons`n"
		break
	}

	$LineNum=$LineNum+1
} 
 
#Start the big loop
Get-Content $args[0] | Foreach-Object {
	#Hash parsing method
	$username_to_crack = $_.Split(“:”)[0]
	$lmhash=$_.Split(“:”)[3]
	$ntlmhash=$_.Split(“:”)[4]
	$salt=$_.Split(“:”)[5]

	
	#Checks if the hash is already in john.pot
	$pot_file_loc = ""+$John_DIR+"john.pot"
	if(Test-Path($pot_file_loc)){
		$done = "false"
		Get-Content $pot_file_loc | Foreach-Object {
			$pot_hash_start = $_.Split("$")[3]
			$pot_hash = $pot_hash_start.Split(":")[0]
			$prev_pass = $pot_hash_start.Split(":")[1]
			
			if ($pot_hash -like $ntlmhash){
				$prev_cracked = "Previously Cracked: "+$username_to_crack+" "+$prev_pass+""
				$prev_cracked >> $file_to_write
				Write-Host ""$username_to_crack" "$pot_hash" is already in the Pot File"
				$done = "true"
			}
		}
	}	
	else{
		Write-Host "No john.pot file available."
		$done = "false"
	}
	
	if($done -like "false"){
	
	Write-Host ""$username_to_crack" is going to get cracked"
	
	#Writes the current hash that is getting cracked to a temp file
	$file_loc = ""+$(get-location)+"\current.txt"
	[system.io.file]::WriteAllText($file_loc, $_.TrimEnd())
	
	#Parses Half of the LM hash
	$HALFHASH = $lmhash.Substring(0,16)
	
	#Starts the rcrack lookups
	Write-Host "Cracking:"$HALFHASH
	$rcrack_command = ""+$rcrack_DIR+" -h "+$HALFHASH+" "+$rtables_DIR+" -o halfhash.txt"
	Invoke-Expression $rcrack_command

	#If no halfhash.txt, then write failure to file.
	if (Test-Path($half_hash_loc)){
	#Reads and parses rcrack output
		$Del_Half = "true"
		$seedin1 = Get-Content halfhash.txt
		$seed = $seedin1.Split(“:”)[1]
		Write-Host "Seed:"$seed

		#Sets your john directory and changes you to the john DIR
		$JOHN_DIR_CMD = "cd "+$John_DIR+""
		Invoke-Expression $JOHN_DIR_CMD
		
		#Runs the netntlm.pl for the first time
		$John_command1 = ""+$perl_DIR+" netntlm.pl --seed "+$seed+" --file "+$file_loc+""
		Invoke-Expression $John_command1 | Foreach-Object {
			$seed2 = $_.Split(" ")[0]
		}

		#Runs the netntlm.pl for the second time
		$John_command2 = ""+$perl_DIR+" netntlm.pl --seed "+$seed2+" --file "+$file_loc+""
		Invoke-Expression $John_command2 | Foreach-Object {
			if ($_ -like '*('+$username_to_crack+')*') { 
				$_ >> $file_to_write
			}
		}
	}
	else{
		Write-Host "The hash for "$username_to_crack" was not found in the rainbow tables."
		$hash_not_found = "The hash for "+$username_to_crack+" was not found in the rainbow tables."
		$hash_not_found >> $file_to_write
		$Del_Half = "false"
	}
	
	#Brings you back to the DIR you started in
	$go_home = 	"cd "+$home_DIR+""
	Invoke-Expression $go_home
	
	#Clean up the temp files
	if ($Del_Half -like "true"){
		Invoke-Expression "del halfhash.txt"
	}
	
	Invoke-Expression "del current.txt"
	}

}