Imports System.Runtime.InteropServices

Module Paper
    'Paper size information
    Structure StructPaperSize
        Dim Name As String      'size name
        Dim Number As Integer   'size number
        Dim MultiCut As Integer 'number of page
    End Structure

    Public PaperSize(MediaNumMax - 1) As StructPaperSize

    Declare Function DeviceCapabilities Lib "winspool.drv" Alias "DeviceCapabilitiesA" ( _
            ByVal pDevice As String, _
            ByVal pPort As String, _
            ByVal fwCapability As Integer, _
            ByVal pOutput As IntPtr, _
            ByVal pDevMode As IntPtr) As Integer

    Declare Sub MoveMemory Lib "kernel32.dll" Alias "RtlMoveMemory" ( _
            ByVal Destination As String, _
            ByVal Source As IntPtr, _
            ByVal Length As Integer)


    Const DC_PAPERNAMES As Int32 = 16
    Const DC_PAPERS As Int32 = 2

    Public PrinterModel As Short
    Public Const PRN_6IN As Short = 0
    Public Const PRN_8IN As Short = 1


    '----------------------------------------------------------
    ' Get paper size information
    '----------------------------------------------------------
    Public Sub GetPaperSizeInfo()
        GetPaperSizeName()      'Get paper size name
        GetPaperSizeNumber()    'Get paper size number
        MultiCutNum()           'Set multi cut number
    End Sub


    '----------------------------------------------------------
    ' Get paper size name
    '----------------------------------------------------------
    Public Sub GetPaperSizeName()
        Dim strPrnName As String
        Dim strPortName As String
        Dim lngBuffSize As Integer
        Dim bytPaperName() As Byte
        Dim strTempBuffer As String
        Dim lngRetCode As Integer
        Dim n As Integer, m As Integer

        strPrnName = PrinterName
        strPortName = GetPortName(strPrnName)

        lngBuffSize = DeviceCapabilities(strPrnName, strPortName, DC_PAPERNAMES, IntPtr.Zero, IntPtr.Zero)

        ReDim bytPaperName(lngBuffSize * 64)

        Dim gchPn As GCHandle = GCHandle.Alloc(bytPaperName, GCHandleType.Pinned)
        Dim lpPn As Integer = gchPn.AddrOfPinnedObject().ToInt32()
        lngRetCode = DeviceCapabilities(strPrnName, strPortName, DC_PAPERNAMES, lpPn, IntPtr.Zero)
        gchPn.Free()

        Dim b As Byte

        For n = 0 To lngBuffSize - 1
            strTempBuffer = ""
            For m = 0 To 64 - 1
                b = bytPaperName((n * 64) + m)
                If b = 0 Then Exit For
                strTempBuffer = strTempBuffer & CType(ChrW(b), Char)
            Next m
            PaperSize(n).Name = strTempBuffer
        Next n

    End Sub


    '----------------------------------------------------------
    ' Get paper size number
    '----------------------------------------------------------
    Public Sub GetPaperSizeNumber()
        Dim strPrnName As String
        Dim strPortName As String
        Dim intOutPut() As Short
        Dim lngBuffSize As Integer
        Dim lngRetCode As Integer
        Dim n As Integer

        strPrnName = PrinterName
        strPortName = GetPortName(strPrnName)

        lngBuffSize = DeviceCapabilities(strPrnName, strPortName, DC_PAPERS, IntPtr.Zero, IntPtr.Zero)

        ReDim intOutPut(lngBuffSize - 1)

        Dim gchPn As GCHandle = GCHandle.Alloc(intOutPut, GCHandleType.Pinned)
        Dim lpPn As Integer = gchPn.AddrOfPinnedObject().ToInt32()
        lngRetCode = DeviceCapabilities(strPrnName, strPortName, DC_PAPERS, lpPn, IntPtr.Zero)
        gchPn.Free()

        For n = 0 To lngBuffSize - 1
            PaperSize(n).Number = intOutPut(n)
        Next n

    End Sub


    '----------------------------------------------------------
    ' Set multi cut number
    '----------------------------------------------------------
    Public Sub MultiCutNum()
        Dim n As Integer

        For n = 0 To MediaNumMax - 1

            PaperSize(n).MultiCut = 1          'clear

            Select Case PaperSize(n).Name

                Case "(5x3.5)", "(5x7)", "(6x4)", "(6x8)", "(6x9)", "PR (4x6)", "PR (3.5x5)"
                    PaperSize(n).MultiCut = 1

                Case "(6x4) x 2", "PR (4x6) x 2", "(5x3.5) x 2", "PR (3.5x5) x 2"
                    PaperSize(n).MultiCut = 2

                Case Else
                    PaperSize(n).MultiCut = 1

            End Select

        Next n

    End Sub

End Module
