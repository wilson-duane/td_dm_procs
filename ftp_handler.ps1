### ###############################################################
# Title:                    FTPHandler
# Author:                Joe Frizzell
# Create Date:       11/3/2016
# Modified Date    11/3/2016
# Purpose:              Handles backend process for Sql Server calls.
##################################################################

class FTPHandler{

    [String] $ERROR_MESSAGE
    [String]$server
    [String] $dropoffDirectory
    [String]$pickupDirectory
    [String]$user
    [String] $password
    [String[]] $files
    [String] $method
    [String] $configFIle

     FTPHandler(){
       $this.ERROR_MESSAGE=$null
       $this.server=$null
       $this.dropoffDirectory
       $this.pickupDirectory=$null
       $this.user=$null
       $this.password=$null
       $this.files=$null
       $this. method=$null
       $this.configFile = "..\cfg\ftpjobs.xml"
    }
    #SOMETHING HERE TO COMMENT FOR GIT
    ##############################################################
    #Send file to FTP server.
    #jobName := Job name to be executed. 
    #retuns := Boolean
    ###############################################################
    [void] PutFile([String]$jobName){

        if (!(test-path $this.configFile))
        {
             $this.ERROR_MESSAGE= "ERROR: Cannot find Environment config file: $this.configFile"
        }
        else
        {
            $this.SetFTPObjects($this.configFile)

            foreach( $file in $this.files){

                try{
                    [String]$uploadPath = [String]::Format("ftp://{0}/", $this.server)

                    if(-Not [String]::IsNullOrEmpty($this.dropoffDirectory)){
                        $uploadPath += [String]::Format("{0}/",$this.dropoffDirectory)
                    }

                    $ftp = [System.Net.FtpWebRequest]::Create($uploadPath + $file )
                    $ftp = [Net.FtpWebRequest]$ftp
                    $ftp.Method = [Net.WebRequestMethods+Ftp]::UploadFile
                    $ftp.Credentials = new-object System.Net.NetworkCredential($this.user,$this.password)
                    $ftp.UseBinary = $true
                    $ftp.UsePassive = $true

                     $fullPathToFile = Join-Path ($this.pickupDirectory) ($file)

                    $content = [IO.File]::ReadAllBytes($fullPathToFile)
                    $ftp.ContentLength = $content.Length
           
                    $rs = $ftp.GetRequestStream()
                    $rs.Write($content, 0, $content.Length)
            
                    $rs.Close()
                    
                 }
                catch{
                  $this.ERROR_MESSAGE += [String]::Format("FTP failed to upload file.  {0}",$_.Exception.Message)
                }
            }
            Write-Output "FTP complete!"
        }
    }#End Method

    ##############################################################
    #Get files from FTP Server. 
    #jobName := Job name to be executed. 
    #retuns := Boolean
    ###############################################################
    [void] GetFile([String]$jobName){
        if (!(test-path $this.configFile))
        {
             $this.ERROR_MESSAGE= "ERROR: Cannot find Environment config file: $this.configFile"
        }
        else
        {
            $this.SetFTPObjects($this.configFile)

            foreach( $file in $this.files){

                try{
                    [String]$pickupPath = [String]::Format("ftp://{0}/", $this.server)

                    if(-Not [String]::IsNullOrEmpty($this.pickupDirectory)){
                        $pickupPath += [String]::Format("{0}/",$this.pickupDirectory)
                    }

                    $ftp = New-Object Net.WebClient
                    $ftp.Credentials = new-object System.Net.NetworkCredential($this.user,$this.password)
                    $ftp.DownloadFile($pickupPath, (Join-Path $this.dropoffDirectory $file))
                 }
                catch{
                  $this.ERROR_MESSAGE = [String]::Format("FTP failed to upload file.  {0}",$_.Exception.Message)
                }
            }
        }
    }#End Method

    #############################################################
    #Get list of all files in array that match the wild card criteria.
    #files := List of files to search for. 
    #pickupDirectory := Directory where files are to be located.
    #return := [String[]]
    #############################################################
    [String[]]GetMputFiles([String[]]$files, [String]$pickupDirectory){

        $list = New-Object Collections.Generic.List[String]

        foreach($file in $files){
            [String[]]$collectionOfFiles = [System.IO.Directory]::GetFiles($pickupDirectory,$files)

            if($collectionOfFiles.Count -gt 0){
                 foreach($fileObject in $collectionOfFiles){
                    $list.add([IO.Path]::GetFIleName($fileObject))
                 }#End foreach($fileObject in $collectionOfFiles)
            }#End if
        }#End foreach foreach($file in $files)

         Write-Output "Process complete"
         return $list.ToArray()

    }#End Method

    #############################################################
    #Set configuration values. 
    #configFile := List of files to search for. 
    #############################################################
    [void] SetFTPObjects([String]$configFile){
        [xml]$xml = Get-Content $configFile
        $xmlElements  = $xml.FTPTask.Job | ?  {$_.Name -eq $jobName} | Select-Object Server,Port,User,Password,PickupDirectory,DropoffDirectory,Files,Method
            
        $this.server = $xmlElements.server
        $this.dropoffDirectory = $xmlElements.DropoffDirectory
        $this.pickupDirectory=$xmlElements.PickupDirectory
        $this.user = $xmlElements.User
        $this.password=$xmlElements.Password
        $this.files=$xmlElements.Files.File
        $this.method=$xmlElements.Method

        if($this.dropoffDirectory.Substring(0,1) -eq "/"){
            $this.dropoffDirectory = $this.dropoffDirectory.Substring(1)
        }

        if($this.dropoffDirectory.EndsWith("/")){
            $this.dropoffDirectory=$this.dropoffDirectory.Substring(0,$this.dropoffDirectory.Length-1)
        }

        if($this.method -eq "MPUT"){
            $this.files = $this.GetMputFiles($this.files,$this.pickupDirectory)
        }#End if
    }#End Method
    
}