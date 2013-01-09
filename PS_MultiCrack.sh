#!/bin/bash

##########################################################################################
# PS_MultiCrack
#		Fully cracks LM Half Chall passwords from an input file using Rcrack_mt and John
#
# Usage: PS_MultiCrack.sh INPUT_FILE OUTPUT_FILE
#
# Requirements: 
#				-Rcracki_mt, Rainbow tables, and John
#
# To Add:
#		 - Stats for number of hashes cracked, number not found, total time
#		 - Delete the previous temp files on startup
#		 - Add option to load a config file, or just take the RT and Rcrack paths as parameters
#
#
# Originally written by Karl Fosaaen
#	Twitter: @kfosaaen
# Translated to bash by Ryan Gandrud
#	Twitter: @siegenapster
#
##########################################################################################

#Setup your local directories for stuff here
#This should be your John\Run directory
John_DIR=~/Desktop/Scripts/john-1.7.9-jumbo-6/run
#Where your rcrack_mt.exe lives
rcrack_DIR=~/Desktop/rcracki_mt_0.7.0_src/rcracki_mt/rcracki_mt

#Where your halflmchall Rainbow tables are
rtables_DIR=~/Desktop/Cracking/halflmchall

#Checks your ARGS
if [ $# -eq 2 ]
then
	input_file=$1
	output_file=$2
	#Writes your output file to the dir that you run this from
	home_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	file_to_write="$home_DIR/$output_file"
	half_hash_loc="$home_DIR/halfhash.txt"
else
	if [ $# -eq 1 ]
	then
		echo "No second argument supplied"
	fi
	if [ $# -eq 0 ]
	then
		echo "No arguments supplied"
	fi
	if [ $# -gt 2 ]
	then
		echo "Too many arguments supplied"
	fi
fi

#Just some global variables 
LineNum=1
LineValid="true"

#Verify the hashes in the file before trying to open them
while read -r p; do
#The read -r makes backslash does not act as an escape character.

	#Resets each iteration
	input_type="DEFAULT"


	#Check if it's DOMAIN\User
	username_check=$(echo $p | cut -f1 -d:)
	#Write-Host "Line"$username_check
	
	#Checks if the Domain is after the second :, if so, then it's John format
	domain_check=$(echo $p | cut -f3 -d:)
	#Write-Host "Line"$domain_check
	
	#Length of 48
	lmhash_check=$(echo $p | cut -f4 -d:)
	#Write-Host "Line"$lmhash_check
	
	#Length of 48
	ntlmhash_check=$(echo $p | cut -f5 -d:)
	#Write-Host "Line"$ntlmhash_check
	
	#Length of 16
	salt_check=$(echo $p | cut -f6 -d:)
	#Write-Host "Line"$salt_check

	#Check if third field is empty. If so, then format is John
	if [ ${#domain_check} -ge 1 ]
	then
		input_type="JOHN"
	fi

	#Check if username contains \. If so, if input_type is still DEFAULT, then there is an error in formatting.
	if [[ ! "$username_check" == *'\'* ]]
	then
		if [ $input_type == "DEFAULT" ]
		then
			echo -e "Line"$LineNum" is not properly formatted at the Domain\Username. Add a \\ \n\n$p\n\nProper hash format is:\n\nDomain\USER:::LMHASH:NTLMHASH:1122334455667788\nor\nUSER::Domain:LMHASH:NTLMHASH:1122334455667788\n"
		exit
		fi
		
	fi

	#Check if lmhash_check is a valid lm hash length
	if [ ${#lmhash_check} -ne 48 ]
	then
		echo -e "Line $LineNum is not properly formatted at the LMHASH.\n\n$p\n\nCheck your hashes and/or your colons.\nProper hash format is:\n\nDomain\USER:::LMHASH:NTLMHASH:1122334455667788\nor\nUSER::Domain:LMHASH:NTLMHASH:1122334455667788\n"
	exit
	fi

	if [ ${#ntlmhash_check} -ne 48 ]
	then
		echo -e "Line $LineNum is not properly formatted at the NTLMHASH.\n\n$p\n\nCheck your hashes and/or your colons.\nProper hash format is:\n\nDomain\USER:::LMHASH:NTLMHASH:1122334455667788\nor\nUSER::Domain:LMHASH:NTLMHASH:1122334455667788\n"
	exit
	fi

	if [ ${#salt_check} -ne 16 ]
	then
		echo -e "Line $LineNum is not properly formatted at the SALT.\n\n$p\n\nCheck your hashes and/or your colons.\nProper hash format is:\n\nDomain\USER:::LMHASH:NTLMHASH:1122334455667788\nor\nUSER::Domain:LMHASH:NTLMHASH:1122334455667788\n"
	exit
	fi

	LineNum=$(($LineNum + 1))

#This is the input file for the while loop above
done < $input_file

#Start the big loop
while read -r p; do

	#parsing the hash
	domain=$(echo $p | cut -f3 -d:)
	lmhash=$(echo $p | cut -f4 -d:)
	ntlmhash=$(echo $p | cut -f5 -d:)
	salt=$(echo $p | cut -f6 -d:)
	if [ ${#domain} -ge 1 ]
	then
		username=$(echo $p | cut -f1 -d:)
		domain=$(echo $p | cut -f3 -d:)
		username_to_crack=$username'\'$domain
		correct_string=$username_to_crack":::"$lmhash":"$ntlmhash":"$salt
	else
		username_to_crack=$(echo $p | cut -f1 -d:)
		correct_string=$p
	fi

	#Check if the hash is already in john.pot
	pot_file_loc=$John_DIR"/john.pot"
	if [ -a $pot_file_loc ]
	then
		done="false"
		while read -r q; do
			#Parsing the john.pot file
			pot_hash_start=$(echo $q | cut -f4 -d$)
			pot_hash=$(echo $pot_hash_start | cut -f1 -d:)
			prev_pass=$(echo $pot_hash_start | cut -f2 -d:)

			if [ "$pot_hash" == "$ntlmhash" ]
			then
				prev_cracked="Previously Cracked:"$username_to_crack" "$prev_pass
				`echo $prev_pass"     ("$username_to_crack")" >> $file_to_write`
				echo -e $prev_cracked
				done="true"
			fi
		done < $pot_file_loc
	else
		echo "No john.pot file available"
		done="false"
	fi

	#If hash not found in john.pot, start the cracking loop
	if [ $done == "false" ]
	then
		echo "$username_to_crack is going to get cracked"
		file_loc=$home_DIR"/current.txt"
		echo $correct_string > $file_loc

		HALFHASH=${lmhash:0:16}
		rcrack_command=$rcrack_DIR" -h "$HALFHASH" "$rtables_DIR" -o halfhash.txt"
		rcrack=`$rcrack_command`
		#If the halfhash.txt is created, then continue cracking
		if [ -a $half_hash_loc ]
		then
			#Parse out the seed to pipe into john
			Del_Half="true"
			while read -r z; do
				seedin1=$z
				seed=$(echo $z | cut -f2 -d:)
			done < $half_hash_loc

			cd $John_DIR

			#Writing own custom john.conf file for LM cracking
			Conftowrite="[Incremental:LM]\nFile = lanman.chr\nMinLen = 1\nMaxLen = 7\nCharCount = 69\n\n[List.External:HalfLM]\nvoid init()\n{\n  word[14] = 0;\n}\n\nvoid filter()\n{\n  word[13] = word[6];\n  word[12] = word[5];\n  word[11] = word[4];\n  word[10] = word[3];\n  word[9] = word[2];\n  word[8] = word[1];\n  word[7] = word[0];\n  word[6] = '"${seed:6:1}"';\n  word[5] = '"${seed:5:1}"';\n  word[4] = '"${seed:4:1}"';\n  word[3] = '"${seed:3:1}"';\n  word[2] = '"${seed:2:1}"';\n  word[1] = '"${seed:1:1}"';\n  word[0] = '"${seed:0:1}"';\n}\n\n[List.Rules:Wordlist]\n:\n-c T0Q\n-c T1QT[z0]\n-c T2QT[z0]T[z1]\n-c T3QT[z0]T[z1]T[z2]\n-c T4QT[z0]T[z1]T[z2]T[z3]\n-c T5QT[z0]T[z1]T[z2]T[z3]T[z4]\n-c T6QT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]\n-c T7QT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]\n-c T8QT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]\n-c T9QT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]\n-c TAQT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]T[z9]\n-c TBQT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]T[z9]T[zA]\n-c TCQT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]T[z9]T[zA]T[zB]\n-c TDQT[z0]T[z1]T[z2]T[z3]T[z4]T[z5]T[z6]T[z7]T[z8]T[z9]T[zA]T[zB]T[zC]"
		
			john_temp_folder=$John_DIR"/tmpcrack"
			if [ -a $john_temp_folder ]
			then
				echo -e $Conftowrite > tmpcrack/john.conf
				touch tmpcrack/john.dict
				touch tmpcrack/john.session
			else
				mkdir $john_temp_folder
				echo -e $Conftowrite >> tmpcrack/john.conf
				touch tmpcrack/john.dict
				touch tmpcrack/john.session
			fi

			#Commands to execute for cracking with john
			LMCrackerComm="./john -format:netlm -config:tmpcrack/john.conf -external:HalfLM -incremental:LM -session:tmpcrack/john.session $file_loc"
			LMShowComm="./john -format:netlm -show $file_loc"
			NTLMCrackerComm="./john -format:netntlm -config:tmpcrack/john.conf -wordlist:tmpcrack/john.dict --rules -user:$username_to_crack -session:tmpcrack/john.session $file_loc"

			#Crack the LM
			LMCracker=`$LMCrackerComm`
			#Get the LM from the -show command
			LMShow=`$LMShowComm`
			seed2=$(echo $LMShow | cut -f2 -d:)
			echo $seed2 >> tmpcrack/john.dict

			#Crack the NTLM
			NTLMCracker=`$NTLMCrackerComm > /dev/null`

			#Clean up temp files
			`rm -rf tmpcrack`

			#Run john a third time to output the case-sensitive password for easier parsing
			John_command3="./john -format:netntlm -show "$file_loc
			ntlm_return=`$John_command3`
			final_username=$(echo $ntlm_return | cut -f1 -d:)
			final_pass=$(echo $ntlm_return | cut -f2 -d:)
			if [ "$final_username" == "$username" ]
			then
				echo -e $final_pass"     ("$username")" >> $file_to_write
				echo -e "\nSuccessfully cracked "$username_to_crack" - Password is "$final_pass"\n"
			elif [ "$final_username" = "$username_to_crack" ]
			then
				echo -e $final_pass"     ("$username_to_crack")" >> $file_to_write
				echo -e "\nSuccessfully cracked "$username_to_crack" - Password is "$final_pass"\n"
			fi
		#If the halflm is not found in the rainbow tables
		else
			echo -e "The hash for "$username_to_crack" was not found in the rainbow tables."
			echo -e "The hash for "$username_to_crack" was not found in the rainbow tables." >> $file_to_write
			Del_Half="false"
			
		fi
		
		#Clean up temp files
		cd $home_DIR
		if [ $Del_Half == "true" ]
		then
			`rm halfhash.txt`
		fi
		`rm current.txt`
	fi


#This is the input file for the while loop above
done < $input_file

