Option Strict Off
Option Explicit On
Imports System.Runtime.InteropServices

Module Module1

    Public Const MediaNumMax As Integer = 32    'Number of paper size

    Public Const COLOR_RED As Short = &HFFS
    Public Const COLOR_WHITE As Integer = &HFFFFFF
    Public Const COLOR_BLUE As Integer = &HFFFFC0
    Public Const COLOR_GRAY As Integer = &HC0C0C0

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

    '---------------------------------------------------------
    ' Get printer status
    '---------------------------------------------------------
    Function GetStateStr(ByVal UsbPort As Integer) As String
        Dim state As Integer
        Dim stateStr As String

        stateStr = ""

        state = GetStatus(UsbPort)
        If state And GROUP_USUALLY Then
            Select Case state
                Case STATUS_USUALLY_IDLE : stateStr = "Idle"
                Case STATUS_USUALLY_PRINTING : stateStr = "Printing"
                Case STATUS_USUALLY_STANDSTILL : stateStr = "STANDSTILL"
                Case STATUS_USUALLY_PAPER_END : stateStr = "Paper End"
                Case STATUS_USUALLY_RIBBON_END : stateStr = "Ribbon End"
                Case STATUS_USUALLY_COOLING : stateStr = "Head Cooling Down"
                Case STATUS_USUALLY_MOTCOOLING : stateStr = "Motor Cooling Down"
            End Select
        ElseIf state And GROUP_SETTING Then
            Select Case state
                Case STATUS_SETTING_COVER_OPEN : stateStr = "Cover Open"
                Case STATUS_SETTING_PAPER_JAM : stateStr = "Paper Jam"
                Case STATUS_SETTING_RIBBON_ERR : stateStr = "Ribbon Error"
                Case STATUS_SETTING_PAPER_ERR : stateStr = "Paper definition Error"
                Case STATUS_SETTING_DATA_ERR : stateStr = "Data Error"
                Case STATUS_SETTING_SCRAPBOX_ERR : stateStr = "Scrap Box Error"
            End Select
        ElseIf state And GROUP_HARDWARE Then
            Select Case state
                Case STATUS_HARDWARE_ERR01 : stateStr = "Head Voltage Error"
                Case STATUS_HARDWARE_ERR02 : stateStr = "Head Position Error"
                Case STATUS_HARDWARE_ERR03 : stateStr = "Fan Stop Error"
                Case STATUS_HARDWARE_ERR04 : stateStr = "Cutter Error"
                Case STATUS_HARDWARE_ERR05 : stateStr = "Pinch Roller Error"
                Case STATUS_HARDWARE_ERR06 : stateStr = "Illegal Head Temperature"
                Case STATUS_HARDWARE_ERR07 : stateStr = "Illegal Media Temperature"
                Case STATUS_HARDWARE_ERR08 : stateStr = "Ribbon Tension Error"
                Case STATUS_HARDWARE_ERR09 : stateStr = "RFID Module Error"
                Case STATUS_HARDWARE_ERR10 : stateStr = "Illegal Motor Temperature"
            End Select
        ElseIf state And GROUP_SYSTEM Then
            stateStr = "SYSTEM ERROR"
        ElseIf state And GROUP_FLSHPROG Then
            stateStr = "FLSHPROG MODE"
        ElseIf state < 0 Then
            stateStr = " ---"
        End If

        GetStateStr = stateStr

    End Function

End Module
