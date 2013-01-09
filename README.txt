READ ME
----------------------------------------------------------------------------------
You need to specify your rcrack, john, and rainbow table directories in the script
----------------------------------------------------------------------------------

Usage: PS_MultiCrack.ps1 INPUT_FILE OUTPUT_FILE
or
Usage: PS_MultiCrack.sh INPUT_FILE OUTPUT_FILE


Hashes in the input file need to be in either format:
	Domain\User:::LMHASH:NTLMHASH:1122334455667788
	User::Domain:LMHASH:NTLMHASH:1122334455667788
	
The output file writes to the directory that you run this script from.

Latest Updates: (as of 01/09/2013)

	-Additional support for linux now
		-Same functionality, just now it's written in bash

	-No need for a functional netntlm.pl
		-I found people had issues getting it to work,
		 so I rewrote it in this script
	-Much cleaner output to the powershell window
		-I nulled the output for rcrack, so it looks better
	-Hashes can be either format listed above
	
If you find any issues in either script, please let me know.	