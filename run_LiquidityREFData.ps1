# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
# USE Case Number:  ????
# Job Description: 
#                  
#
# Usage:  <Command File Name> 1 2
#  1 Environment Mandatory parameter Date -- Format YYYYMMDD
#  2 Rerun      Optional Parameter (P, R) -- Set for Rerun of data from manual file P)rimary R)erun (Default = P)
#  Note: The variables in the manual section below will need to be filed out correctly
# Creation Date:   
# Author:          
# ------------------------------------------------------------------------
# ------------------------------------------------------------------------

# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
# Things to build on for Template
# 1. Better error checking 
# 2. Notifications (email) 
# 3. Increase logging capabilities (add in verbose logging)
# 4. Move functions into modules
# 5. Provide more functions for dates (prevDate, prevMonth, prevQuarter)
# 6. build in File control system support
# 7. option to log to tables instead of/along with files
# ------------------------------------------------------------------------
# ------------------------------------------------------------------------




Param(
    
    [alias("d")]
    [string] $runDate,
    [alias("r")]
    $rerun)
    #cls
    #get current working directory
    $launchDir = $pwd


#call function send_email_on_error "header line" "message"
function send_email_on_error ([string] $header, [string] $message, [string] $workingEnv)
{

    #$mailExecDir="L:\DEV\USDANLY\OPS\bin\3rdParty"
    $mailExecDir="C:_Apps\Bmail" #use this until we can get security issues fixed on shared drives
    $emailExecPath = "$mailExecDir\BMAIL.exe"
    
    if ($workingEnv -eq "PRD")
    {
        $EmailServer="billingrelay.tdbank.ca"
        $EmailTo="TBSMUS-SystemIssues@td.com"
        $EmailFrom="TBSMUSDM-JS@td.com" 
    

        $emailArguments = @("-s", $EmailServer, "-t", $EmailTo, "-f", $EmailFrom, "-a", $header, "-b", $message, "-c")
        $proc = Start-Process -FilePath $emailExecPath -ArgumentList $emailArguments -PassThru -Wait
    }
    elseif ($workingEnv -eq "PAT")
    {
        $EmailServer="patrelay.tdbank.ca"
        $EmailTo="treusj2@p-tdbfg.com"
        $EmailFrom="treusj2@p-tdbfg.com" 
    

        $emailArguments = @("-s", $EmailServer, "-t", $EmailTo, "-f", $EmailFrom, "-a", $header, "-b", $message, "-c")
        $proc = Start-Process -FilePath $emailExecPath -ArgumentList $emailArguments -PassThru -Wait
        
    }
    else
    {
        echo "no email set up for this environment"
    }
}
Try
{
# ---------------------------------------------------------------------
# Set-up of common variables
# ---------------------------------------------------------------------
   
    $Script = gi($MyInvocation.InvocationName)
    $global:baseName = ($Script | select basename).basename
    $baseDrive = "L:\DEV\USDANLY"
    #$baseDrive = "P:\Desktop\test\TestEnv"
    #need to make runDate based on time running if $runDate is not supplied ($rundate will be supplied if doing rerun by hand for previous date)
    if (!($runDate))
    {
        $runDate = Get-Date -UFormat "%Y%m%d"
    }

# ---------------------------------------------------------------------
# Set-up logging and other utils
# ---------------------------------------------------------------------
    $logDir = "$baseDrive\ops\logs"
    if(!(Test-Path $logDir))
    {
        md $logDir
    }
    $logFile= "$logDir\$baseName.$PID.$runDate.log"
# ---------------------------------------------------------------------
# load shell utility functions
# ---------------------------------------------------------------------

    . $baseDrive\OPS\script\shellUtils.ps1
    writetoLog $logFile "INFO" " starting process"

# ---------------------------------------------------------------------
# set up domain specific items
# ---------------------------------------------------------------------
    $EmailServer=""
    $workingEnv = ""

    $theDomain = (gwmi win32_computersystem).domain
    echo $theDomain
    if ($theDomain -eq "tdbfg.com")
    {
        echo "in production"
        $workingEnv = "PRD"
        $dbServerStage = "bfsdprsc01bwus2.tdbfg.com,3341"
        $dbServerReport = "absdpssca0bwus2.tdbfg.com,3341"
        $dbUser = "a-proc-us-tbsmus"
        $EmailServer="billingrelay.tdbank.ca"
        $EmailTo="TBSMUS-SystemIssues@td.com"
        $EmailFrom="TBSMUSDM-JS@td.com"
    }
    elseif ($theDomain -eq "p-tdbfg.com")
    {
        echo "in PAT"
        $workingEnv = "PAT"
        $dbServerStage = "BFSDARCP01BWUS2.p-tdbfg.com, 3341"
        $dbServerReport = "ABSDASCPA0BWUS2.p-tdbfg.com,3341"
        $dbUser = "a-proc-us-tbsmus.p-tdbfg.com"
        
    }
    elseif ($theDomain -eq "d2-tdbfg.com")
    {
        echo "in Development"
        $workingEnv = "DEV"
        $dbServerStage = "ABSDSBCP01BWUS2.d2-tdbfg.com"
        $dbServerReport = "ABSDSBCP01BWUS2.d2-tdbfg.com"
        $dbUser = "d-proc-us-tbsmus"
        
    }
    elseif ($theDomain -eq "bkng.net")
    {
        echo "in production"
        $workingEnv = "PRD"
        $dbServerStage = "bfsdprsc01bwus2.tdbfg.com,3341"
        $dbServerReport = "absdpssca0bwus2.tdbfg.com,3341"
        $dbUser = "a-proc-us-tbsmus"
        $EmailServer="billingrelay.tdbank.ca"
        $EmailTo="TBSMUS-SystemIssues@td.com"
        $EmailFrom="TBSMUSDM-JS@td.com"
    }
    else
    {
        echo "in unknown domain"
        exit 1
    }
# ---------------------------------------------------------------------
# Set-up Network Drives
# ---------------------------------------------------------------------
   
    $binDir = "$baseDrive\ops\bin\"
    $libDir ="$baseDrive\ops\lib\"
    $cfgDir = "$baseDrive\ops\cfg\"
    $statusDir = "$baseDrive\ops\status\"
    $utilitiesDir="M:FINANCE\TAAS\Systems\ProductionEnvironments\USOPS\apps\TBSMUSDM\Utilities"
    $emailExecPath = "$utilitiesDir\BMAIL.exe"
    
    #Final Data Locations
    $sourceDataDir = "U:\TREASURY\Liquidity\Vision\non-system data and reference tables\non_system_USTS"
    $targetInputDataDir = "M:FINANCE\TAAS\Systems\ProductionEnvironments\LIQ_REFERENCE\Import_Files" #final location of input files that were to be processed.
    $targetDir = "M:FINANCE\TAAS\Systems\ProductionEnvironments\LIQ_REFERENCE\Export_Files"  #final location or archive of all output data.
    
    #Test Data Locations
    #$sourceDataDir = "P:\Desktop\test\VisionCrap\BaseFiles\non-system data and reference tables\non_system_USTS"
   
    #$targetDir = "P:\Desktop\test\VisionCrap\Export_Files"
    #$targetInputDataDir = "P:\Desktop\test\VisionCrap\Input_Files"
# ---------------------------------------------------------------------
# Set-up DB configuration
# ---------------------------------------------------------------------
    
    #if SSIS package you may need the following
    #$FileMask="ff_Extract_TaxReport$runDate.txt"
    #$DTSPackage="TaxReporting.dtsx"
    #$appName = "INTRADER-Security" #so far this does not seem to be necessary

    #$DTSPackagePassword="baseball"
    #$DTSJobConfigDir="$baseDrive\Apps\TBSMUSDM\DTS_Config\"
    #$DTSPackagesDir= "$baseDrive\APPS\USTG_ST_DataStage\SSISProjects\DataStage_PROD\ST_DataStage_Prod_Transfer_Job"
    #$cm_sql_ustg="Data Source=$dbServerReport;Initial Catalog=ALM_Reporting_ST;Provider=SQLNCLI10.1;Integrated Security=SSPI;Auto Translate=False;Application Name=$AppName;"


# ---------------------------------------------------------------------
# Set-up email configuration
# ---------------------------------------------------------------------

    
    #server setup by domain above.
    



# ---------------------------------------------------------------------
# Set-up and move into run directory
# ---------------------------------------------------------------------

    $localDir= "$baseDrive\ops\run\$baseName.$PID.$runDate"

# ---------------------------------------------------------------------
# Set-up Job status files
# ---------------------------------------------------------------------
    $touchFileBase = "$statusDir$baseName.$runDate"
    $mytouchFile = "$touchFileBase.touch"
    $mySuccessFile = "$touchFileBase.OK"
    $myFailFile = "$touchFileBase.FAIL"

    touchFile $mytouchFile
 
    writetoLog $logFile "INFO" "changing to temp directory $localDir"
    if (!(Test-Path $localDir))
    {
        #echo "couldn't find the directory"
        md $localDir
    }
    cd $localDir
    cp "$binDir\NSDC\mapping.json" $localDir
# ---------------------------------------------------------------------
# Start processing - anything you do here is temporary - copy any output and
# logs to appropriate final locations before cleaning up.
# ---------------------------------------------------------------------
    $progInputPath = ".\input"
    $progOutputPath = ".\output"
    $tempInputPath = ".\tmp"
    $tempOutputPathUSTG1 = ".\USTG1"
    $tempOutputPathUSTG2 = ".\USTG2"
    $tempOutputPathVision = ".\Vision"
    mkdir $progInputPath
    mkdir $progOutputPath
    mkdir $tempOutputPathUSTG1
    mkdir $tempOutputPathUSTG2
    mkdir $tempOutputPathVision
    mkdir $tempInputPath
  
    Copy-Item -Path $sourceDataDir\IHCVSN* -Destination $progInputPath
    writetoLog $logFile "INFO" "got input files"
   
  
    

# ---------------------------------------------------------------------
# SSIS/SSAS/SSRS SQL job setup and execution
# 
# ---------------------------------------------------------------------
    #Example section to use for SSIS package execution
    
    #writetoLog $logFile "INFO" "$appName Started"
    #$DTSOPTIONS = "/CHECKPOINTING OFF /Reporting E "
    #$DTSDECRYPT = "/Decrypt $DTSPackagePassword"
    #$DTSCONN1 = "/CONN `"cm_sql_USTG`";`"$cm_sql_USTG`""
    #$DTSCONN2 = "/CONN `"ff_Extract`";`"$FileMask`"" 
    #$DTEXEC_path = "C:\Program Files\Microsoft SQL Server\100\DTS\Binn"
    #$fullExecPath = "`"$DTEXEC_path\DTEXEC.exe`""
    #$my_arguments = "/f `"$DTSPackagesDir\$DTSPackage`" $DTSCONN1 $DTSCONN2" # "$DTSOPTIONS

    
    #writetoLog $logFile "INFO" "Start-Process -FilePath $fullExecPath -ArgumentList $my_arguments -PassThru -Wait -NoNewWindow"
    
    #$proc = Start-Process -FilePath $fullExecPath -ArgumentList $my_arguments -PassThru -Wait -NoNewWindow
    #if ($proc.ExitCode)
    #{
    #   echo "error in process call" $proc.ExitCode
    #   writetoLog $logFile "ERROR" "Process failed exiting without cleanup."
    #   cp *.log $logDir
    #   touchFile $myFailFile
    #   Exit 1
       
    #}

    #writetoLog $logFile "INFO" "$appName Completed"


# ---------------------------------------------------------------------
# command line job setup and execution
# ---------------------------------------------------------------------
    #example
    $executable = "NSDC\NSDC.exe"
    $fullExecPath = $binDir + $executable
    #need to loop through each file separately to ensure that all are successful (and that we know each one that isn't on failures)
    $myExitCode = 0
    echo "the input path is $progInputPath"
    $theFiles = Get-ChildItem $progInputPath  
    Foreach ($file in $theFiles) 
    {
    echo "the file to process is $file"
        #$filename = $file.FullName
        #need to determine which files go to which output location for later FTP.
        if ($file -like '*FHLBDBT*' -Or $file -like '*IntrCoCapAct*' -Or $file -like '*PrntCoDbt*' )
        {
            $myOutPath = $tempOutputPathUSTG2
        }
        elseif ($file -like '*AssetHairCut*' -Or $file -like '*BrokeredAccts*' -Or $file -like '*CommitMapping*' -Or $file -like '*FHLBLoansBlnkt*')
        {
            $myOutPath = $tempOutputPathUSTG1
        }
        elseif ($file -like '*CustMappingACCT*' -Or $file -like '*CustMappingNAICS*' -Or $file -like '*CustMappingTIN*')
        {
            $myOutPath = $tempOutputPathUSTG1
        }
        elseif ($file -like '*DepTypeMapping*' -Or $file -like '*EntityMapping*' -Or $file -like '*ManagedAccts*' -Or $file -like '*TranCodes*')
        {
            $myOutPath = $tempOutputPathUSTG1
        }
        else
        {
            $myOutPath = $tempOutputPathVision
        }
        echo "cp $progInputPath\$file $tempInputPath"
        $fileBaseName = (Get-Item $progInputPath\$file).BaseName
        $fileExtension = (Get-Item $progInputPath\$file).Extension
        $dateBasedFile = $fileBaseName + "_" + $runDate + $fileExtension
        echo $fileBaseName
        echo $fileExtension
        echo $dateBasedFile

        cp $progInputPath\$file $tempInputPath\$dateBasedFile  #need to add runDate to the filenames here.
    
        

        $my_arguments = @("-i",$tempInputPath,"-o", $myOutPath)
        
        writetoLog $logFile "INFO" "running executable: $fullExecPath $my_arguments -PassThru -Wait"
        writetoLog $logFile "INFO" "running for input file $file"
        echo "INFO" "process call: Start-Process -FilePath $fullExecPath -ArgumentList $my_arguments -PassThru -Wait"
        echo $fullExecPath
        echo $my_arguments

       
        $proc = Start-Process -FilePath $fullExecPath -ArgumentList $my_arguments -PassThru -Wait -NoNewWindow
        #check exit code ($proc.ExitCode)
        #if exit code is fail then write message to logFile and continue to next file.
        if ($proc.ExitCode)
        {
            echo "error in process call"
            writetoLog $logFile "ERROR" "Process failed (exit code $proc.ExitCode) on processing file: $file" 
            $myExitCode = 1    
       
        }
        cp $tempInputPath\* $targetInputDataDir
        rm $tempInputPath\*
    }


    


    if ($myExitCode)
    {
      
       echo "error in process call"
       writetoLog $logFile "ERROR" "Process failed (exit code $proc.ExitCode) exiting without cleanup" 
       #need to send email here if error
       if ($workingEnv -eq "PRD")
       {
        
            $message = "`"One or more files failed conversion please see logFile `""
            $header = "`"FAIL: $global:baseName`""
            send_email_on_error $header $message $workingEnv
            #$emailArguments = @("-s", $EmailServer, "-t", $EmailTo, "-f", $EmailFrom, "-a", $header, "-b", $message, "-c")
            # $proc = Start-Process -FilePath $emailExecPath -ArgumentList $emailArguments -PassThru -Wait

       }

       cp *.log $logDir
       touchFile $myFailFile
       Exit 1
    }
    #if all went well we should have 3 directories of output data that now needs to be transferred to separate inboxes.


# ---------------------------------------------------------------------
# if other jobs continue here
# ---------------------------------------------------------------------




# ---------------------------------------------------------------------
# put all output files into final locations
# ---------------------------------------------------------------------
   #example for copying files to $targetDir
   cp $tempOutputPathUSTG1\* $targetDir
   cp $tempOutputPathUSTG2\* $targetDir
   #cp $tempOutputPathVision\* $targetDir
   #cp $progInputPath\* $targetInputDataDir
   #this will include some archiving for this set of processes.
    
# ---------------------------------------------------------------------
# send files to ftp locations if necessary
# ---------------------------------------------------------------------   
    #going to be at least 3 sets of ftps for this process....all will be using sftp to different "mailboxes" - accounts and directories


    $ftpExecPath = "`"C:\Program Files (x86)\winscp\winscp.com`"" 
    #---------------------------------
    
    #$ftp_server = "mfttiisa.tdbank.ca"
    #$ftp_port = "10022"
    #$ftp_user = "XM0KC601"
    #$ftp_pwd = "Itdd5AmX"
    #---------------------------------
   
    writetoLog $logFile "INFO" "ftping data REF Data to BLDS0KC6"
    $ftp_auguments = ""
    if ($workingEnv -eq "PAT")
    {
        $ftp_arguments = @("/command", "`"option batch abort`"", "`"option confirm off`"", "`"open -implicit sftp://XM0KC601:Itdd5AmX@mfttiisa.tdbank.ca:10022`"", "`"mput USTG1\* /BLDS0KC6/ -resumesupport=off`"", "`"exit`"")
    }
    elseif ($workingEnv -eq "PRD")
    {
        #$ftp_arguments = @("/command", "`"option batch abort`"", "`"option confirm off`"", "`"open -implicit sftp://XM0KC601:Itdd5AmX@mfttiisa.tdbank.ca:10022`"", "`"mput USTG1\* /BLDS0KC6/ -resumesupport=off`"", "`"exit`"")
 
        $ftp_arguments = @("/command", "`"option batch abort`"", "`"option confirm off`"", "`"open -implicit sftp://XM0KC601:Itdd5AmX@mfttiisp.tdbank.ca:10022`"", "`"mput USTG1\* /BLDS0KC6/ -resumesupport=off`"", "`"exit`"")
    }
   
    writetoLog $logFile "INFO" "running executable: $ftpExecPath $ftp_arguments -PassThru -Wait"
    
    echo "INFO" "process call: Start-Process -FilePath $ftpExecPath -ArgumentList $ftp_arguments -PassThru -Wait"
    
    $sendProc = Start-Process -FilePath $ftpExecPath -ArgumentList $ftp_arguments -PassThru -Wait -NoNewWindow -RedirectStandardOutput ftpREFout.txt -RedirectStandardError ftpREFerr.txt
    # check exit code ($proc.ExitCode)

    if ($proc.ExitCode)
    {
        echo "error in process call"
       writetoLog $logFile "ERROR" "ftp process failed for inbox BLDS0KC6 exiting without cleanup"
       $message = "`"ftp process failed for inbox BLDS0KC6 exiting `""
       $header = "`"FAIL: $global:baseName`""
       send_email_on_error $header $message $workingEnv
       
       cp *.log $logDir
       touchFile $myFailFile
       $myExitCode = 1
       Exit 1
    }

    writetoLog $logFile "INFO" "ftping data SUPX Data to BLDS0KCL"
    $ftp_auguments = ""
    if ($workingEnv -eq "PAT")
    {
        $ftp_arguments = @("/command", "`"option batch abort`"", "`"option confirm off`"", "`"open -implicit sftp://XM0KC601:Itdd5AmX@mfttiisa.tdbank.ca:10022`"", "`"mput USTG2\* /BLDS0KCL/ -resumesupport=off`"", "`"exit`"")
    }
    elseif ($workingEnv -eq "PRD")
    {
        #$ftp_arguments = @("/command", "`"option batch abort`"", "`"option confirm off`"", "`"open -implicit sftp://XM0KC601:Itdd5AmX@mfttiisa.tdbank.ca:10022`"", "`"mput USTG2\* /BLDS0KCL/ -resumesupport=off`"", "`"exit`"")
 
        $ftp_arguments = @("/command", "`"option batch abort`"", "`"option confirm off`"", "`"open -implicit sftp://XM0KC601:Itdd5AmX@mfttiisp.tdbank.ca:10022`"", "`"mput USTG2\* /BLDS0KCL/ -resumesupport=off`"", "`"exit`"")
    }
    writetoLog $logFile "INFO" "running executable: $ftpExecPath $ftp_arguments -PassThru -Wait"
    
    echo "INFO" "process call: Start-Process -FilePath $ftpExecPath -ArgumentList $ftp_arguments -PassThru -Wait"
    
    $sendProc = Start-Process -FilePath $ftpExecPath -ArgumentList $ftp_arguments -PassThru -Wait -NoNewWindow -RedirectStandardOutput ftpSUPXout.txt -RedirectStandardError ftpSUPXerr.txt
    # check exit code ($proc.ExitCode)
    # probably need to read the ftp*out.txt files to determine if there really was an error in the ftp since the process will exit success even if ftps have failed to transmit.

    if ($proc.ExitCode)
    {
       echo "error in process call"
       writetoLog $logFile "ERROR" "ftp process failed for inbox BLDS0KCL exiting without cleanup"
       $message = "`"ftp process failed for inbox BLDS0KCL exiting `""
       $header = "`"FAIL: $global:baseName`""
       send_email_on_error $header $message $workingEnv
       cp *.log $logDir
       touchFile $myFailFile
       $myExitCode = 1
       Exit 1
    }

}
Catch
{
    
    #writeLog $logFile "ERROR" "unknown exception caught, exiting"
    #send email here as well.
    echo "unknown exception caught, exiting"
    echo $_.Exception.GetType().FullName, $_.Exception.Message
    echo $_.Exception | format-list -force
    $message = "`"unknown exception caught, exiting `""
    $header = "`"FAIL: $global:baseName`""
    send_email_on_error $header $message $workingEnv
    Exit 1
}
# ---------------------------------------------------------------------
# clean up and get out
# ---------------------------------------------------------------------
    
writetoLog $logFile "INFO" "Process complete, Cleaning up"
cp *.log $logDir
cd $launchDir
rmdir $localDir -r -force
touchFile $mySuccessFile
rm $myTouchFile

Exit 0