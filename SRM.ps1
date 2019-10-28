function SRM-NewToast($title, $text)
{
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.UI.Notifications.ToastNotification, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
    
    $APP_ID = 'Microsoft.XboxApp_8wekyb3d8bbwe!Microsoft.XboxApp'
    #$APP_ID = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
    
    $template = @"
    <toast>
        <visual>
            <binding template="ToastText02">
                <text id="1">$($title)</text>
                <text id="2">$($text)</text>
            </binding>
        </visual>
    </toast>
"@
    
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml($template)
    $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($APP_ID).Show($toast)
}

$Publishers = [System.Collections.ArrayList]@()
$Publishers = "Rockstar", "Ubisoft", "Blizzard", "Origin", "steamapps"

$defaultProcesses = [System.Collections.ArrayList]@("wallpaper32", "wallpaperservice32_c", "svchost", "MicrosoftEdgeCP", "TeamViewer_Service" , "RuntimeBroker", "nvcontainer", "Discord", "dllhost", "conhost", "csrss", "Idle", "Memory Compression", "MsMpEng", "NisSrv", "Registry", "SecurityHealthService", "services", "SgrmBroker", "smss", "System", "wininit", 
"UbisoftGameLauncher", "upc", "UplayWebCore", "LsaIso", "Secure System", "vmmem")
#$default = "wallpaper32", "wallpaperservice32_c", "svchost", "MicrosoftEdgeCP", "TeamViewer_Service" , "RuntimeBroker", "nvcontainer", "Discord", "dllhost", "conhost"

#$processes = Get-Process | Where-Object { $_.ProcessName -NotIn $defaultProcesses }
$listenToProcesses = $true
$currentGames = [System.Collections.ArrayList]@()
function SRM-Processes()
{
    while ($true)
    {
        Start-Sleep -Milliseconds 500
        $process = Get-Process | Where-Object { $_.ProcessName -NotIn $defaultProcesses } | Select-Object -Property ProcessName
        Start-Sleep -Milliseconds 500
        foreach ($proc In $process)
        {
            $procPath = Get-Process -Name $proc.ProcessName | Select-Object -ExpandProperty Path
            if ([string]::IsNullOrEmpty($procPath))
            {
                Write-Host "Skipping item " $proc
                Continue
            }


        
            $hasMatch = $false
            foreach ($pub In $Publishers)
            {
                if ($procPath -match $pub)
                {   
                    $hasMatch = $true
                }
            }
        
            if ($hasMatch -eq $false)
            {
                $defaultProcesses.Add($proc.ProcessName)
                Write-Host "No Match for " $proc.ProcessName " witch path " $procPath -ForegroundColor Red
            }
            else
            {
                $currentGames.Add($proc.ProcessName)
                $text = $(Get-Process -Name $proc.ProcessName | Select-Object -Property MainWindowTitle).MainWindowTitle
                SRM-NewToast -title $text -text "Proceeding to reduce workload on CPU and ram";
                #SRM-NewToast("Game Launched", $text)
                Write-Host $proc.ProcessName " has a match " $procPath -ForegroundColor Green
        
            }
        }

        if ($currentGames.Count -gt 0)
        {
            Write-Host "Calling SRM-ProcessWaiter" -ForegroundColor Cyan
            SRM-ProcessWaiter
        }
        else {
            Write-Host "Waiting 10 sec for new iteration" -ForegroundColor Yellow
            Start-Sleep -Seconds 10
        }
    
        
            
        
    }

}

function SRM-ProcessWaiter
{
    SRM-HyperV -request 1
    while($currentGames.Count -gt 0)
    {
        Write-Host $currentGames.Count 
        foreach ($item in $currentGames)
        {
            $proc = Get-Process -Name $item -ErrorAction SilentlyContinue
            Write-Host "Waiting for " $proc.ProcessName " to end" -ForegroundColor Yellow

            if ([string]::IsNullOrEmpty($proc))
            {
                Write-Host $proc.ProcessName " ended" -ForegroundColor Yellow 
                $currentGames.Remove($item)
                SRM-NewToast -title "Game Closed" -text "Resuming normal activities"
            }

        }
        Write-Host "Waiting for " $currentGames.Count " game(s) to end" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
    Write-Host "Calling SRM-Processes" -ForegroundColor Cyan
    SRM-HyperV -request 0
    SRM-Processes
}

# 0 = Start
# 1 = Save
function SRM-HyperV($request)
{
    switch ($request) {
        0 { 
            SRM-StartHyperV
         }
        1 { 
            SRM-SaveHyperV
        }
        Default {}
    }


}

$VMs = New-Object System.Collections.ArrayList

function SRM-SaveHyperV
{
    $VMs = Get-VM | Where-Object { $_.State -ne "Saved" }
    foreach ($VM in $VMs)
    {
        $VMs.Add($VM.Name)
        Save-VM -Name $VM.Name
        
        $cVM = Get-VM -Name $VM.Name
        if ($cVM.State -eq "Saved")
        {
            Write-Host "Virtual Machine " $VM.Name " state " -NoNewline "[" $VM.State "]" -ForegroundColor Green
        }
        else
        {
            Write-Host "Virtual Machine " $VM.Name " state " -NoNewline "[" $VM.State "]" -ForegroundColor Red 
        }
    }
}

function SRM-StartHyperV
{
    $VMs = Get-VM | Where-Object { $_.State -ne "Running" -or $_.State -ne "Off" }
    foreach ($VM in $VMs)
    {
        if ($VMs.Contains($VM))
        {
            Start-VM -Name $VM.Name
            $cVM = Get-VM -Name $VM.Name
            if ($cVM.State -eq "Running")
            {
                Write-Host "Virtual Machine " $VM.Name " state " -NoNewline "[" $VM.State "]" -ForegroundColor Green
            }
            else
            {
                Write-Host "Virtual Machine " $VM.Name " state " -NoNewline "[" $VM.State "]" -ForegroundColor Red 
            }
        }
        else 
        {
            Write-Host "Saved list does not contain " + $VM -ForegroundColor Red    
        }
        
    }    
}

#Initialization

$hyperV = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online
if ($hyperV.State -eq "Enabled")
{
    Write-Host "Hyper-V is enabled" -ForegroundColor Green
}
else {
    Write-Host "Hyper-V is not enabled" -ForegroundColor Red
    Write-Host "Either way, SRM-Processes will be started.." -ForegroundColor Yellow
}

SRM-Processes


