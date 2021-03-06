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