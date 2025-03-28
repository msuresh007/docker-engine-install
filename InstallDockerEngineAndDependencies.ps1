
#######################################################################
# Script Name: InstallDockerEngineAndDependencies.ps1
# Author: Suresh Madadha
# Description: Installs Docker Engine in Windows Computer in one go!
#
# Disclaimer:
# This PowerShell script is provided as-is without any warranty. Use at
# your own risk. The author will not be responsible for any damage or
# data loss caused by using this script. Ensure you understand the
# script's functionality before execution and take necessary backups
# before making any changes to your system.
#
# Usage:
# - Ensure PowerShell Execution Policy allows script execution.
# - Review the script to understand its actions before running.
# - Modify variables or configurations as needed for your environment.
# - Execute the script in a PowerShell environment.
#
# Author Contact:
# Email: msuresh007@gmailcom
# LinkedIn: https://www.linkedin.com/in/suresh-madadha/ 
#
# Version: 1.0
# Last Updated: Dec 10, 2023
#######################################################################


#-------------------------------------------------- Start of Variables for Initialization --------------------------------------------------#
# check https://download.docker.com/win/static/stable/x86_64 for latest version of docker engine
$dockerZipFileURL = "https://download.docker.com/win/static/stable/x86_64/docker-28.0.4.zip"
$downloadPath = "D:\dockerDownload"
$dockerInstallPath = "D:\apps"
$accountName = "MyTest01"
#-------------------------------------------------- End of  Variables for Initialization --------------------------------------------------#

$groupName = "DockerUsers"
$daemonjson = @"
{
    "builder": {
      "gc": {
        "defaultKeepStorage": "20GB",
        "enabled": true
      }
    },
    "experimental": true,
    "hosts": [
       "npipe:////./pipe/docker_engine"
    ]    
  }
"@

# function to create folder if not exists
function CreateFolderIfNotExists($folderPath) {
  if (!(Test-Path $folderPath)) {
    Write-Output "Creating folder $folderPath"
    New-Item -Path $folderPath -ItemType Directory
  }
}

function CheckUserGroupMembership($winGroupName, $userName) {
  $groupMembers = Get-LocalGroupMember -Group "$winGroupName"  -ErrorAction SilentlyContinue
  if ($null -ne $groupMembers) {
      foreach ($member in $winGroupName) {
          if ($member.Name -eq $userName) {
              Write-Output "$userName is a member of group $winGroupName"
              return $true
          }
      }
  }
  
  Write-Output "$userName is not a member of group $winGroupName"
  return $false
}

# function that takes grouname and user account name as input and adds the user to the group if not already added
function AddUserToGroup($winGroupName, $accountName) {
  # check if the group exists. if not create it
  if (!(Get-LocalGroup -Name $winGroupName -ErrorAction SilentlyContinue)) {
    Write-Output "Creating group $winGroupName"
    New-LocalGroup -Name $winGroupName
  }
  else {
    Write-Output "Group $winGroupName already exists"  
  }

  # check if the user is already in the group and add if not
  if (!(CheckUserGroupMembership $winGroupName $accountName)) {
    Write-Output "Adding user $accountName to group $winGroupName"
    Add-LocalGroupMember -Group $winGroupName -Member $accountName
  }
  else {
    Write-Output "User $accountName already exists in group $winGroupName"  
  }
}


# check if powershell is running as admin
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Warning "You need to run this script as an administrator"
  exit 1
}


# checking if the download and install folders exist. if not create them
CreateFolderIfNotExists($downloadPath)
CreateFolderIfNotExists($dockerInstallPath)

# install wsl kernel
Write-Output "Installing WSL kernel"
wsl --install -d Ubuntu-22.04
wsl --set-default-version 2


if (!(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq 1) {
  Write-Output "Enabling WSL"
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All
}

# Required for both WSL2 and Hyper-V backends.
# Needed if you plan to use WSL2 as the backend for Docker.
Write-Output "Enabling VirtualMachinePlatform"
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

# Required ONLY if using the Hyper-V backend instead of WSL2.
# Hyper-V is an alternative to WSL2 for running Docker virtual machines.
# This is needed if you plan to use Windows-native virtualization instead of WSL2.
Write-Output "Enabling Hyper-V"
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

# Required ONLY if running Windows containers (not needed for Linux containers).
# Needed when running native Windows-based Docker containers instead of Linux containers.
# If you only plan to run Linux containers using WSL2 or Hyper-V, this is not required.
Write-Output "Enabling Containers"
Enable-WindowsOptionalFeature -Online -FeatureName containers -All



Write-Output "Setting WSL default version to 2"
wsl --set-default-version 2

#download the zip file
Write-Output "Downloading Docker Zip file"
Invoke-WebRequest -Uri $dockerZipFileURL -OutFile "$downloadPath\docker.zip"
Write-Output "Unzipping Docker Zip file"
Expand-Archive -Path "$downloadPath\docker.zip" -DestinationPath "$downloadPath"
Write-Output "Docker Zip file unzipped"

#check if dockerd is running. if yes, stop it from running

if (Get-Service -Name docker -ErrorAction SilentlyContinue) {
  Write-Output "Stopping docker service"
  Stop-Service docker
  #remove the service
  Write-Output "Removing docker service"
  sc.exe delete docker
}

# copy all files from the unzipped folder to the install folder
Write-Output "Copying files to install folder"

Copy-Item -Path "$downloadPath\docker" -Destination $dockerInstallPath -Recurse -Force

# grant full control to Users group for the install folder
Write-Output "Granting full control to Users group for the install folder"
$Acl = Get-Acl -Path $dockerInstallPath
$Ar = New-Object  system.security.accesscontrol.filesystemaccessrule("Users","FullControl","Allow")
$Acl.SetAccessRule($Ar)
Set-Acl -Path $dockerInstallPath -AclObject $Acl



# delete the zip file and the unzipped folder
Write-Output "Deleting downloaded files"
Remove-Item -Path "$downloadPath\docker.zip" -Force -Recurse
Remove-Item -Path "$downloadPath\docker" -Force -Recurse

# add $downloadPath\docker to the path environment variable
$existingPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
$newPathValue = $existingPath + ";$dockerInstallPath\docker"

# Update the PATH environment variable with the new value for all users
Write-Output "Updating PATH environment variable"
[Environment]::SetEnvironmentVariable("PATH", $newPathValue, "Machine")

# Verify the updated PATH variable
$updatedPath = [Environment]::GetEnvironmentVariable("PATH", "Machine")
Write-Host "Updated PATH variable:"
Write-Host $updatedPath



#write $daemonjson to the file
Write-Output "Creating daemon.json file"
Write-Output $daemonjson | Out-File -FilePath "$dockerInstallPath\docker\daemon.json" -Force


# check if the group exists. if not create it
if (!(Get-LocalGroup -Name $groupName -ErrorAction SilentlyContinue)) {
  Write-Output "Creating group $groupName"
  New-LocalGroup -Name $groupName
}
else {
  Write-Output "Group $groupName already exists"  
}

# Add users to the Docker group
# get current user 
$user = [Environment]::UserName

AddUserToGroup($groupName, $user)
AddUserToGroup($groupName, $accountName)

#write the names of the users in the group to console in comma separated format
Write-Output "Users in group $groupName"
Get-LocalGroupMember -Group $groupName | Select-Object -ExpandProperty Name | ForEach-Object { Write-Output $_ }

Write-Output "Registering docker service"
Start-Process -FilePath "$dockerInstallPath\docker\dockerd.exe" -ArgumentList "--register-service --service-name docker -G Users --config-file $dockerInstallPath\docker\daemon.json --log-level debug" -Wait -NoNewWindow

Write-Output "Setting docker service to start automatically"
#starting the service
Start-Service -Name docker

Write-Output "Docker installed successfully"

Write-Output "you can run below command to check if docker is running"
Write-Output "docker run hello-world"

