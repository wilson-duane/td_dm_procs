##################################################################
# Title:         GlobalMethods.ps1
# Author:        Joe Frizzell
# Create Date:   10/10/2016
# Modified Date  10/10/2016
# Purpose:       Class for contating functions that could be useful
#                throughout the project. 
##################################################################

class GlobalMethods{

    #Default constructor
    GlobalMethods(){}

    ###############################################################
    #Using the namespace passed by caller bukld the assembly
    #reference data. 
    #namespace := Namespace to build the reference type for. 
    #returns := String
    ###############################################################
    [String] GetAssembly([String]$namespace){
        
        try{

            $serviceRef = New-Object System.IO.FileInfo([System.Reflection.Assembly]::LoadWithPartialName($namespace))

            $array = $serviceRef.FullName.Split(',')

            $library = $namespace
            $version = $null
            $culture = $null
            $token = $null

            for($i = 0; $i -lt $array.Length; $i++){
                if($array[$i].ToString().Contains("Version")){
                    $version = $array[$i]
                }
                elseif($array[$i].ToString().Contains("Culture")){
                    $culture = $array[$i]
                }
                elseif($array[$i].ToString().Contains("PublicKeyToken")){
                    $token = $array[$i]
                }#End if
            }#End for($i)

            $name = "$library, $version, $culture, $token"

            Write-Output ""

            return $name
        }
        catch{
            return ""
        }#End try / catch

    }
}