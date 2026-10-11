Option Strict Off
Option Explicit On
Imports System.Runtime.InteropServices
Module pJob

    Structure PRINTER_DEFAULTS
        Dim pDatatype As Integer
        Dim pDevMode As Integer
        Dim DesiredAccess As Integer
    End Structure

    <DllImport("winspool.Drv", EntryPoint:="OpenPrinterW", _
       SetLastError:=True, CharSet:=CharSet.Unicode, _
       ExactSpelling:=True, CallingConvention:=CallingConvention.StdCall)> _
    Public Function OpenPrinter(ByVal src As String, ByRef hPrinter As IntPtr, ByVal pd As IntPtr) As Boolean
    End Function

    <DllImport("winspool.Drv", EntryPoint:="EnumJobsA", _
       SetLastError:=True, CharSet:=CharSet.Unicode, _
       ExactSpelling:=True, CallingConvention:=CallingConvention.StdCall)> _
    Public Function EnumJobs(ByVal hPrinter As Integer, ByVal FirstJob As Integer, ByVal NoJobs As Integer, _
        ByVal Level As Integer, ByRef pJob As IntPtr, ByVal cdBuf As Integer, ByRef pcbNeeded As Integer, ByRef pcReturned As Integer) As Integer
    End Function

    <DllImport("winspool.Drv", EntryPoint:="ClosePrinter", _
       SetLastError:=True, CharSet:=CharSet.Unicode, _
       ExactSpelling:=True, CallingConvention:=CallingConvention.StdCall)> _
    Public Function ClosePrinter(ByVal hPrinter As IntPtr) As Boolean
    End Function

    <DllImport("kernel32", SetLastError:=True)> _
    Public Sub Sleep( _
            ByVal dwMilliseconds As Integer)
    End Sub


    ' Checking for existence of printer print jobs.
    Function CheckPrnJob(ByVal pName As String) As Boolean
        Dim pcbNeeded As Integer
        Dim NoJobs As Integer
        Dim hPrinter As IntPtr
        Dim FirstJob As Integer
        Dim Level As Integer
        Dim pcReturned As Integer
        Dim ResultCode As Integer
        FirstJob = 0
        NoJobs = 10
        Level = 1

        ResultCode = OpenPrinter(pName, hPrinter, IntPtr.Zero)
        ResultCode = EnumJobs(hPrinter, FirstJob, NoJobs, Level, IntPtr.Zero, 0, pcbNeeded, pcReturned)
        ResultCode = ClosePrinter(hPrinter)
        CheckPrnJob = pcbNeeded <> 0
    End Function

End Module