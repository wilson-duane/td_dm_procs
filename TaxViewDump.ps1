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
    



# ---------------------------------------------------------------------
# Set-up logging
# ---------------------------------------------------------------------
$logDir = "$baseDrive\ops\logs"
if(!(Test-Path $logDir))
  {
    md $logDir
  }
$logFile= "$logDir\$baseName.$PID.$runDate.log"
Function touchFile {set-content -Path ($args[0]) -Value ($null)}
Function writetoLog
{
<#
  .SYNOPSIS
  function to write a new entry to the log file
  .DESCRIPTION
  Send in the log file name, message type, and message.  Log message will be written to the log file
  File should be in the standard log file directory.  Naming convention is $baseProcessName.$PID.runDate.log
  Type can be "INFO", "WARNING", "ERROR"
  Message is a string
  
  format of log message
  $type::$processName::PID:$PID::$date/time::$message
  INFO::blah::PID:3936::2015-04-15T12:34:35.1717799-04:00:: starting process
  .EXAMPLE
  writetoLog "c:\local\logs\logfile.log" "INFO" "message" 
  .EXAMPLE
  writetoLog $logFile "ERROR" "message" 
  .PARAMETER logFile
  full path to the logFile
  .PARAMETER type
  "INFO", "WARNING", "ERROR"
  .PARAMETER message
  free form string message contents
  #>
  param ([string]$outfile, [string]$type, [string]$message)
  
  
  $time = Get-Date -f o
  $content = "$type::$global:baseName::PID:$PID::$time::$message"
   
  Add-Content -Path $outfile -Value $content
}
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

    #$sourceDir
    $targetDir = "R:\DEV\USDANLY\DATA\DYNAMIC\USTG_ST_DataStage\Output"
# ---------------------------------------------------------------------
# Set-up DB configuration
# ---------------------------------------------------------------------
    #if SSIS package you may need the following
    $FileMask="ff_Extract_TaxReport$runDate.txt"
    $DTSPackage="TaxReporting.dtsx"
    $appName = "INTRADER-Security" #so far this does not seem to be necessary

    #$DTSPackagePassword="baseball"
    #$DTSJobConfigDir="$baseDrive\Apps\TBSMUSDM\DTS_Config\"
    $DTSPackagesDir= "$baseDrive\APPS\USTG_ST_DataStage\SSISProjects\DataStage_PROD\ST_DataStage_Prod_Transfer_Job"
    $cm_sql_ustg="Data Source=$dbServerReport;Initial Catalog=ALM_Reporting_ST;Provider=SQLNCLI10.1;Integrated Security=SSPI;Auto Translate=False;Application Name=$AppName;"


# ---------------------------------------------------------------------
# Set-up email configuration
# ---------------------------------------------------------------------

    #Email specific data
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
    writetoLog $logFile "INFO" "$appName Started"
    $DTSOPTIONS = "/CHECKPOINTING OFF /Reporting E "
    $DTSDECRYPT = "/Decrypt $DTSPackagePassword"
    $DTSCONN1 = "/CONN `"cm_sql_USTG`";`"$cm_sql_USTG`""
    $DTSCONN2 = "/CONN `"ff_Extract`";`"$FileMask`"" 
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

    writetoLog $logFile "INFO" "$appName Completed"



# ---------------------------------------------------------------------
# command line job setup and execution
# ---------------------------------------------------------------------

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
# put all output files into final locations
# ---------------------------------------------------------------------

    cp *.txt $targetDir
    cp *.log $logDir
    
    
# ---------------------------------------------------------------------
# clean up and get out
# ---------------------------------------------------------------------

    cd $launchDir
    writetoLog $logFile "INFO" "Cleaning up"
    rmdir $localDir -r -force
    touchFile $mySuccessFile
    rm $myTouchFile
    writetoLog $logFile "INFO" "process complete"
    


Exit 0