# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
# USE Case Number:  ????
# Job Description: 
#                  
#
# Usage:  run_SADerivativeLoad 1 2
#  1 Environment Mandatory parameter runDate -- Format YYYYMMDD
#  2 Rerun      Optional Parameter (P, R) -- Set for Rerun of data from manual file P)rimary R)erun (Default = P)
#  Note: The variables in the manual section below will need to be filed out correctly
# Creation Date:   
# Author:          
# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
Param(
    [parameter(Mandatory=$true)]
    [alias("d")]
    $runDate,
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


$inDir = "P:\Desktop\test\OldAMTDFlagAddor\"
$outDir = "P:\Desktop\test\OldAMTDFlagAddor\out\"
# ---------------------------------------------------------------------
# Set-up and move into run directory
# ---------------------------------------------------------------------

$localDir= "$baseDrive\ops\run\$baseName.$PID.$runDate"
$touchFileBase = "$statusDir$baseName.$runDate"
#produce touchFile
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
#echo $pwd
# ---------------------------------------------------------------------
# Start processing - anything you do here is temporary - copy any output and
# logs to appropriate final locations before cleaning up.
# ---------------------------------------------------------------------

$inFile = "FileforTreasury$runDate.csv"
$inFilePath = $inDir + $inFile
cp $inFilePath .
writetoLog $logFile "INFO" "got input file: $inFile"

$oldAMTDFile = "OLDamtd.csv"
$oldAMTDFilePath = $inDir +$oldAMTDFile
cp $oldAMTDFilePath .
writetoLog $logFile "INFO" "got date file: $oldAMTDFile"

# ---------------------------------------------------------------------
# SSIS/SSAS/SSRS SQL job setup and execution
# 
# ---------------------------------------------------------------------

$infileOBJ = (gci $inFilePath)
writetoLog $logFile "INFO" "changing ""Unwind"" to Unwind in source file"
$interfile = $infileOBJ.BaseName + "unwind" + $infileOBJ.Extension

Get-content $inFilePath | foreach-object{$_ -replace '"Unwinds"',"Unwinds"} | Set-content $interfile
$outputfile = $infileOBJ.BaseName +"adj"+ $infileOBJ.extension



# ---------------------------------------------------------------------
# command line job setup and execution
# ---------------------------------------------------------------------




#example
$executable = "OldAMTDFlagAddor.exe"
$fullExecPath = $binDir + $executable


$my_arguments = @("-i",$interfile,"-o", $outputfile, "-a", $oldAMTDFile)

writetoLog $logFile "INFO" "running executable:"
writetoLog $logFile "INFO" "process call: Start-Process -FilePath $fullExecPath -ArgumentList $my_arguments -PassThru -Wait"
$proc = Start-Process -FilePath $fullExecPath -ArgumentList $my_arguments -PassThru -Wait

#check exit code ($proc.ExitCode)

if ($proc.ExitCode)
{
   echo "error in process call"
   writetoLog $logFile "ERROR" "Process failed exiting without cleanup"
   cp *.log $logDir
   touchFile $myFailFile
   Exit 1
   
}

# ---------------------------------------------------------------------
# if other jobs continue here
# ---------------------------------------------------------------------




# ---------------------------------------------------------------------
# put all output files into final locations
# ---------------------------------------------------------------------

    cp *adj.csv $outDir
    cp *.log $logDir
    cd $launchDir
# ---------------------------------------------------------------------
# clean up and get out
# ---------------------------------------------------------------------


    writetoLog $logFile "INFO" "Cleaning up"
    rmdir $localDir -r -force
    touchFile $mySuccessFile
    writetoLog $logFile "INFO" "process complete"
    


Exit 0