Imports System.Runtime.InteropServices

Module Devmode1

    Public PrinterName As String

    'Global Memory Flags
    Public Const GMEM_FIXED As Integer = &H0
    Public Const GMEM_MOVEABLE As Integer = &H2
    Public Const GMEM_ZEROINIT As Integer = &H40

    Public Const GHND As Integer = (GMEM_MOVEABLE Or GMEM_ZEROINIT)
    Public Const GPTR As Integer = (GMEM_FIXED Or GMEM_ZEROINIT)

    'Mode selections for the device mode function (DEVMODE)
    Public Const DM_UPDATE As Integer = 1
    Public Const DM_COPY As Integer = 2
    Public Const DM_PROMPT As Integer = 4
    Public Const DM_MODIFY As Integer = 8

    Public Const DM_IN_BUFFER As Integer = DM_MODIFY
    Public Const DM_IN_PROMPT As Integer = DM_PROMPT
    Public Const DM_OUT_BUFFER As Integer = DM_COPY
    Public Const DM_OUT_DEFAULT As Integer = DM_UPDATE

    'Field selection bits   (DEVMODE)
    Public Const DM_ORIENTATION As Integer = &H1
    Public Const DM_PAPERSIZE As Integer = &H2
    Public Const DM_PAPERLENGTH As Integer = &H4
    Public Const DM_PAPERWIDTH As Integer = &H8
    Public Const DM_SCALE As Integer = &H10
    Public Const DM_COPIES As Integer = &H100
    Public Const DM_DEFAULTSOURCE As Integer = &H200
    Public Const DM_PRINTQUALITY As Integer = &H400
    Public Const DM_COLOR As Integer = &H800
    Public Const DM_DUPLEX As Integer = &H1000
    Public Const DM_YRESOLUTION As Integer = &H2000
    Public Const DM_TTOPTION As Integer = &H4000
    Public Const DM_COLLATE As Integer = &H8000
    Public Const DM_FORMNAME As Integer = &H10000
    Public Const DM_LOGPIXELS As Integer = &H20000
    Public Const DM_BITSPERPEL As Integer = &H40000
    Public Const DM_PELSWIDTH As Integer = &H80000
    Public Const DM_PELSHEIGHT As Integer = &H100000
    Public Const DM_DISPLAYFLAGS As Integer = &H200000
    Public Const DM_DISPLAYFREQUENCY As Integer = &H400000
    Public Const DM_ICMMETHOD As Integer = &H800000

    'Orientation selections (DEVMODE)
    Public Const DM_ORIENT_PORTRAIT As Short = 1    'Portrate
    Public Const DM_ORIENT_LANDSCAPE As Short = 2   'Landscape

    'ICM selections (DEVMODE)
    Public Const DM_ICMMETHOD_NONE As Short = 1     'ICM OFF
    Public Const DM_ICMMETHOD_SYSTEM As Short = 2   '    ON

    'Color adjustment (Private DEVMODE)
    Public Const DM_EXCOLORADJ_NONE As Short = 0    'Color Adjustment OFF
    Public Const DM_EXCOLORADJ_DRIVER As Short = 1  '                 ON

    'Border (Private DEVMODE)
    Public Const DM_BORDER_OFF As Short = 0         'Border OFF
    Public Const DM_BORDER_ON As Short = 1          '       ON 

    'Matte (Private DEVMODE)
    Public Const DM_OVERCOA_GLOSSY As Short = 0     'Glossy
    Public Const DM_OVERCOA_MATTE As Short = 1      'Matte

    'Print Re-try (Private DEVMODE)
    Public Const DM_PRN_RETRY_OFF As Short = 0      'Print Re-try OFF
    Public Const DM_PRN_RETRY_ON As Short = 1       '             ON

    'Print Quality (DEVMODE)
    Public Const QUALITY_300x300 As Short = 0       '300x300dpi
    Public Const QUALITY_300x600 As Short = 1       '300x600dpi
    Public Const QUALITY_600x600 As Short = 2       '600x600dpi

    '2inch Cut
    Public Const DM_CUT2INCH_OFF As Short = 0       '2inch Cut OFF
    Public Const DM_CUT2INCH_ON As Short = 1        '2inch Cut ON


    'Top of private DEVMODE
    Public ExDevTop As Integer

    'Size of secured area for private DEVMODE
    Public Const EX_DEV_SIZE As Short = 1024

    'Header of private DEVMODE
    Public Const EX_DEV_SIGN As Integer = &H4D534654 '"MSFT"

    'Position of private DEVMODE
    Public Const ExStrSize As Integer = 0           'Size of private DEVMODE
    Public Const ExSign As Integer = 1              'Header("MSFT")
    Public Const ExVer As Integer = 2               'Version of private DEVMODE
    Public Const ExBorder As Integer = 3            'Border
    Public Const ExColorAdjustment As Integer = 4   'Color Adjustment
    Public Const ExSharpness As Integer = 5         'Sharpness
    Public Const ExAdjGammaR As Integer = 6         'Gamma R
    Public Const ExAdjGammaG As Integer = 7         '      G
    Public Const ExAdjGammaB As Integer = 8         '      B
    Public Const ExAdjBrightnessR As Integer = 10   'Brightness R
    Public Const ExAdjBrightnessG As Integer = 11   '           G
    Public Const ExAdjBrightnessB As Integer = 12   '           B
    Public Const ExAdjContrastR As Integer = 14     'Contrast R
    Public Const ExAdjContrastG As Integer = 15     '         G
    Public Const ExAdjContrastB As Integer = 16     '         B
    Public Const ExAdjChromaR As Integer = 18       'Chroma R
    Public Const ExAdjChromaG As Integer = 19       '       G
    Public Const ExAdjChromaB As Integer = 20       '       B
    Public Const ExOvercoarFinish As Integer = 27   'OvercoarFinishÅiGlossy /MatteÅj
    Public Const ExPrintRetry As Integer = 29       'Print Re-try
    Public Const ExCut2inch As Integer = 30         '2inch Cut

    Declare Function CreateDC Lib "gdi32" Alias "CreateDCA" ( _
                ByVal lpDriverName As String, _
                 ByVal lpDeviceName As String, _
                 ByVal lpOutput As String, _
                 ByVal lpInitData As IntPtr) As Integer

    Public Declare Function ResetDC Lib "gdi32" Alias "ResetDCA" ( _
                 ByVal hdc As Integer, _
                 ByRef lpInitData As IntPtr) As Integer

    Declare Function DocumentProperties Lib "winspool.drv" Alias "DocumentPropertiesW" _
                (ByVal hwnd As Integer, _
                 ByVal hPrinter As Integer, _
                 ByVal pDeviceName As String, _
                 ByVal pDevModeOutput As IntPtr, _
                 ByVal pDevModeInput As IntPtr, _
                 ByVal fMode As Integer) As Integer

    Public Declare Function GlobalAlloc Lib "kernel32" _
                (ByVal uFlags As Short, _
                 ByVal dwBytes As Integer) As Integer

    Public Declare Function GlobalFree Lib "kernel32" _
                (ByVal hMem As Integer) As Integer

    Public Declare Function GlobalLock Lib "kernel32" _
                (ByVal hMem As Integer) As Integer

    'Structure of print setting
    Structure PRINT_SETTING
        Dim PaperSize As Short
        Dim Orientation As Short
        Dim PrintQuality As Short
        Dim YResolution As Short
        Dim ICMMethod As Integer
        Dim Border As Integer
        Dim Sharpness As Integer
        Dim ColorAdjustment As Integer
        Dim AdjGammaR As Integer
        Dim AdjGammaG As Integer
        Dim AdjGammaB As Integer
        Dim AdjBrightnessR As Integer
        Dim AdjBrightnessG As Integer
        Dim AdjBrightnessB As Integer
        Dim AdjContrastR As Integer
        Dim AdjContrastG As Integer
        Dim AdjContrastB As Integer
        Dim AdjChromaR As Integer
        Dim AdjChromaG As Integer
        Dim AdjChromaB As Integer
        Dim OvercoatFinish As Integer
        Dim PrintRetry As Integer
        Dim Cut2inch As Integer
    End Structure

    '--------------------------------------------
    ' Structure of DEVMODE-W (for Print Document)
    '--------------------------------------------
    <StructLayout(LayoutKind.Sequential)> _
    Public Structure DEVMODEW
        Const CCHDEVICENAME As Integer = (32 * 2)
        Const CCHFORMNAME As Integer = (32 * 2)

        <VBFixedArray(CCHDEVICENAME - 1), _
            MarshalAs(UnmanagedType.ByValArray, _
            SizeConst:=CCHDEVICENAME)> Public dmDeviceName As Byte()

        Dim dmSpecVersion As Short
        Dim dmDriverVersion As Short
        Dim dmSize As Short
        Dim dmDriverExtra As Short
        Dim dmFields As Integer
        Dim dmOrientation As Short
        Dim dmPaperSize As Short
        Dim dmPaperLength As Short
        Dim dmPaperWidth As Short
        Dim dmScale As Short
        Dim dmCopies As Short
        Dim dmDefaultSource As Short
        Dim dmPrintQuality As Short
        Dim dmColor As Short
        Dim dmDuplex As Short
        Dim dmYResolution As Short
        Dim dmTTOption As Short
        Dim dmCollate As Short

        <VBFixedArray(CCHFORMNAME - 1), _
            MarshalAs(UnmanagedType.ByValArray, _
            SizeConst:=CCHFORMNAME)> Public dmFormName As Byte()

        Dim dmUnusedPadding As Short
        Dim dmBitsPerPel As Integer
        Dim dmPelsWidth As Integer
        Dim dmPelsHeight As Integer
        Dim dmDisplayFlags As Integer
        Dim dmDisplayFrequency As Integer
        Dim dmICMMethod As Integer
        Dim dmICMIntent As Integer
        Dim dmMediaType As Integer
        Dim dmDitherType As Integer
        Dim dmICCManufacturer As Integer
        Dim dmICCModel As Integer
        Dim dmPanningWidth As Integer
        Dim dmPanningHeight As Integer

        'Private DevMode
        <VBFixedArray(EX_DEV_SIZE - 1), _
        MarshalAs(UnmanagedType.ByValArray, _
        SizeConst:=EX_DEV_SIZE)> Public ExDevMode() As Integer

    End Structure

    Private Declare Sub Mem2DevCopy Lib "kernel32" Alias "RtlMoveMemory" _
                            (ByRef hpvDest As DEVMODEW, _
                             ByVal hpvSource As IntPtr, _
                             ByVal cbCopy As Integer)

    Private Declare Sub Dev2MemCopy Lib "kernel32" Alias "RtlMoveMemory" _
                        (ByVal hpvDest As IntPtr, _
                         ByRef hpvSource As DEVMODEW, _
                         ByVal cbCopy As Integer)

    '---------------------------------------------------------
    'Searches for top of the private DevMode
    '---------------------------------------------------------
    Public Sub ExDevModeTopSearch()
        Dim hPrinter As IntPtr
        Dim ResultCode As Integer
        Dim DevModeSize As Integer
        Dim dmw As DEVMODEW = Nothing
        Dim hDevMode As Integer
        Dim lpDevModeDmW As IntPtr
        Dim n As Integer

        ResultCode = OpenPrinter(PrinterName, hPrinter, IntPtr.Zero)
        DevModeSize = DocumentProperties(0, hPrinter, PrinterName, IntPtr.Zero, IntPtr.Zero, 0)
        If DevModeSize = 0 Then
            ClosePrinter(hPrinter)
            Exit Sub
        End If

        hDevMode = GlobalAlloc(GHND, DevModeSize)
        lpDevModeDmW = GlobalLock(hDevMode)
        ResultCode = DocumentProperties(0, hPrinter, PrinterName, lpDevModeDmW, 0, DM_OUT_BUFFER)
        If ResultCode < 0 Then
            GlobalFree(lpDevModeDmW)
            ClosePrinter(hPrinter)
            Exit Sub
        End If

        Mem2DevCopy(dmw, lpDevModeDmW, DevModeSize)

        n = 0
        Do
            If dmw.ExDevMode(n) = EX_DEV_SIGN Then
                ExDevTop = n - 1    'Top position
                Exit Do
            End If

            If n >= EX_DEV_SIZE Then
                Exit Do             '"MSFT" is not found. 
            End If
            n = n + 1
        Loop

        GlobalFree(lpDevModeDmW)
        ClosePrinter(hPrinter)

    End Sub

    '---------------------------------------------------------
    'print setting
    '---------------------------------------------------------
    Public Sub PrintSetting(ByRef PrnSet As PRINT_SETTING, ByRef pd As System.Drawing.Printing.PrintDocument)
        Dim hPrinter As IntPtr
        Dim ResultCode As Integer
        Dim DevModeSize As Integer
        Dim dmw As DEVMODEW = Nothing

        Dim hDevMode As Integer
        Dim lpDevModeDmW As IntPtr

        ResultCode = OpenPrinter(PrinterName, hPrinter, IntPtr.Zero)
        DevModeSize = DocumentProperties(0, hPrinter, PrinterName, IntPtr.Zero, IntPtr.Zero, 0)
        If DevModeSize = 0 Then
            ClosePrinter(hPrinter)
            Exit Sub
        End If

        hDevMode = GlobalAlloc(GHND, DevModeSize)
        lpDevModeDmW = GlobalLock(hDevMode)

        ResultCode = DocumentProperties(0, hPrinter, PrinterName, lpDevModeDmW, IntPtr.Zero, DM_OUT_BUFFER)
        If ResultCode < 0 Then
            GlobalFree(lpDevModeDmW)
            ClosePrinter(hPrinter)
            Exit Sub
        End If

        Mem2DevCopy(dmw, lpDevModeDmW, DevModeSize)

        '----------------------
        'Setting of DevMode
        '----------------------
        'Paper size
        dmw.dmPaperSize = PrnSet.PaperSize

        'Orientation
        dmw.dmOrientation = PrnSet.Orientation

        'Border
        dmw.ExDevMode(ExDevTop + ExBorder) = PrnSet.Border

        'Sharpness
        dmw.ExDevMode(ExDevTop + ExSharpness) = PrnSet.Sharpness

        'Resolution
        dmw.dmPrintQuality = PrnSet.PrintQuality
        dmw.dmYResolution = PrnSet.YResolution

        'ICM
        dmw.dmICMMethod = PrnSet.ICMMethod

        'Color Adjustment
        dmw.ExDevMode(ExDevTop + ExColorAdjustment) = PrnSet.ColorAdjustment
        'Gamma
        dmw.ExDevMode(ExDevTop + ExAdjGammaR) = PrnSet.AdjGammaR
        dmw.ExDevMode(ExDevTop + ExAdjGammaG) = PrnSet.AdjGammaG
        dmw.ExDevMode(ExDevTop + ExAdjGammaB) = PrnSet.AdjGammaG
        'Brightness
        dmw.ExDevMode(ExDevTop + ExAdjBrightnessR) = PrnSet.AdjBrightnessR
        dmw.ExDevMode(ExDevTop + ExAdjBrightnessG) = PrnSet.AdjBrightnessG
        dmw.ExDevMode(ExDevTop + ExAdjBrightnessB) = PrnSet.AdjBrightnessB
        'Contrast
        dmw.ExDevMode(ExDevTop + ExAdjContrastR) = PrnSet.AdjContrastR
        dmw.ExDevMode(ExDevTop + ExAdjContrastG) = PrnSet.AdjContrastR
        dmw.ExDevMode(ExDevTop + ExAdjContrastB) = PrnSet.AdjContrastR
        'Chroma
        dmw.ExDevMode(ExDevTop + ExAdjChromaR) = PrnSet.AdjChromaR
        dmw.ExDevMode(ExDevTop + ExAdjChromaG) = PrnSet.AdjChromaG
        dmw.ExDevMode(ExDevTop + ExAdjChromaB) = PrnSet.AdjChromaB

        'Overcoar Finish
        dmw.ExDevMode(ExDevTop + ExOvercoarFinish) = PrnSet.OvercoatFinish

        'Print Re-try
        dmw.ExDevMode(ExDevTop + ExPrintRetry) = PrnSet.PrintRetry

        '2inch Cut
        If PrinterModel = PRN_6IN Then
            dmw.ExDevMode(ExDevTop + ExCut2inch) = PrnSet.Cut2inch
        End If

        dmw.dmFields = dmw.dmFields Or DM_PAPERSIZE Or DM_PRINTQUALITY Or DM_YRESOLUTION Or DM_ORIENTATION Or DM_ICMMETHOD
        dmw.dmFields = dmw.dmFields And (DM_PAPERLENGTH Xor &HFFFFFFFF) And (DM_PAPERWIDTH Xor &HFFFFFFFF)

        Call Dev2MemCopy(lpDevModeDmW, dmw, DevModeSize)
        ClosePrinter(hPrinter)
        pd.PrinterSettings.SetHdevmode(lpDevModeDmW)
        ResultCode = GlobalFree(lpDevModeDmW)
    End Sub

End Module
