##################################################################
# Title:                    SqlDbHandler
# Author:               Joe Frizzell
# Create Date:      10/4/2016
# Modified Date   10/4/2016
# Purpose:             Handles backend process for Sql Server calls.
##################################################################

$script_directory =[System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition.ToString())
. "$script_directory\global_methods.ps1"

class SqlDbHandler{
    [String] $ERROR_MESSAGE
    
    SqlDbHandler(){
        $this.ERROR_MESSAGE = $null
    }

    ###############################################################
    #Executes a DTSX Package.
    #pathToPackage := Full path to DTSX package to be executed. 
    #password := Password for package if required.
    #returns := boolean
    ###############################################################
    [bool] RunDtsxPackageFromDirectory([string]$pathToPackage, [string]$password){

        $this.ERROR_MESSAGE = $null

        if ([System.IO.File]::Exists($pathToPackage) -and [System.IO.Path]::GetExtension($pathToPackage.ToLower()) -eq ".dtsx"){
      
            try{
             
                $globalAssembly = New-object GlobalMethods

                $reference = $globalAssembly.GetAssembly("Microsoft.SqlServer.ManagedDTS")

                Add-Type -AssemblyName $reference

                $ssisApplication = New-Object "Microsoft.SqlServer.Dts.Runtime.Application" 

                if (-Not [String]::IsNullOrEmpty($password)){
                    $ssisApplication.PackagePassword = $password
                }#End if
               
                ##With Pathname and FileName 
                $ssisPackagePath =$pathToPackage
                
                $ssisPackage = $ssisApplication.LoadPackage($pathToPackage,$null) 

                $ssisPackage.Execute()  

                Write-Output "Process complete!"

                return $true
            
            }
            catch{

                $this.ERROR_MESSAGE = $_.Exception.Message
                return $false
            }
        }
        else{
            $this.ERROR_MESSAGE = "Invalid file. Please make sure file exists and is the proper file type(dtsx)."
            Write-Output $this.ERROR_MESSAGE
            return $false
        }#End if
    }#End Method

    ###############################################################
    #Run SQL query and populate a dataset.
    #query := Query to fill dataset with. 
    #server := Server to connect to. 
    #database := Name of database being queried.
    #retuns := DataSet
    ###############################################################
    [System.Data.DataSet] CreateTableObject([string]$query,[string]$server, [string]$database){
        
        $this.ERROR_MESSAGE = $null

        $objConn = New-Object System.Data.SqlClient.SqlConnection
        $objConn.ConnectionString =  "Data Source=$server;Initial Catalog=$database;Integrated Security=SSPI;"

        $objDSet = New-Object System.Data.DataSet

        try{
            $objConn.Open

            $objCmd = New-Object System.Data.SqlClient.SqlCommand($query,$objConn)

            $objAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($objCmd)
            $objAdapter.Fill($objDSet)

            Write-Output "Process Complete"

            return $objDSet
        }
        catch{
            $this.ERROR_MESSAGE =  $_.Exception.Message
            Write-Output = $this.ERROR_MESSAGE
            return $null;
        }
        finally{
            $objConn.Close
            $objConn.Dispose
            $objDSet.Dispose
        }

    }#End method

    ###############################################################
    #Run SQL query and populate a dataset.
    #query := Query to fill dataset with. 
    #sqlArgs := Arguments passed into query. 
    #server := Server to connect to. 
    #database := Name of database being queried.
    #retuns := DataSet
    ###############################################################
    [System.Data.DataSet] CreateTableObject([string]$query,[string[]]$sqlArgs, [string]$server, [string]$database){

        $this.ERROR_MESSAGE = $null

        $objConn = New-Object System.Data.SqlClient.SqlConnection
        $objConn.ConnectionString =  "Data Source=$server;Initial Catalog=$database;Integrated Security=SSPI;"

        $objDSet = New-Object System.Data.DataSet

        try{
            $objConn.Open

            $objCmd = New-Object System.Data.SqlClient.SqlCommand($query, $objConn)

            [Void]$objCmd.Parameters.AddWithValue($sqlargs[0],$sqlArgs[1])

            $objAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($objCmd)
            $objAdapter.Fill($objDSet)

            Write-Output "Process Complete"

            return $objDSet
        }
        catch{
            $this.ERROR_MESSAGE =  $_.Exception.Message
            Write-Output = $this.ERROR_MESSAGE
            return $null;
        }
        finally{
            $objConn.Close
            $objConn.Dispose
            $objDSet.Dispose
        }

    }#End method
    
    ###############################################################
    #Run SQL query and populate a dataset.
    #query := Query to fill dataset with. 
    #sqlArgs := Arguments passed into query. 
    #server := Server to connect to. 
    #database := Name of database being queried.
    #retuns := DataSet
    ###############################################################
    [System.Data.DataSet] CreateTableObject([string]$query,[string[][]]$sqlArgs, [string]$server, [string]$database){
        
        $this.ERROR_MESSAGE = $null

        $objDSet = New-Object System.Data.DataSet
        $objConn = New-Object System.Data.SqlClient.SqlConnection

        $objConn.ConnectionString =  "Data Source=$server;Initial Catalog=$database;Integrated Security=SSPI;"

        try{
            $objConn.Open

            $objCmd = New-Object System.Data.SqlClient.SqlCommand($query, $objConn)

            for($i = 0; $i -lt $sqlArgs.Length; $i++){
                $name = $sqlArgs[$i][0]
                $value = $sqlArgs[$i][1]
                [Void]$objCmd.Parameters.AddWithValue($name,$value)
            }

            $objAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($objCmd)
            $objAdapter.Fill($objDSet)

            Write-Output "Process Complete"

            return $objDSet
        }
        catch{
            $this.ERROR_MESSAGE =  $_.Exception.Message
            Write-Output = $this.ERROR_MESSAGE
            return $null;
        }
        finally{

            $objConn.Close
            $objConn.Dispose
            $objDSet.Dispose
        }

    }#End method

    
}