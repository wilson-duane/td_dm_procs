# ------------------------------------------------------------------------
# ------------------------------------------------------------------------
# USE Case Number:  ????
# Job Description: 
#                  
#
# Usage:  run_fxRatesLoad 1 2
#  1 Environment Mandatory parameter fx Date -- Format YYYYMMDD
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


#$inDir
$outDir = "$baseDrive\DATA\STATIC\USTG_NII_DataStage\"
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

$yearMonth = $runDate.Substring(0,6)
$year = $runDate.Substring(0,4)
$month = $runDate.Substring(4,2)
$day = $runDate.Substring(6,2)
$outDate = $month + "/" + $day + "/" + $year

$fileLocation = "W:\Market\Data\Static\eodfxrt\" +$yearMonth + "\" + $runDate + "\input\"
if (!(Test-Path $fileLocation))
{
    #echo "Directory $fileLocation not found"
    writetoLog $logFile "ERROR" "Directory $fileLocation not found"
    touchFile $myFailFile
    exit 1
}
$fxFile = ""
#echo $fileLocation

#echo $fileList
$foundit = 0
foreach ($f in Get-ChildItem $fileLocation)
{
    #echo $f.name
    if ((!$f.name.Contains(".ok")) -and ($f.name.Contains("wss_mgmt_01acad." + $Date)))
    {
        writetoLog $logFile "INFO" "found the fx file  $f"
        
        $fxFile = $f
        $foundit = 1
    }
}
if (!$foundit)
{
    writetoLog $logFile "ERROR" "File not found for $Date"
    touchFile $myFailFile
    exit 1
} 
$tempFile = $pwd.Path +"\tempfile"
writetoLog $logFile "INFO" "Removing first four lines of file"
#echo "Removing first four lines of file"
(Get-Content($fxFile.Fullname) | Select-Object -Skip 4) | Set-Content($tempFile)

$contents = import-Csv $tempFile -Delimiter '|'
$contents | Add-Member -MemberType NoteProperty "Date" -Value $outDate
writetoLog $logFile "INFO" "Adding in Date column with value $outDate"
#echo "Adding in Date column with value $outDate"
$contents | Add-Member -MemberType NoteProperty "Spot Rate (USD basis)" -Value ""
#echo $contents.Currency
$convRate = ""
#get the value for USD
#echo "Getting the USD basis conversion value"
writetoLog $logFile "INFO" "Getting the USD basis conversion value"
foreach($line in $contents)
{
  if ($line.Currency -eq "USD")
  {
    $convRate = $line."Spot Rate"    
  }

}
writetoLog $logFile "INFO" "Adding the USD Basis Spot Rate column"

#echo $convRate 
foreach($line in $contents)
{
    $line."Spot Rate (USD basis)" = $line."Spot Rate" / $convRate
}


$outfile = $pwd.Path +"\FXSpotRates" + $runDate + ".csv"

writetoLog $logFile "INFO" "Writing results to $outfile"
$contents | export-Csv $outfile


# ---------------------------------------------------------------------
# SSIS/SSAS/SSRS SQL job setup and execution
# 
# ---------------------------------------------------------------------







# ---------------------------------------------------------------------
# command line job setup and execution
# ---------------------------------------------------------------------

# ---------------------------------------------------------------------
# if other jobs continue here
# ---------------------------------------------------------------------




# ---------------------------------------------------------------------
# put all output files into final locations
# ---------------------------------------------------------------------

   cp FXSpotRates* $outDir
   
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