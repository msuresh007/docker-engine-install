
$dockerZipFileURL = "https://download.docker.com/win/static/stable/x86_64/docker-24.0.7.zip"
$downloadPath = "D:\dockerDownload"
$dockerInstallPath = "D:\apps"
$accountName = "MyTest01"

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

# function to update access control list for named pipe to allow access to non-admin users
# function UpdateNamedPipeAccessControlList($namedPipePath, $accountName) {

#   $dinfo = New-Object System.IO.DirectoryInfo $namedPipePath
#   $acl = $dinfo.GetAccessControl()
#   $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule($accountName, "FullControl", "Allow")))
#   $dinfo.SetAccessControl($acl)
# }

function UpdateNamedPipeAccessControlList($namedPipePath, $accountName) {

  # Use the Get-Acl cmdlet to retrieve the Access Control List (ACL)
  $acl = Get-Acl -Path $namedPipePath

  # Create a new FileSystemAccessRule object
  $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($accountName, "FullControl", "Allow")

  # Add the access rule to the ACL
  $acl.AddAccessRule($accessRule)

  # Set the ACL on the named pipe
  Set-Acl -Path $namedPipePath -AclObject $acl
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
# https://learn.microsoft.com/en-us/windows/wsl/install-manual 
# https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi 

# check if wsl is installed. if not install and enable it
#wsl -l -v
#wsl --set-default-version 2
#wsl --update

wsl --install -d Ubuntu-22.04
wsl --set-default-version 2


if (!(Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -eq 1) {
  Write-Output "Installing WSL"
  Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
}

Write-Output "Enabling WSL"
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

Write-Output "Enabling Hyper-V"
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

Write-Output "Enabling Containers"
Enable-WindowsOptionalFeature -Online -FeatureName containers -All

#enable Windows Subsystem for Linux 2
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -All    


Write-Output "Enabling WSL 2"
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


#create a daemon.json file in $dockerInstallPath\docker\daemon.json and override if already exists
# Write-Output "Creating daemon.json file"
# New-Item -Path "$dockerInstallPath\docker\daemon.json" -ItemType File -Force

#write $daemonjson to the file
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




# Write-Output "Registering service"
# Start-Process -FilePath "$dockerInstallPath\docker\dockerd.exe" -ArgumentList "--run-service --service-name docker -G Users --config-file $dockerInstallPath\docker\daemon.json --log-level debug" -Wait -NoNewWindow
#Start-Process -FilePath "$dockerInstallPath\docker\dockerd.exe" -ArgumentList "--run-service --service-name docker -G DockerUsers --config-file $dockerInstallPath\docker\daemon.json" -NoNewWindow -Wait

#registering the service
#Start-Process -FilePath "$dockerInstallPath\docker\dockerd.exe" -ArgumentList "--register-service" -NoNewWindow -Wait

Start-Process -FilePath "$dockerInstallPath\docker\dockerd.exe" -ArgumentList "--register-service --service-name docker -G Users --config-file $dockerInstallPath\docker\daemon.json --log-level debug" -Wait -NoNewWindow

# find all the named pipes that have docker in the name
# $namedPipes = Get-ChildItem -Path \\.\pipe\ | Where-Object { $_.Name -like "*docker*" }

# update the access control list for each named pipe to allow access to non-admin users
# foreach ($namedPipe in $namedPipes) {  
#   Write-Output "Updating access control list for named pipe $($namedPipe.Name)"
#   prefix the directory path to named pipe name and store it in full path
#   $fullPath = Join-Path -Path "\\.\pipe\" -ChildPath $namedPipe.Name

#   check if namedpipe exists
#   if (!(Test-Path $fullPath)) {
#     Write-Output "Named pipe $fullPath does not exist"
#     create it with full access to everybody
#     Write-Output "Creating named pipe $fullPath"
#     New-Item -Path $fullPath -ItemType File -Force
#   }

#   Write-Output "Full path of named pipe is $fullPath"
#   UpdateNamedPipeAccessControlList($fullPath, $accountName)
# }


#starting the service
Start-Service -Name docker

# stop service and delete it
#Stop-Service docker
#sc.exe delete docker

Write-Output "Docker installed successfully"