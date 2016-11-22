$workingFolder = "c:\nexosis"

# Create working dir folder
if (-not (test-path $workingFolder) )
{
    New-Item -ItemType directory -Path C:\nexosis
}

$Logfile = $workingFolder + "\$(gc env:computername)-install.log"

Function LogWrite
{
   Param ([string]$logstring)
   Add-content $Logfile -value $logstring
}

Push-Location
Set-Location -Path $workingFolder

# config
$uri = 'https://cran.r-project.org/bin/windows/base/old/3.2.3/R-3.2.3-win.exe'
$outFile = '.\R-3.2.3-win.exe'
$packageName = 'R for Windows 3.2.3' #  must == DisplayName of installed package",
$isInstalled = $false

Try 
{
    # get installer
    LogWrite "Downloading R installer..."
    Invoke-WebRequest $uri -OutFile $outFile
    LogWrite "    COMPLETE"
    LogWrite "Creating deploy.inf..."
    # Creating deploy.inf file
    $inf = '[Setup]
Lang=en
Dir=C:\Program Files\R\R-3.2.3
Group=R
NoIcons=0
SetupType=user
Components=main,i386,x64,translations
Tasks=desktopicon,recordversion,associate
[R]
MDISDI=MDI
HelpStyle=HTML'

    # Get Setup directory
    $setupDirectory = (get-item $outFile).Directory.FullName
    # Get ini path
    $infFullPath = $setupDirectory + '\deploy.inf'
    # Write deploy.inf
    $inf | Set-Content $infFullPath
    LogWrite "    COMPLETE"
    # set installer arguments
    $rInstallArgs = "/LOADINF=" + $infFullPath + " /VERYSILENT"

    # install without user input
    LogWrite "installing $($packageName)..."
    $setupFullPath =(get-item $outFile).FullName
    $setupDirectory =(get-item $outFile).Directory.FullName
    
    Start-Process $setupFullPath -ArgumentList $rInstallArgs

    # wait until install is complete.
    do
    {
        Write-Progress -Activity "Installing R..."
        LogWrite "."
        sleep -Milliseconds 200
        $isInstalled = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | where {$_.DisplayName -eq $packageName}
    }
    until
    (
        $isInstalled
    )
    Write-Progress -Activity "R Installtion Complete." -Completed "R Installtion Complete."
    LogWrite "    COMPLETE"
}
Catch 
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    LogWrite $ErrorMessage + ": " + $FailedItem
    LogWrite "    FAILED TO FETCH OR INSTALL R."
    Break
}

# config
$uri = 'https://notepad-plus-plus.org/repository/6.x/6.9.2/npp.6.9.2.Installer.exe'
$outFile = '.\npp.6.9.2.Installer.exe'
$packageName = 'Notepad++' #  must == DisplayName of installed package
$nppInstallArgs = "/S"
$isInstalled = $false

Try 
{
    # get installer",
    LogWrite "Getting Notepad++ installer..."
    Invoke-WebRequest $uri -OutFile $outFile
    LogWrite "    COMPLETE"

    # install without user input
    LogWrite "installing $($packageName):"
    $exeFullPath = (get-item $outFile).FullName

    Start-Process $exeFullPath -ArgumentList $nppInstallArgs

    # wait until install is complete.
    # msiexec doesn't actually terminate after install, so this is the only way to do it
    do
    {
        Write-Progress -Activity "Installing Notepad++..."
        LogWrite "."
        sleep -Milliseconds 200
        $isInstalled = Get-ItemProperty HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | where {$_.DisplayName -eq $packageName}
    }
    until
    (
        $isInstalled
    )
    Write-Progress -Activity "Notepad++ Installtion Complete." -Completed "Notepad++ Installtion Complete."
    LogWrite "    COMPLETE"
}
Catch 
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    LogWrite "    " + $ErrorMessage + ": " + $FailedItem
    LogWrite "    FAILED TO FETCH OR INSTALL Notepad++."
    Break    
}

# config
$isInstalled = $false
$uri = 'https://download.octopusdeploy.com/octopus/Octopus.Tentacle.3.3.4-x64.msi'
$outFile = '.\Octopus.Tentacle.3.2.24-x64.msi'
$packageName = 'Octopus Deploy Tentacle' #  must == DisplayName of installed package
$octopusUrl = 'https://deploy.nexosis.com'
$role = 'TestStack.Workflow'
$environment = 'Dev'
$tentacleUserName = 'PollingTentacle'
$tentacleUserPassword = ''

Try 
{
    $tentacleHostName = (Invoke-WebRequest 'http://169.254.169.254/latest/meta-data/instance-id').content

    # get installer
    LogWrite "Getting Tentcle installer..."
    Invoke-WebRequest $uri -OutFile $outFile
    LogWrite "    COMPLETE"

    # install without user input
    LogWrite "installing $($packageName)..."
    $msiFullPath =(get-item $outFile).FullName 
    msiexec /i $msiFullPath /quiet

    # wait until install is complete.
    do
    {
        Write-Progress -Activity "Installing Tentacle..."
        LogWrite "."
        sleep -Milliseconds 200
        $isInstalled = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | where {$_.DisplayName -eq $packageName}
    }
    until
    (
        $isInstalled
    )
    Write-Progress -Activity "Tentacle Installtion Complete." -Completed "Tentacle Installtion Complete."
    LogWrite "    COMPLETE"

    # configure tentacle.  Run Octopus Tentacle Manager once manually to get these values
    LogWrite "Configuring Octopus Deploy Tentacle:"
    Push-Location 'C:\Program Files\Octopus Deploy\Tentacle\'
    .\Tentacle.exe create-instance --instance "Tentacle" --config "C:\Octopus\Tentacle.config" --console
    .\Tentacle.exe new-certificate --instance "Tentacle" --if-blank --console
    .\Tentacle.exe configure --instance "Tentacle" --reset-trust --console
    .\Tentacle.exe configure --instance "Tentacle" --home "C:\Octopus" --app "C:\Octopus\Applications" --port "10933" --noListen "True" --console
    .\Tentacle.exe register-with --instance "Tentacle" --server $octopusUrl --name $tentacleHostName --username $tentacleUserName --password $tentacleUserPassword --comms-style "TentacleActive" --server-comms-port "10943" --force --environment $environment --role $role --console
    .\Tentacle.exe service --instance "Tentacle" --install --start --console
    Pop-Location
    LogWrite "Configuring Octopus Deploy Tentacle COMPLETE, script exiting"
}
Catch
{
    $ErrorMessage = $_.Exception.Message
    $FailedItem = $_.Exception.ItemName
    LogWrite $ErrorMessage + ": " + $FailedItem
    LogWrite "    FAILED TO FETCH OR INSTALL Tentacle."
    Break    
}
Pop-Location