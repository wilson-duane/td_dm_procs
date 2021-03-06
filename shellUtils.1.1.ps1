Function touchFile 
{
<#
  .SYNOPSIS
  function to touch an empty file
  .DESCRIPTION
  Send in file name, function touches file
  File should be in the standard status file directory.  Naming convention is $baseProcessName.runDate.[OK|FAIL|touch]
 
  .EXAMPLE
  touchFile $myTouchFile
  .EXAMPLE
  touchFile  "$statusDir$baseName.$runDate.FAIL"
  .PARAMETER Filename
  full path to the touchFile
  
  #>
    set-content -Path ($args[0]) -Value ($null)
}

Function InitializeLogging
{
<#
.SYNOPSIS
  function to initialize the log file 
  .DESCRIPTION
  Sets up the log file in the directory specified by $dir
  Log file name is based on process name, process ID, and runDate.
  Called from within SetEnvironment automatically for all processes.
  
  .EXAMPLE
  InitializeLogging($logDir)
  
  .PARAMETER logDir
  full path to the log directory
  
  #>
    param ([string]$dir)
    
    if(!(Test-Path $dir))
    {
        md $dir
    }
    #set the log file to have script scope
    $script:logFile=  Join-Path "$logDir" "$baseName.$PID.$runDate.log"

}

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
  param ([string]$type, [string]$message)
  
  
  $time = Get-Date -f o
  $content = "$type::$global:baseName::PID:$PID::$time::$message"
   
  Add-Content -Path $logFile -Value $content
}

Function setEnvironment
{
<#
  .SYNOPSIS
  function to set common Environment variables that are used in all scripts
  .DESCRIPTION
  Will set up by environment (after having determined which env the script is running in) databases, settings, common directories
  and long term any other common variable that will be used by most scripts.
  These variables will be added to $retEnv object and can be accessed from the object passed as a reference. 
  Config is read via an xml config file (env.xml) in the $base\ops\cfg directory
  
  .EXAMPLE
  $myEnv = New-Object -TypeNamePSObject
  setEnvironment($myEnv)
  .EXAMPLE
  
  .PARAMETER $myEnv
  
  an object containing environment variables that will be used in all scripts
  current list:

  machineName = machine name script is running on
  domainName = domain name script is running on
  workingEnv = current working environment (SIT, UAT, PAT, PRD)
  dbServerStage = server name of the staging database including port
  dbServerReport = server name of the reporting database including port
  dbUser = default dbUser name
  baseDir = Base directory for all analytics processing and for running environment.
  binDir = directory of all binary executable code (relative to baseDir)
  libDir = directory of all library objects (relative to baseDir)
  cfgDir = directory of all configuratio files(relative to baseDir)
  statusDir = directory for all status files (touch, fail, success) (relative to baseDir)
  utilsDir = directory for all utilities including third party
  scriptDir = directory for all shell scripts (relative to baseDir)
  logDir = directory for all log files (relative to baseDir)
  TDMBaseDir = Base directory for all TDM apps and data
  TDMAppsDir = base application directory for TDM (relative to TDMBaseDir)
  TDMDataDir = base data directory for TDM (relative to TDMBaseDir)
  emailexec = location of email executable for sending status emails automatically
  emailServer = name of email server
  emailTo = email address to send to
  emailFrom = email address for the from line

  #>
  
  #need to complete settings for SIT and UAT 
  

  param ($retEnv, $EnvOverride)
    $machineName = [system.environment]::MachineName
    $theDomain = (gwmi win32_computersystem).domain
    $workingEnv = ""
    #echo $theDomain
    if ($EnvOverride)
    {
        $workingEnv = $EnvOverride
    }
    else
    {
        if ($theDomain -eq "tdbfg.com" -Or $theDomain -eq "bkng.net")
        {
            $workingEnv = "PRD"
        }
        elseif ($theDomain -eq "p-tdbfg.com")
        {
            $workingEnv = "PAT"
        }
        elseif ($theDomain -eq "d2-tdbfg.com")
        {
            $UATmachines = "ABXDSVCP12BWUS2","ABXDSVCP04BWUS2", "ABXDSVCP05BWUS2", "ABXDSVCP06BWUS2", "ABXDSVCP07BWUS2", "ABXDSVCP08BWUS2", "ABXDSVCP13BWUS2", "ABXDSVCP02BWUS2", "ABXDSVCP03BWUS2", "ABXDSVCP26BWUS2", "ABXDSVCP24BWUS2", "ABXDSVCP25BWUS2" 
            $SITmachines = "ABXDSVCP17BWUS2","ABXDSVCP18BWUS2","ABXDSVCP19BWUS2","ABXDSVCP30BWUS2","ABXDSVCP31BWUS2","ABXDSVCP32BWUS2","ABXDSVCP33BWUS2","ABXDSVCP34BWUS2","ABXDSVCP35BWUS2"
            switch ($machineName)
            {
                {UATmachines -contains $_} {$workingEnv = "UAT";break}
                {SITmachines -contains $_} {$workingEnv = "SIT";break}
                default {writeToLog "ERROR" "in D2 domain but cannot determine if in UAT or SIT"; exit 1}
            }      
        }
        else
        {
            writeToLog "ERROR" "in unknown domain"
            exit 1
        }
    }
    #read in Environment config file from default location
    $configDir = "..\cfg\"
    $configFile = $configDir+"env.xml"
    if (!(test-path $configFile))
    {
        echo "ERROR" "Cannot find Environment config file: $configFile"
        Exit 1
    }
    [xml]$envXML = Get-Content $configFile
    echo "the working Environment is $workingEnv"
    if (!($envXML.ENV.$workingEnv))
    {
        echo "ERROR" "Cannot find Environment $workingEnv"
        Exit 1
    }
    $base = $envXML.ENV.$workingEnv.baseDir
    $TDMBaseDir = $envXML.ENV.$workingEnv.TDMBaseDir
    $retEnv | Add-Member –MemberType NoteProperty –Name baseDir –Value $base
    #$envXML.ENV.$workingEnv | Format-List  #will show contents of xml object for debugging
    #config items determined at runtime
    $retEnv | Add-Member –MemberType NoteProperty –Name workingEnv –Value $workingEnv
    $retEnv | Add-Member –MemberType NoteProperty –Name machineName –Value $machineName
    $retEnv | Add-Member –MemberType NoteProperty –Name domainName –Value $theDomain
    #config items taken from env.xml
    $retEnv | Add-Member –MemberType NoteProperty –Name dbServerStage –Value $envXML.ENV.$workingEnv.dbServerStage
    $retEnv | Add-Member –MemberType NoteProperty –Name dbServerReport –Value $envXML.ENV.$workingEnv.dbServerReport
    $retEnv | Add-Member –MemberType NoteProperty –Name dbUser –Value $envXML.ENV.$workingEnv.dbUser
    $retEnv | Add-Member –MemberType NoteProperty –Name emailServer –Value $envXML.ENV.$workingEnv.emailServer
    $retEnv | Add-Member –MemberType NoteProperty –Name emailTo –Value $envXML.ENV.$workingEnv.emailTo
    $retEnv | Add-Member –MemberType NoteProperty –Name emailFrom –Value $envXML.ENV.$workingEnv.emailFrom
    $retEnv | Add-Member –MemberType NoteProperty –Name TDMBaseDir -Value $envXML.ENV.$workingEnv.TDMBaseDir
    
    #config directories defined with respect to $base directory as well as some full static folders
    $binDir = $base + $envXML.ENV.$workingEnv.binDir
    $libDir = $base + $envXML.ENV.$workingEnv.libDir
    $logDir = $base + $envXML.ENV.$workingEnv.logDir
    $cfgDir = $base + $envXML.ENV.$workingEnv.cfgDir
    $statusDir = $base + $envXML.ENV.$workingEnv.statusDir
    $scriptDir = $base + $envXML.ENV.$workingEnv.scriptDir
    $utilitiesDir= $envXML.ENV.$workingEnv.utilitiesDir
    $TDMAppsDir = $TDMBaseDir + $envXML.ENV.$workingEnv.TDMAppsDir
    $TDMDataDir = $TDMBaseDir + $envXML.ENV.$workingEnv.TDMDataDir
    #email exec path can also be changed in config file.
    $emailExecPath = $envXML.ENV.$workingEnv.emailExecPath
    $retEnv | Add-Member –MemberType NoteProperty –Name TDMAppsDir -Value $TDMAppsDir
    $retEnv | Add-Member –MemberType NoteProperty –Name TDMDataDir -Value $TDMDataDir
    $retEnv | Add-Member –MemberType NoteProperty –Name binDir –Value $binDir
    $retEnv | Add-Member –MemberType NoteProperty –Name libDir –Value $libDir
    $retEnv | Add-Member –MemberType NoteProperty –Name logDir –Value $logDir
    $retEnv | Add-Member –MemberType NoteProperty –Name cfgDir –Value $cfgDir
    $retEnv | Add-Member –MemberType NoteProperty –Name statusDir –Value $statusDir
    $retEnv | Add-Member –MemberType NoteProperty –Name utilsDir –Value $utilitiesDir
    $retEnv | Add-Member –MemberType NoteProperty –Name scriptDir –Value $scriptDir
    $retEnv | Add-Member –MemberType NoteProperty –Name emailexec –Value $emailExecPath
    
    initializeLogging($logDir)

    #test drive mappings before allowing usage.
    <#
    $mappingError = 0
    $arrayLength = $envXML.ENV.$workingEnv.driveMapping.letter.length
    for ($i=0; $i-lt $arrayLength; $i++)
    {
        if ($arrayLength -eq 1)
        {
            $xmap = $envXML.ENV.$workingEnv.driveMapping.letter
            $xpath = $envXML.ENV.$workingEnv.driveMapping.mapping
        }
        else
        {
            $xmap = $envXML.ENV.$workingEnv.driveMapping.letter[$i]
            $xpath = $envXML.ENV.$workingEnv.driveMapping.mapping[$i]
        }
        echo "the path for $xmap is $xpath"
        $testpath = $xmap + ":\"
        #let's test the path
        if (!(Test-Path $testpath))
        {
            writeToLog "INFO" "could not find path $testpath will try to re-map" 
            # need to test this with drive mappings with spaces....not sure if quotes will be needed.
            try
            {
                writeToLog "INFO" "remapping $xmap to $xpath"
                New-PSDrive –Name $xmap –PSProvider FileSystem –Root $xpath –Persist -Scope "Global" | Out-Null
                if (Test-Path $testpath)
                {
                    writeToLog "INFO" "remapping of $xmap to $xpath successful"
                }
                else
                {
                    writeToLog "WARNING" "remapping of $xmap to $xpath was not successful"
                    $mappingError = 1
                }
            }
            catch
            {
                writeToLog "WARNING" "Something went wrong while remapping drive $xmap"
                $mappingError = 1
            }
        }
    }
    if ($mappingError)
    {
        writeToLog "ERROR" "at least one shared drive was unable to be remapped"
        exit 1
    }
    #>


}
<#
  .SYNOPSIS
  function to send an email on error with message and header
  .DESCRIPTION
  accepts a header string, message string, and working environment as input.
  sends email on caught issues based on email settings defined below by environment. 
  
  
  
  .EXAMPLE
  $message = "unknown exception caught, exiting"
  $header = "FAIL: $global:baseName"
  send_email_on_error $header $message $workingEnv
  
  .EXAMPLE
  $message = "ftp process failed for inbox BLDS0KCL exiting"
  $header = "FAIL: $global:baseName"
  send_email_on_error $header $message $workingEnv
  
  .PARAMETER header
  free form string that should contain FAIL: $global:baseName (the name of the running program).
  .PARAMETER message
  free form string describing the issue that caused the program to terminate
  .PARAMETER workingEnv
  defined in setEnvironment
  #>


function send_email_on_error ([string] $header, [string] $message, $envRef)
{
    $emailExecPath = $envRef.emailExec
    $message = "`"$message`"" #adding in extra quotes necessary for command line message
    $header = "`"$header`"" #adding in extra quotes necessary for command line message
    if ($envRef.workingEnv -eq "PRD" -Or $envRef.workingEnv -eq "PAT")
    {
        $EmailServer= $envRef.emailServer
        $EmailTo= $envRef.emailTo
        $EmailFrom= $envRef.emailFrom 
    

        $emailArguments = @("-s", $EmailServer, "-t", $EmailTo, "-f", $EmailFrom, "-a", $header, "-b", $message, "-c")
        #write-host "Start-Process -FilePath $emailExecPath -ArgumentList $emailArguments -PassThru -Wait"
        $proc = Start-Process -FilePath $emailExecPath -ArgumentList $emailArguments -PassThru -Wait
        #Send-MailMessage  -From $EmailFrom -To $EmailTo -Subject $header -Body $message -SmtpServer $EmailServer 
    }
    else
    {
        writeToLog "INFO" "no email set up for this environment"
    }
}