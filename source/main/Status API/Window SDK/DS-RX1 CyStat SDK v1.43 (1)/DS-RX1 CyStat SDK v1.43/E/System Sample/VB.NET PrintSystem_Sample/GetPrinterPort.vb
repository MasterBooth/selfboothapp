Option Strict Off
Option Explicit On
Imports System.Runtime.InteropServices
Imports System.ComponentModel


Module GetCvPort
    <DllImport("kernel32.dll", EntryPoint:="lstrlenA", _
       SetLastError:=True, CharSet:=CharSet.Unicode, _
       ExactSpelling:=True, CallingConvention:=CallingConvention.StdCall)> _
    Private Function lstrlen(ByVal lpString As IntPtr) As Integer
    End Function

    <DllImport("winspool.Drv", EntryPoint:="OpenPrinterW", _
        SetLastError:=True, CharSet:=CharSet.Unicode, _
        ExactSpelling:=True, CallingConvention:=CallingConvention.StdCall)> _
     Private Function OpenPrinter(ByVal src As String, ByRef hPrinter As IntPtr, ByVal pd As Integer) As Boolean
    End Function

    <DllImport("winspool.Drv", EntryPoint:="EnumJobsA", _
       SetLastError:=True, CharSet:=CharSet.Unicode, _
       ExactSpelling:=True, CallingConvention:=CallingConvention.StdCall)> _
    Private Function EnumJobs(ByVal hPrinter As Integer, ByVal FirstJob As Integer, ByVal NoJobs As Integer, _
        ByVal Level As Integer, ByRef pJob As IntPtr, ByVal cdBuf As Integer, ByRef pcbNeeded As Integer, ByRef pcReturned As Integer) As Integer
    End Function

    <DllImport("winspool.Drv", EntryPoint:="ClosePrinter", _
       SetLastError:=True, CharSet:=CharSet.Unicode, _
       ExactSpelling:=True, CallingConvention:=CallingConvention.StdCall)> _
    Private Function ClosePrinter(ByVal hPrinter As IntPtr) As Boolean
    End Function

    <DllImport("winspool.drv", SetLastError:=True)> _
    Private Function GetPrinter( _
        ByVal hPrinter As IntPtr, ByVal dwLevel As Integer, _
        ByVal pPrinter As IntPtr, ByVal cbBuf As Integer, _
        ByRef pcbNeeded As Integer) As Boolean
    End Function

    <StructLayout(LayoutKind.Sequential, CharSet:=CharSet.Auto)> _
    Public Structure PRINTER_INFO_5
        Public pPrinterName As IntPtr
        Public pPortName As IntPtr
        Public Attributes As Integer
        Public DeviceNotSelectedTimeout As Integer
        Public TransmissionRetryTimeout As Integer
    End Structure

    Private Const PRINTER_ATTRIBUTE_DEFAULT As Integer = &H4
    Private Const PRINTER_ATTRIBUTE_ENABLE_BIDI As Integer = &H800 '‘o•ûŒü
    Private Const PRINTER_ATTRIBUTE_WORK_OFFLINE As Integer = &H400 'OFFLINE

    '==================================================================
    '
    '==================================================================
    Public Function GetPortName(ByRef strPrinterDeviceName As String) As String
        Dim lngPrinterInfo5Level As Integer
        Dim lngPrinterInfo5Needed As Integer
        Dim bytPortName As Byte()
        Dim temp As Integer

        GetPortName = ""
        lngPrinterInfo5Level = 5

        'Get printer handle
        Dim hPrinter As IntPtr
        If Not OpenPrinter(strPrinterDeviceName, hPrinter, IntPtr.Zero) Then
            Throw New Win32Exception(Marshal.GetLastWin32Error())
        End If

        Dim pPrinterInfo As IntPtr = IntPtr.Zero

        Try
            GetPrinter(hPrinter, lngPrinterInfo5Level, vbNullString, 0, lngPrinterInfo5Needed)
            If lngPrinterInfo5Needed <= 0 Then
                Throw New Exception("error!")
            End If
            pPrinterInfo = Marshal.AllocHGlobal(lngPrinterInfo5Needed)

            'Get printer information
            If Not GetPrinter(hPrinter, lngPrinterInfo5Level, pPrinterInfo, lngPrinterInfo5Needed, temp) Then
                Throw New Win32Exception(Marshal.GetLastWin32Error())
            End If

            Dim printerInfo As PRINTER_INFO_5 = _
                CType(Marshal.PtrToStructure( _
                pPrinterInfo, GetType(PRINTER_INFO_5)), PRINTER_INFO_5)

            If (printerInfo.Attributes And PRINTER_ATTRIBUTE_WORK_OFFLINE) = 0 Then
                Dim size As Integer = lstrlen(printerInfo.pPortName)

                ReDim bytPortName(size)
                Marshal.Copy(printerInfo.pPortName, bytPortName, 0, size)
                GetPortName = System.Text.Encoding.GetEncoding("Shift_JIS").GetString(bytPortName)
            Else
                GetPortName = "OFF LINE"
            End If
        Finally
            ClosePrinter(hPrinter)
            Marshal.FreeHGlobal(pPrinterInfo)
        End Try

    End Function

    '==================================================================
    '
    '==================================================================
    Public Function PrnSearch(ByVal strPrinterDeviceName As String) As Boolean
        PrnSearch = False
        For Each strprinter As String In Printing.PrinterSettings.InstalledPrinters
            If strprinter = strPrinterDeviceName Then
                PrnSearch = True
            End If
        Next
    End Function

End Module