##########################################################################################
# PS_MultiCrack.ps1
#		Fully cracks LM Half Chall passwords from an input file using Rcrack_mt and John
#
# Usage: PS_MultiCrack.ps1 INPUT_FILE OUTPUT_FILE
#
# Requirements: 
#				-Rcrack, Rainbow tables, and John
#				-Also Powershell, but that should be obvious
#
# To Add:
#		 - Stats for number of hashes cracked, number not found, total time
#		 - Delete the previous temp files on startup
#		 - Add option to load a config file, or just take the RT and Rcrack paths as parameters
#
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
#Where your halflmchall Rainbow tables are
$rtables_DIR = "C:\tools\RainbowTables\halflmchall\"

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

#Just some global variables 
$LineNum=1
$LineValid="true"

#Verify the hashes in the file before trying to open them
Get-Content $args[0] | Foreach-Object {

	#Resets each iteration
	$input_type="DEFAULT"

	#Check if it's DOMAIN\User
	$username_check = $_.Split(“:”)[0]
	#Write-Host "Line"$username_check
	
	#Checks if the Domain is after the second :, if so, then it's John format
	$domain_check = $_.Split(“:”)[2]
	#Write-Host "Line"$domain_check
	
	#Length of 48
	$lmhash_check=$_.Split(“:”)[3]
	#Write-Host "Line"$lmhash_check
	
	#Length of 48
	$ntlmhash_check=$_.Split(“:”)[4]
	#Write-Host "Line"$ntlmhash_check
	
	#Length of 16
	$salt_check=$_.Split(“:”)[5]
	#Write-Host "Line"$salt_check
	
	
	if($domain_check.length -ge 1){
		$input_type="JOHN"
	}
	if (($username_check -notlike "*\*") -and ($input_type -eq"DEFAULT")){
		Write-Host "Line"$LineNum" is not properly formatted at the Domain\Username Add a \`n"$_"`nProper hash format is:`n Domain\USER:::LMHASH:NTLMHASH:1122334455667788`nor`n USER::Domain:LMHASH:NTLMHASH:1122334455667788`n"
		break
	}
	if($lmhash_check.length -ne 48){
		Write-Host "Line"$LineNum" is not properly formatted at the LMHASH`n"$_"`n`nCheck your hashes and/or your colons`nProper hash format is:`n Domain\USER:::LMHASH:NTLMHASH:1122334455667788`nor`n USER::Domain:LMHASH:NTLMHASH:1122334455667788`n"
		break
	}
	if($ntlmhash_check.length -ne 48){
		Write-Host "Line"$LineNum" is not properly formatted at the NTLMHASH`n"$_"`n`nCheck your hashes and/or your colons`nProper hash format is:`n Domain\USER:::LMHASH:NTLMHASH:1122334455667788`nor`n USER::Domain:LMHASH:NTLMHASH:1122334455667788`n"
		break
	}
	if($salt_check.length -ne 16){
		Write-Host "Line"$LineNum" is not properly formatted at the SALT`n"$_"`n`nCheck your hashes and/or your colons`nProper hash format is:`n Domain\USER:::LMHASH:NTLMHASH:1122334455667788`nor`n USER::Domain:LMHASH:NTLMHASH:1122334455667788`n"
		break
	}

	$LineNum=$LineNum+1
} 
 
#Start the big loop
Get-Content $args[0] | Foreach-Object {

	#Hash parsing method
	$username_to_crack = $_.Split(“:”)[0]
	$username = $username_to_crack.Split("\")[1]
	
	if($_.Split(“:”)[2] -ge 1){
		$username = $_.Split(“:”)[0]
		$username_to_crack = $_.Split(“:”)[2]+"\"+$_.Split(“:”)[0]
	}
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
				$prev_cracked | out-file -encoding ASCII -append $file_to_write
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
	#Corrects Cygwin errors
	$file_loc_mod = $file_loc -replace "\\", "/"
	$file_loc_mod = $file_loc_mod -replace "C\:", "/cygdrive/c"
	#Added line in here to rearrange the john formatted lines
	$HashToFile = ""+$username_to_crack+":::"+$lmhash+":"+$ntlmhash+":"+$salt+""
	[system.io.file]::WriteAllText($file_loc, $HashToFile.TrimEnd())
	
	#Parses Half of the LM hash
	$HALFHASH = $lmhash.Substring(0,16)
	
	#Starts the rcrack lookups
	$rcrack_command = ""+$rcrack_DIR+" -h "+$HALFHASH+" "+$rtables_DIR+" -o halfhash.txt"
	Invoke-Expression $rcrack_command|out-null

	#If no halfhash.txt, then write failure to file.
	if (Test-Path($half_hash_loc)){
	#Reads and parses rcrack output
		$Del_Half = "true"
		$seedin1 = Get-Content halfhash.txt
		$seed = $seedin1.Split(“:”)[1]
		
		#Sets your john directory and changes you to the john DIR
		$JOHN_DIR_CMD = "cd "+$John_DIR+""
		Invoke-Expression $JOHN_DIR_CMD
		
		#John.conf file created on the fly based on the seed
		$ConftoWrite = "[Incremental:LM]`nFile = lanman.chr`nMinLen = 1`nMaxLen = 7`nCharCount = 69`n`n[List.External:HalfLM]`nvoid init()`n{`n  word[14] = 0;`n}`n`nvoid filter()`n{`n  word[13] = word[6];`n  word[12] = word[5];`n  word[11] = word[4];`n  word[10] = word[3];`n  word[9] = word[2];`n  word[8] = word[1];`n  word[7] = word[0];`n  word[6] = '"+$seed[6]+"';`n  word[5] = '"+$seed[5]+"';`n  word[4] = '"+$seed[4]+"';`n  word[3] = '"+$seed[3]+"';`n  word[2] = '"+$seed[2]+"';`n  word[1] = '"+$seed[1]+"';`n  word[0] = '"+$seed[0]+"';`n}`n`n[List.Rules:Wordlist]`n:`n-c T0Q`n-c T1QT[z0]`n-c T2QT[z0]T[z1]`n-c T3QT[z0]T[z1]T[z2]`n-c T4QT[z0]T[z1]T[z2]T[z3]`n-c T5QT[z0]T[z1]T[z2]T[z3]T[z4]`n-c T6QT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]`n-c T7QT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]`n-c T8QT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]`n-c T9QT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]`n-c TAQT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]T[z9]`n-c TBQT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]T[z9]T[zA]`n-c TCQT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]T[z9]T[zA]T[zB]`n-c TDQT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]T[z9]T[zA]T[zB]T[zC]"

		#Writes the john.conf file
		if(test-path .\tmpcrack -pathType container){
			$ConftoWrite | out-file -encoding ASCII tmpcrack\john.conf
			new-item tmpcrack\john.dict -ItemType file|out-null
			new-item tmpcrack\john.session -ItemType file|out-null
		}
		else{
			#Makes the DIR and suppresses output
			mkdir .\tmpcrack |out-null
			$ConftoWrite | out-file -encoding ASCII tmpcrack\john.conf
			new-item tmpcrack\john.dict -ItemType file|out-null
			new-item tmpcrack\john.session -ItemType file|out-null
		}

		#Commands to execute for cracking with john
		$LMCracker = ".\john -format:netlm -config:tmpcrack/john.conf -external:HalfLM -incremental:LM -session:tmpcrack/john.session "+$file_loc_mod+""
		$LMShow = ".\john -format:netlm -show "+$file_loc_mod+""
		$NTLMCracker = ".\john -format:netntlm -config:tmpcrack/john.conf -wordlist:tmpcrack/john.dict --rules -user:"+$username_to_crack+" -session:tmpcrack/john.session "+$file_loc_mod+""

		#Crack the LM
		Invoke-Expression $LMCracker|out-null
		#Get the LM from the -show command
		Invoke-Expression $LMShow | Foreach-Object {
			$seed2 = $_.Split(":")[1]
			$seed2 | out-file -encoding ASCII -append tmpcrack\john.dict
		}
		#Crack the NTLM
		Invoke-Expression $NTLMCracker|out-null

		#Clean up the temp files
		Invoke-Expression "del tmpcrack\john.conf"
		Invoke-Expression "del tmpcrack\john.dict"
		Invoke-Expression "del tmpcrack\john.session"
		if(test-path .\tmpcrack\john.session.log){
			Invoke-Expression "del tmpcrack\john.session.log"
		}
		Invoke-Expression "rmdir tmpcrack"
				
		#Run john a third time to output the case-sensitive password for easier parsing
		$John_command3 = ".\john.exe -format:netntlm -show "+$file_loc_mod+""
		Invoke-Expression $John_command3 | Foreach-Object{
			if (($_.Split(":")[0] -like $username) -or ($_.Split(":")[0] -like $username_to_crack)) { 
				$to_Write = ""+$username_to_crack+" "+$_.Split(":")[1]+""
				$to_Write | out-file -encoding ASCII -append $file_to_write
			}
		}
	}
	else{
		Write-Host " The hash for "$username_to_crack" was not found in the rainbow tables."
		$hash_not_found = "The hash for "+$username_to_crack+" was not found in the rainbow tables."
		$hash_not_found | out-file -encoding ASCII -append $file_to_write
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