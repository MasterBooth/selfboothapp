Option Strict Off
Option Explicit On
Imports System.Runtime.InteropServices
Imports System.ComponentModel
Module pJob

    'Declaration of the structure which defines the printer access rights
    Structure PRINTER_DEFAULTS
        Dim pDatatype As Integer
        Dim pDevMode As Integer
        Dim DesiredAccess As Integer
    End Structure

    'Declaration of the function which enumerates printer print jobs
    Declare Function EnumJobs Lib "winspool.drv" Alias "EnumJobsA" ( _
                    ByVal hPrinter As Integer, _
                    ByVal FirstJob As Integer, _
                    ByVal NoJobs As Integer, _
                    ByVal Level As Integer, _
                    ByRef pJob As IntPtr, _
                    ByVal cdBuf As Integer, _
                    ByRef pcbNeeded As Integer, _
                    ByRef pcReturned As Integer) As Integer

    '---------------------------------------------------------
    ' Checking for existence of printer print jobs.
    '---------------------------------------------------------
    Function CheckPrnJob(ByVal pName As String) As Boolean
        'Dim pDefaults As PRINTER_DEFAULTS
        Dim pcbNeeded As Integer
        Dim NoJobs As Integer
        Dim hPrinter As Integer
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

        If pcbNeeded = 0 Then
            CheckPrnJob = False 'print job exists
        Else
            CheckPrnJob = True  'Print job does not exist
        End If
    End Function
End Module