
<#
.SYNOPSIS
    Common template for building shell scripts for TBSM US.
.DESCRIPTION
    Starting point for building new scripts, should be updated when libraries and code standards are updated
.PARAMETER runDate
    -d - runDate -- in the Format YYYYMMDD defaults to current date
.PARAMETER startENV
    -e - startENV -- Environment override, set to LOCAL if you want to override the lookup by domain/machine for the running environment variables.
.EXAMPLE
    powershell.exe .\template.ps1

.EXAMPLE
    powershell.exe .\template.ps1 -d 20160909
.EXAMPLE
    powershell.exe .\template.ps1 -d 20160909 -e LOCAL
#>

#update the section above to ensure operators understand how to use the script and what it is for.

#parameters can be updated to include any command line options.  These should include the ability to override input and output file locations to allow for operational overrides.

Param(
    
    [alias("d")]
    [string] $runDate,
    [alias("e")]
    [string] $startENV)
    cls
    #get current working directory
    $launchDir = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition.ToString())
    cd $launchDir
# ---------------------------------------------------------------------
# Set-up of common variables
# ---------------------------------------------------------------------
   
    $Script = gi($MyInvocation.InvocationName)
    $global:baseName = ($Script | select basename).basename
    
    #this can be changed depending on default method for obtaining the rundate, ie if obtaining from table or environment variable.  
    if (!($runDate))
    {
        $runDate = Get-Date -UFormat "%Y%m%d"
    }

# ---------------------------------------------------------------------
# load shell utility functions including logging and email
# as well as all common variables into environment object
# all scripts are to be run from the script directory, this assumes the standard locations of cfg directory until env.xml is loaded.
# --------------------------------------------------------------------
    . .\shellUtils.1.1.ps1
    $envObj = New-Object –TypeName PSObject
    setEnvironment $envObj $startENV
    $envstring  = $envObj | Format-List | out-string
    writetoLog "INFO" " starting process"
    writetoLog "INFO" "Environment Settings:  $envstring"
    $baseDrive = $envObj.baseDir
# ---------------------------------------------------------------------
# Set-up and move into run directory
# ---------------------------------------------------------------------

    $localDir= "$baseDrive\ops\run\$baseName.$PID.$runDate"

# ---------------------------------------------------------------------
# Set-up Job status files and environment default locations
# other variables can be found in shellUtils script that are included in the $envObj
# ---------------------------------------------------------------------
    
    $TDMBaseDir = $envObj.TDMBaseDir
    $TDMAppsDir = $envObj.TDMAppsDir
    $binDir = $envObj.binDir
    $libDir = $envObj.libDir
    $logDir = $envObj.logDir
    $scriptDir = $envObj.scriptDir
    $runDir = $envObj.runDir
    $statusDir = $envObj.statusDir
    $cfgDir = $envObj.cfgDir
    $utilsDir = $envObj.utilsDir
    $touchFileBase = "$statusDir$baseName.$runDate"
    $mytouchFile = "$touchFileBase.touch"
    $mySuccessFile = "$touchFileBase.OK"
    $myFailFile = "$touchFileBase.FAIL"
    
    touchFile $mytouchFile
    $workingEnv = $envObj.workingEnv
    writetoLog "INFO" "changing to temp directory $localDir"
    if (!(Test-Path $localDir))
    {
        #echo "couldn't find the directory"
        md $localDir | Out-Null
    }
    cd $localDir
    
     
# ---------------------------------------------------------------------
# Start processing - anything you do here is temporary - copy any output and
# logs to appropriate final locations before cleaning up.
# order of the following steps for shell scripts, SSIS jobs, executables depends on your requirements
# ---------------------------------------------------------------------
 #example of error handling, shell code inside Try statement.
Try
{
   
}
Catch
{
    echo "unknown exception caught, exiting"
    echo $_.Exception.GetType().FullName, $_.Exception.Message
    echo $_.Exception | format-list -force
    $excType = $_.Exception.GetType().FullName
    $excMessage = $_.Exception.Message
    writeToLog "ERROR" "exception caught, exiting"
    writeToLog "ERROR" "$excType, $excMessage"
    $message = "unknown exception caught, exiting $excType, $excMessage"
    $header = "FAIL: $global:baseName"
    send_email_on_error $header $message $workingEnv
    touchFile $myFailFile
    Exit 1
}



# ---------------------------------------------------------------------
# SSIS/SSAS/SSRS SQL job setup and execution
# ensure to get database variables from envObj.
# ---------------------------------------------------------------------


# ---------------------------------------------------------------------
# command line job setup and execution
# executables should be located if possible in bin directory
# ---------------------------------------------------------------------


# ---------------------------------------------------------------------
# if other jobs continue here
# ---------------------------------------------------------------------




# ---------------------------------------------------------------------
# put all output files into final locations
# ---------------------------------------------------------------------
   
    
# ---------------------------------------------------------------------
# send files to ftp locations if necessary
# ---------------------------------------------------------------------  


# ---------------------------------------------------------------------
# clean up and get out
# 
# ---------------------------------------------------------------------
    
writetoLog "INFO" "Process complete, Cleaning up"
cp *.log $logDir
rmdir $localDir -r -force
touchFile $mySuccessFile
rm $myTouchFile

Exit 0