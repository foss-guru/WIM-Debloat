### Customize Windows Setup with package provisioning, component base reset, and an answer file.
Write-Output "**** Welcome to Win Setup Prep Utility - the purist-friendly Windows debloater :) ****"
Write-Output "Usage: Insert a setup drive from MCT or Rufus to run the script against. (ESD-USB)"
Write-Output "You can also mount a standalone ISO. (ESD-ISO)"
Write-Output "The standalone takes priority over USB as source. (You can add packages back this way)"
pause

# STAGE 0: Scan for setup
Write-Output "Scanning for compatible volumes..."
if (Get-Volume -FileSystemLabel "ESD-ISO" -ErrorAction SilentlyContinue) {
    $SRC = Get-Volume -FileSystemLabel "ESD-ISO" | Select-Object DriveLetter -ExpandProperty DriveLetter
    if ($SRC -is [array]) { Write-Output "WARNING - Multiple virtual DVDs detected. Exiting..."; exit }
    if (-not (Get-Volume -FileSystemLabel "ESD-USB" -ErrorAction SilentlyContinue | Select-Object DriveLetter -ExpandProperty DriveLetter))
    { Write-Output "WARNING - No target drive detected. If you want to modify one directly, make sure it's inserted before the write stage." }
} else {
    $SRC = Get-Volume -FileSystemLabel "ESD-USB" -ErrorAction SilentlyContinue | Select-Object DriveLetter -ExpandProperty DriveLetter
    if (-not $SRC) { Write-Output "WARNING - No setup volumes detected. Exiting..."; exit }
    if ($SRC -is [array]) { Write-Output "WARNING - Multiple setup drives detected. Exiting..."; exit }
}
$SRC = Get-ChildItem -Path "${SRC}:\sources\install.*" | Select-Object -First 1 -ExpandProperty FullName

# If drive is Rufus or vanilla MCT without .swm, check if user would like to save a local install.wim or not for later servicing (Win SIM, etc.)
if (Get-ChildItem -Path ((Get-Volume -FileSystemLabel "ESD-USB" -ErrorAction SilentlyContinue |
    Select-Object DriveLetter -ExpandProperty DriveLetter) + ":\sources\install.esd") -ErrorAction SilentlyContinue)
{
    Write-Output "An existing ESD file is available on your setup drive. Would you like to mount it directly or continue with importing a decompressed copy?"
    Write-Output "If your USB has good performance, skipping decompression is significantly faster but will not produce install.wim locally in this case. (See ReadMe)"
    $NO_IMPORT = Read-Host "Proceed? - Yes to modify directly. No to import WIM as usual (Y/N)"
    if ($NO_IMPORT -eq 'y') {
        $SRC = Get-Volume -FileSystemLabel "ESD-USB" -ErrorAction SilentlyContinue | Select-Object DriveLetter -ExpandProperty DriveLetter
        $SRC = Get-ChildItem -Path "${SRC}:\sources\install.*" | Select-Object -First 1 -ExpandProperty FullName
    }
}
Write-Output "Discovered source image: $SRC"

# STAGE 1: Select index
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$EDITIONS = @()
DISM /Get-ImageInfo /ImageFile:$SRC | Select-String "Name : " | ForEach-Object { $EDITIONS += $_.ToString().TrimStart("Name : ") }

$editionsDialog = New-Object System.Windows.Forms.Form
$editionsDialog.Text = 'Select Win Edition'
$editionsDialog.Size = New-Object System.Drawing.Size(300, 250)
$editionsDialog.StartPosition = 'CenterScreen'

$editionsList = New-Object System.Windows.Forms.CheckedListBox
$editionsList.Location = New-Object System.Drawing.Point(15, 15)
$editionsList.Size = New-Object System.Drawing.Size(255, 150)
foreach ($edition in $EDITIONS) {
    $index = $editionsList.Items.Add($edition)
    $editionsList.SetItemChecked($index, $false)
}
foreach ($item in $editionsList) { $editionsList.DisplayMember = "Name" }
$editionsList.add_ItemCheck({ # Enforce single item check
    param($control, $e)
    if ($e.NewValue -eq [System.Windows.Forms.CheckState]::Checked) {
        for ($i = 0; $i -lt $control.Items.Count; $i++) {
            if ($i -ne $e.Index -and $control.GetItemChecked($i)) {
                $control.SetItemChecked($i, $false)
            }
        }
    }
})
$editionsDialog.Controls.Add($editionsList)

$editionsButtonOk = New-Object System.Windows.Forms.Button
$editionsButtonOk.Text = 'OK'
$editionsButtonOk.Location = New-Object System.Drawing.Point(110, 175)
$editionsButtonOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
$editionsDialog.Controls.Add($editionsButtonOk)

$editionsButtonCancel = New-Object System.Windows.Forms.Button
$editionsButtonCancel.Text = 'Cancel'
$editionsButtonCancel.Location = New-Object System.Drawing.Point(195, 175)
$editionsButtonCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$editionsDialog.Controls.Add($editionsButtonCancel)

$editionsDialog.AcceptButton = $editionsButtonOk
$editionsDialog.CancelButton = $editionsButtonCancel

if ($editionsDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $selectedEdition = @($editionsList.CheckedItems)
}

# STAGE 2: Configure scratch cache
$WIM = "$env:TEMP\Debloat\Converted\install.wim"
$MOUNT = "$env:TEMP\Debloat\Mount"
$BUILD = "$env:TEMP\Debloat\Build"
if (Get-WindowsImage -Mounted) { Dismount-WindowsImage -Path (Get-WindowsImage -Mounted | Select-Object Path -ExpandProperty Path) -Discard }
if (Test-Path -Path "$MOUNT") { Remove-Item -Path "$MOUNT" -Recurse; Clear-WindowsCorruptMountPoint }
New-Item -Path ($WIM -replace '\\install.wim', '') -ItemType Directory -ErrorAction SilentlyContinue
New-Item -Path "$MOUNT" -ItemType Directory -ErrorAction SilentlyContinue
New-Item -Path "$BUILD" -ItemType Directory -ErrorAction SilentlyContinue
$start = Get-Date

# STAGE 3: Import to WIM file
if ($NO_IMPORT -ne 'y') {
    Write-Output "Importing image..."
    if (Test-Path -Path "$WIM") { Remove-Item -Path "$WIM" }
    if ($SRC -match '.swm') {
        Export-WindowsImage -SourceImagePath "$SRC" -SplitImageFilePattern ($SRC -replace 'install.swm', 'install*.swm') -SourceName "$selectedEdition" -DestinationImagePath "$WIM" -CompressionType "None"
    } else {
        Export-WindowsImage -SourceImagePath "$SRC" -SourceName "$selectedEdition" -DestinationImagePath "$WIM" -CompressionType "None"
    }
    if (-not $?) { Write-Output "Something went wrong during WIM import. Exiting..."; exit }
    if (Test-Path -Path "$WIM") { Write-Output "Imported image successfully" }
}

# STAGE 4: Mount WIM file
Write-Output "Mounting..."
if ($NO_IMPORT -eq 'y') {
    Mount-WindowsImage -ImagePath "$SRC" -Name "$selectedEdition" -Path "$MOUNT"
} else {
    Mount-WindowsImage -ImagePath "$WIM" -Name "$selectedEdition" -Path "$MOUNT"
}
if ($?) { Write-Output "Mounted image successfully" } else { Write-Output "Something went wrong mounting the image. Is WIM missing?"; exit }

$finish = Get-Date
$elapsed = $finish - $start
Write-Output ("Elapsed time (import): " + ($elapsed.TotalMinutes -replace '\.\d+', '') + " min.")

# STAGE 5: Removals
$PROVISIONED = @()
Get-AppxProvisionedPackage -Path "$MOUNT" | Where-Object { -not ($_.DisplayName -match 'AppInstaller|Compatibility|Extension|SecHealth|Store|Terminal') } | ForEach-Object { $PROVISIONED += $_ }

$provisioningDialog = New-Object System.Windows.Forms.Form
$provisioningDialog.Text = 'Debloat image (uncheck what to keep)'
$provisioningDialog.Size = New-Object System.Drawing.Size(400, 500)
$provisioningDialog.StartPosition = 'CenterScreen'

$list = New-Object System.Windows.Forms.CheckedListBox
$list.Location = New-Object System.Drawing.Point(15, 15)
$list.Size = New-Object System.Drawing.Size(350, 400)
foreach ($app in $PROVISIONED) {
    $app.DisplayName = $app.DisplayName -replace '^.*\.', ''
    if ($app.DisplayName -eq "TCUI") { $app.DisplayName = "Xbox" + $app.DisplayName }
    $index = $list.Items.Add($app)
    $list.SetItemChecked($index, $true)
}
foreach ($item in $list) { $list.DisplayMember = "DisplayName" }
$provisioningDialog.Controls.Add($list)

$ok = New-Object System.Windows.Forms.Button
$ok.Text = 'OK'
$ok.Location = New-Object System.Drawing.Point(105, 425)
$ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
$provisioningDialog.Controls.Add($ok)

$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = 'Cancel'
$cancel.Location = New-Object System.Drawing.Point(190, 425)
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$provisioningDialog.Controls.Add($cancel)

$provisioningDialog.AcceptButton = $ok
$provisioningDialog.CancelButton = $cancel

if ($provisioningDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $purge = @($list.CheckedItems)
}

$start = Get-Date
Write-Output "Removing MS Store packages: "
foreach ($app in $purge) {
    Write-Output ($app.PackageName + "...")
    Remove-AppxProvisionedPackage -Path "$MOUNT" -PackageName $app.PackageName
}

# STAGE 6: Optimization
Write-Output "Optimizing package hard links..."
Optimize-AppxProvisionedPackages -Path "$MOUNT"

Write-Output "Removing superseded components..."
DISM /Image:"$MOUNT" /Cleanup-Image /StartComponentCleanup /ResetBase # Ideal for clean install because there'd be nothing to rollback to anyway

$finish = Get-Date
$elapsed = ($finish - $start) + $elapsed
Write-Output ("Elapsed time (debloat): " + (($finish - $start).TotalMinutes -replace '\.\d+', '') + " min.")

# STAGE 7: Save results
$start = Get-Date
Write-Output "Commiting changes..."
Dismount-WindowsImage -Path "$MOUNT" -Save -CheckIntegrity
if ($?) { Write-Output "Changes saved successfully" } else { Write-Output "Something went wrong during commit. Exiting..."; exit }

Write-Output "Recompressing..."
$local_esd = $WIM -replace '.wim', '.esd'
if (Test-Path -Path "$local_esd") { Remove-Item -Path "$local_esd" }
if (($NO_IMPORT -ne 'y') -and -not (Test-Path -Path "${SRC[0]}:\sources\install.swm")) {
    DISM /Export-Image /SourceImageFile:"$WIM" /SourceName:"$selectedEdition" /DestinationImageFile:"$local_esd" /Compress:recovery /CheckIntegrity
    if (-not $?) { Write-Output "Something went wrong during image compression. Exiting..."; exit }
}

$finish = Get-Date
$elapsed = ($finish - $start) + $elapsed
Write-Output ("Elapsed time (recompression): " + (($finish - $start).TotalMinutes -replace '\.\d+', '') + " min.")
Write-Output ("Results exported to: " + ($WIM -replace '\\install.wim', ''))
Get-ChildItem -Path ($WIM -replace '\\install.wim', '') | Select-Object Name, Length, Directory, LastWriteTime | Format-Table

# FINAL STAGE: Write changes to disk
$TARGET = Get-Volume -FileSystemLabel "ESD-USB" -ErrorAction SilentlyContinue | Select-Object DriveLetter -ExpandProperty DriveLetter
if ($NO_IMPORT -ne 'y') {
    if (-not $TARGET) {
        Write-Output "No setup drive detected. That's ok, you can still choose to backup the WIM or generate a new ISO from this image."
    } else {
        $choice = Read-Host "Would you like to overwrite the setup drive's image now? (Y/N)"
        $start = Get-Date
        if ($choice -eq 'y') {
            Write-Output "Updating USB..."
            if ((Get-ChildItem "$local_esd" | Select-Object Length -ExpandProperty Length) -lt 4GB) {
                Copy-Item -Path "$local_esd" -Destination "${TARGET}:\sources\install.esd" -Force
            } else {
                Split-WindowsImage -ImagePath "$local_esd" -SplitImagePath "${TARGET}:\sources\install.swm" -FileSize 3800 -CheckIntegrity
            }
            Copy-Item -Path "$PSCommandPath\..\..\config\`$OEM`$" -Destination "${TARGET}:\sources" -Recurse -Force
            Write-Output "All done! Setup drive mods complete."
        }
        $finish = Get-Date
        $elapsed = ($finish - $start) + $elapsed
        Write-Output ("Elapsed time (overwrite): " + (($finish - $start).TotalMinutes -replace '\.\d+', '') + " min. ")
    }
}

# ADDITIONAL STAGE 1: Backup WIM
if ($NO_IMPORT -ne 'y') {
    $choice = Read-Host "Would you like to save a copy of the new image locally? (Y/N)"
    if ($choice -eq 'y') {
        $selectorWIM = New-Object System.Windows.Forms.FolderBrowserDialog
        $selectorWIM.Description = "Choose a good folder for backup"
        $selectorWIM.ShowNewFolderButton = $true
        if ($selectorWIM.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Copy-Item -Path "$WIM" -Destination $selectorWIM.SelectedPath
            Copy-Item -Path "$local_esd" -Destination $selectorWIM.SelectedPath -ErrorAction SilentlyContinue
            if (Test-Path -Path ($selectorWIM.SelectedPath + "\install.wim")) {
                Write-Output ("Results saved to: " + $selectorWIM.SelectedPath);
                Get-ChildItem -Path $selectorWIM.SelectedPath | Select-Object Name, Length, Directory, LastWriteTime | Format-Table
            } else {
                Write-Output "WARNING - Backup not finished. Please try again. Skipping cleanup..."
                Write-Output ("Results exported to: " + ($WIM -replace '\\install.wim', ''))
                Get-ChildItem -Path ($WIM -replace '\\install.wim', '') | Select-Object Name, Length, Directory, LastWriteTime | Format-Table
                exit
            }
        }
    }
}

# ADDITIONAL STAGE 2: Build new ISO (optional)
$choice = Read-Host "Would you like to build your own custom ISO? (Y/N)"
if ($choice -eq 'y') {
    $selectorISO = New-Object System.Windows.Forms.FolderBrowserDialog
    $selectorISO.Description = "Select ISO save path" # Ventoy for instance
    $selectorISO.ShowNewFolderButton = $true
    if ($selectorISO.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Copy-Item -Path "$($SRC[0]):\*" -Destination "$BUILD" -Recurse
        Copy-Item -Path "$PSCommandPath\..\..\config\`$OEM`$" -Destination "$BUILD" -Recurse
        & "$PSCommandPath\..\..\lib\oscdimg.exe" -m -o -u2 -udfver102 "-bootdata:2#p0,e,b$($BUILD)\boot\etfsboot.com#pEF,e,b$($BUILD)\efi\microsoft\boot\efisys.bin" "$BUILD" "$($selectorISO.SelectedPath)\WIM-Debloat.iso"
    }
    if (Test-Path -Path ($selectorISO.SelectedPath + "\WIM-Debloat.iso")) {
        Write-Output "New ISO saved successfully."
    } else {
        Write-Output "WARNING - Something went wrong. Check source permissions."
    }
}

$finish = Get-Date
$elapsed = ($finish - $start) + $elapsed
Write-Output ("Elapsed time (total): " + ($elapsed.TotalMinutes -replace '\.\d+', '') + " min.")

Remove-Item -Path "$env:TEMP\Debloat" -Recurse -Force -ErrorAction SilentlyContinue
