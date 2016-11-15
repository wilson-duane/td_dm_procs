
<#
.SYNOPSIS
    Windows Schedule backup tool
.DESCRIPTION
    download xml files for each task into zip files for each folder in the ScheduleENV.xml file.  
    Publish zip files by folder that can be used to upload to a new machine or environment 
.PARAMETER runDate
    -d - runDate -- in the Format YYYYMMDD defaults to current date
.PARAMETER startENV
    -e - startENV -- Environment override, set to LOCAL if you want to override the lookup by domain/machine for the running environment variables.
.PARAMETER outDir
    -o - outDir -- overrides the default publish archive path ($TDMAppsDir\TBSMUSDM\WindowsSchedulerScripts)   
.EXAMPLE
    powershell.exe .\dumpSchedule.ps1
.EXAMPLE
    powershell.exe .\dumpSchedule.ps1 -o c:\temp
.EXAMPLE
    powershell.exe .\dumpSchedule.ps1 -d 20160909
.EXAMPLE
    powershell.exe .\dumpSchedule.ps1 -d 20160909 -e LOCAL
#>


Param(
    
    [alias("d")]
    [string] $runDate,
    [alias("o")]
    [string] $outDir,
    [alias("e")]
    [string] $startENV)
    cls
    #get current working directory
    $launchDir =  [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition.ToString())
    cd $launchDir
# ---------------------------------------------------------------------
# Set-up of common variables
# ---------------------------------------------------------------------
   
    $Script = gi($MyInvocation.InvocationName)
    $global:baseName = ($Script | select basename).basename
    
    if (!($runDate))
    {
        $runDate = Get-Date -UFormat "%Y%m%d"
    }

    . .\ftp_handler.ps1

    $ftpObject = New-Object FTPHandler

    $ftpObject.PutFile("BONY-TBSM-ADHOC_EXTRACT_BONY_FILES")
# ---------------------------------------------------------------------
# load shell utility functions including logging and email
# as well as all common variables into environment object
# --------------------------------------------------------------------
    #. $baseDrive\OPS\script\shellUtils.1.1.ps1
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
# ---------------------------------------------------------------------
    $TDMBaseDir = $envObj.TDMBaseDir
    $TDMAppsDir = $envObj.TDMAppsDir
    $statusDir = $envObj.statusDir
    $touchFileBase = "$statusDir$baseName.$runDate"
    $mytouchFile = "$touchFileBase.touch"
    $mySuccessFile = "$touchFileBase.OK"
    $myFailFile = "$touchFileBase.FAIL"
    $cfgDir = $envObj.cfgDir
    touchFile $mytouchFile
    $workingEnv = $envObj.workingEnv
    writetoLog "INFO" "changing to temp directory $localDir"
    if (!(Test-Path $localDir))
    {
        #echo "couldn't find the directory"
        md $localDir | Out-Null
    }
    cd $localDir
    
#now take the files and publish them in a useful location.
     
# ---------------------------------------------------------------------
# Start processing - anything you do here is temporary - copy any output and
# logs to appropriate final locations before cleaning up.
# ---------------------------------------------------------------------
 #read in the schedule config xml file
$schCfgFile = Join-Path "$cfgDir"  "ScheduleEnv.xml"
[xml]$schCfgXML = Get-Content $schCfgFile
writeToLog "INFO" "loading schedule config $schCfgFile"

#$XML.Schedule.Folder
$arrayLength = $schCfgXML.ENV.Schedule.Folder.Count
$folderList = New-Object System.Collections.ArrayList
#echo "the array is of length $arrayLength" 
if ($arrayLength -gt 1)
{
    $folderList.AddRange($schCfgXML.ENV.Schedule.Folder)
}
else
{
    $folderList.Add($schCfgXML.ENV.Schedule.Folder)
}

Try
{
    $sch = New-Object -ComObject("Schedule.Service")
    $sch.Connect()
    foreach ($folder in $folderList)
    {
        writeToLog "INFO" "going to get the schedule for folder $folder"
        echo "going to get the schedule for folder $folder"
        $rootfolder = $sch.GetFolder($folder)
        $tasks = $rootfolder.GetTasks(0)
        $outfile_temp = ".\{0}.xml"

        $tasks | %{
            $xml = $_.Xml
            $task_name = $_.Name
            $outfile = $outfile_temp -f $task_name
            writeToLog "INFO" "outputting task $task_name to xml"
            $xml | Out-File $outfile
        }
       
        writeToLog "INFO" "zipping all xml into $folder.$runDate.zip"
        Compress-Archive -Path .\*.xml -DestinationPath .\$folder.$runDate.zip
        rm *.xml | Out-Null
    }  
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
   
#this will include some archiving for this set of processes.
$outputDir = "$TDMAppsDir\TBSMUSDM\WindowsSchedulerScripts" #default publish location for schedules running daily override by setting -o at command line.
if (($outDir) -and (Test-Path $outDir -pathType Container))
{
    writeToLog "INFO" "overriding default publish path"
    $outputDir = $outDir
}
writeToLog "INFO" "publishing schedules to $outputDir"
cp *.zip $outputDir
    
# ---------------------------------------------------------------------
# send files to ftp locations if necessary
# ---------------------------------------------------------------------  


# ---------------------------------------------------------------------
# clean up and get out
# ---------------------------------------------------------------------
    
writetoLog "INFO" "Process complete, Cleaning up"
cp *.log $logDir
cd $launchDir
rmdir $localDir -r -force
touchFile $mySuccessFile
rm $myTouchFile

Exit 0