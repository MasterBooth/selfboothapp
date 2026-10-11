<#
.SYNOPSIS
    Tắt power-saving trên các USB hub/controller để máy ảnh không bị Windows
    cắt nguồn cổng USB sau một thời gian idle (gây rớt kết nối).

.DESCRIPTION
    Chạy MỘT LẦN khi setup máy booth (cần quyền Administrator). Script làm 2 việc:

      1. Tắt "USB selective suspend" trên power-plan đang dùng (AC + DC).
         (App cũng tự làm việc này mỗi lần khởi động, nhưng để ở đây cho máy
          nào không chạy qua app vẫn được cấu hình.)

      2. Bỏ tick "Allow the computer to turn off this device to save power"
         trên mọi USB hub — qua WMI MSPower_DeviceEnable.

    Sau khi chạy: kiểm tra Device Manager → từng "USB Root Hub" / "Generic USB Hub"
    → tab Power Management → ô tick đã được bỏ.

.NOTES
    Chạy:  Right-click → Run with PowerShell (as Administrator)
       hoặc:  powershell -ExecutionPolicy Bypass -File disable-usb-power-saving.ps1
#>

#Requires -RunAsAdministrator

Write-Host "=== Tắt USB power-saving cho máy booth ===" -ForegroundColor Cyan

# ── 1. USB selective suspend OFF trên power-plan hiện hành ────────────────────
$subUsb = "2a737441-1930-4402-8d77-b2bebba308a3"   # SUB_USB
$item   = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"   # USB selective suspend setting

powercfg /SETACVALUEINDEX SCHEME_CURRENT $subUsb $item 0
powercfg /SETDCVALUEINDEX SCHEME_CURRENT $subUsb $item 0
powercfg /SETACTIVE SCHEME_CURRENT
Write-Host "[1/2] Đã tắt USB selective suspend (AC + DC)." -ForegroundColor Green

# ── 2. Bỏ "Allow the computer to turn off this device" trên các USB hub ───────
# MSPower_DeviceEnable.Enable = $false  → Windows KHÔNG được tắt thiết bị.
$count = 0
try {
    $hubs = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction Stop
    foreach ($h in $hubs) {
        try {
            Set-CimInstance -InputObject $h -Property @{ Enable = $false } -ErrorAction Stop
            $count++
        } catch {
            Write-Warning "Không set được trên instance: $($h.InstanceName)"
        }
    }
    Write-Host "[2/2] Đã tắt power-management trên $count thiết bị USB." -ForegroundColor Green
} catch {
    Write-Warning "Không truy cập được MSPower_DeviceEnable: $($_.Exception.Message)"
    Write-Warning "Hãy chắc chắn đang chạy với quyền Administrator."
}

Write-Host "Hoàn tất. Khuyến nghị khởi động lại máy để áp dụng triệt để." -ForegroundColor Cyan
