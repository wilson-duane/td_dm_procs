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
# CHANGE HISTORY
# -----------------
# 12-02-2015 PDN  Initial Version
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
    [parameter(Mandatory=$true)]
    [alias("d")]
    [string] $runDate,
    [alias("r")]
    $rerun)
    #cls
    #get current working directory
    $launchDir = $pwd


# ---------------------------------------------------------------------
# Set-up of common variables
# ---------------------------------------------------------------------
   
    $Script = gi($MyInvocation.InvocationName)
    $global:baseName = ($Script | select basename).basename
    $baseDrive = "R:\DEV\USDANLY"
    $Year= $runDate.substring(0,4)
    $Month=$runDate.substring(4,2)
    $Day=$runDate.substring(6,2)
  
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
    $libDir ="set up for domain/batch controller "
    $cfgDir = "set up for domain/batch controller "
    $statusDir = "$baseDrive\ops\status\"
    #$utilitiesDir="$baseDrive\USOPS\apps\TBSMUSDM\Utilities"
    
  
    #$sourceDir = 
    $targetDir = "$baseDrive\DATA\DYNAMIC\USTG_ST_DataStage\Output\"

# ---------------------------------------------------------------------
# Set-up DB configuration
# ---------------------------------------------------------------------
    
    #if SSIS package you may need the following
    $FileMask = "StressTestingAnalysis_Extract_toFTP_$Month$Year.csv"
    $DTSPackage="StressTestingAnalysis_ExtractTo_FTP.dtsx"
    #$appName = "INTRADER-Security" #so far this does not seem to be necessary

    #$DTSPackagePassword="baseball"
    #$DTSJobConfigDir="$baseDrive\Apps\TBSMUSDM\DTS_Config\"
    $DTSPackagesDir= "$baseDrive\APPS\USTG_ST_DataStage\SSISProjects\ST_Ftp_Jobs\ST_Ftp_Jobs\ST_Ftp_Jobs"
    $cm_sql_ustg="Data Source=$dbServerReport;Initial Catalog=ALM_Reporting_ST;Provider=SQLNCLI10.1;Integrated Security=SSPI;Auto Translate=False;Application Name=$AppName;"

# ---------------------------------------------------------------------
# Set-up email configuration
# ---------------------------------------------------------------------

    #Email specific data *****This has not been tested in powershell yet
    #$EmailServer="192.168.6.27"
    #$EmailTo="TBSMUS-SystemIssues@td.com"
    #$EmailFrom="TBSMUSDM-JS@td.com"

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

# ---------------------------------------------------------------------
# Start processing - anything you do here is temporary - copy any output and
# logs to appropriate final locations before cleaning up.
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# SSIS/SSAS/SSRS SQL job setup and execution
# 
# ---------------------------------------------------------------------
    #Example section to use for SSIS package execution
    
    writetoLog $logFile "INFO" "$appName Started"
    $DTSOUTFILE = "$targetDir$FileMask"
    $DTSOPTIONS = "/CHECKPOINTING OFF /Reporting E "
    $DTSDECRYPT = "/Decrypt $DTSPackagePassword"
    $DTSCONN1 = "/CONN `"cm_sql_USTG`";`"$cm_sql_USTG`""
    $DTSCONN2 = "/CONN `"ff_Extract`";`"$DTSOUTFILE`"" 
    $DTEXEC_path = "C:\Program Files\Microsoft SQL Server\100\DTS\Binn"
    $fullExecPath = "`"$DTEXEC_path\DTEXEC.exe`""
    $my_arguments = "/f `"$DTSPackagesDir\$DTSPackage`" $DTSCONN1 $DTSCONN2" # "$DTSOPTIONS

    
   writetoLog $logFile "INFO" "Start-Process -FilePath $fullExecPath -ArgumentList $my_arguments -PassThru -Wait -NoNewWindow"
    
   $proc = Start-Process -FilePath $fullExecPath -ArgumentList $my_arguments -PassThru -Wait -NoNewWindow
   if ($proc.ExitCode)
   {
      echo "error in process call" $proc.ExitCode
      writetoLog $logFile "ERROR" "Process failed exiting without cleanup."
      cp *.log $logDir
      touchFile $myFailFile
      Exit 1
       
   }
    cp $DTSOUTFILE .
    writetoLog $logFile "INFO" "$appName Completed"
    

# ---------------------------------------------------------------------
# command line job setup and execution
# ---------------------------------------------------------------------

    #check exit code ($proc.ExitCode)

    #if ($proc.ExitCode)
    #{
    #   echo "error in process call"
    #   writetoLog $logFile "ERROR" "Process failed exiting without cleanup"
    #   cp *.log $logDir
    #   touchFile $myFailFile
    #   Exit 1
    #   
    #}

# ---------------------------------------------------------------------
# if other jobs continue here
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# send files to ftp locations if necessary
# ---------------------------------------------------------------------   
    
    $ftpExecPath = "ftp.exe" 
    #---------------------------------
    # could do this in a read only static file
    $ftp_server = "open 49.80.166.78"
    $ftp_user = "user usto2356"
    $ftp_pwd = "h8N(w9Rt"
    #---------------------------------
    $ftp_dir = "cd Dropoff"
    $file_momentum_prefix = "TBSM-ADHOC."
    $putfile = $file_momentum_prefix + $FileMask
    cp $FileMask $putfile
    $file1 = "put " +$file_momentum_prefix + $FileMask
    #$file2 = "put TBSM-ADHOC.BNIN_TBSMUSDB_EXTRACT_C_MA.csv"
    $ftp_bye = "bye"
    #setup ftp config file from above
    $ftp_config = "ftpconfig.cfg"
    $ftp_server,$ftp_user,$ftp_pwd,$ftp_dir,$file1,$ftp_bye | out-file -filepath $ftp_config -encoding ASCII
    $ftp_arguments = "-n -i -s:" + $ftp_config
    $sendProc = Start-Process -FilePath $ftpExecPath -ArgumentList $ftp_arguments -PassThru -Wait
    #check exit code ($proc.ExitCode)

    if ($sendproc.ExitCode)
    {
       echo "error in process call"
       writetoLog $logFile "ERROR" "Process failed exiting without cleanup"
       cp *.log $logDir
       touchFile $myFailFile
       Exit 1
       
    }
    
# ---------------------------------------------------------------------
# put all output files into final locations
# ---------------------------------------------------------------------
   #example for copying files to $targetDir
    #cp $targetDir
    cp *.log $logDir
# ---------------------------------------------------------------------
# clean up and get out
# ---------------------------------------------------------------------
    
    cd $launchDir
    writetoLog $logFile "INFO" "Cleaning up"
    #rmdir $localDir -r -force
    touchFile $mySuccessFile
    rm $myTouchFile
    writetoLog $logFile "INFO" "process complete"
    


Exit 0