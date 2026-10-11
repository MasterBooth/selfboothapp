Option Strict Off
Option Explicit On
Imports System.Runtime.InteropServices

Friend Class Form1
    Inherits System.Windows.Forms.Form

    Private PortName As String                  'USB port name
    Private PortNo As Integer                   'Port number
    Private FileName(3) As String               'Imege file name
    Private HasMore As Integer                  'Multi cut
    Private CurrentImage As Integer             'Current printed image
    Private PrnSet As PRINT_SETTING             'Structure of print setting


    '*******************************************************
    '
    '   Form Load
    '
    '
    '*******************************************************
    Private Sub Form1_Load(ByVal eventSender As System.Object, ByVal eventArgs As System.EventArgs) Handles MyBase.Load
        Dim n As Integer

        '-----------------------------------------
        'File Path / File Name / Printer Name
        '-----------------------------------------
        FileName(0) = "01.jpg"      'Imege File(PATH/NAME)
        FileName(1) = "02.jpg"      '
        FileName(2) = "03.jpg"      '

        PrinterName = "DS-RX1"      'Printer Name

        '-----------------------------------------
        'Get port name
        '-----------------------------------------
        PortName = GetPortName(PrinterName)
        If PortName = "" Then
            MsgBox("Printer is not connected. ", MsgBoxStyle.OkOnly)
            End
        End If
        PortNo = PortInitialize(PortName) 'Initialize of Status API

        '-----------------------------------------
        'Display of printer name and port name
        '-----------------------------------------
        txtPrinterName.Text = PrinterName
        txtPortName.Text = PortName

        '-----------------------------------------
        'Setting of 2inch Cut combo box
        '-----------------------------------------
        ComboCut2inch.Items.Add(New ComboItem("OFF", DM_CUT2INCH_OFF))
        ComboCut2inch.Items.Add(New ComboItem("ON", DM_CUT2INCH_ON))
        ComboCut2inch.SelectedIndex = 0

        '-----------------------------------------
        'Setting of PaperSize combo box
        '-----------------------------------------
        GetPaperSizeInfo()
        For n = 0 To MediaNumMax
            If PaperSize(n).Name <> "" Then
                ComboPaperSize.Items.Add( _
                            New ComboItem(PaperSize(n).Name, _
                            PaperSize(n).Number))
            Else
                Exit For
            End If
        Next n
        ComboPaperSize.SelectedIndex = 0

        '-----------------------------------------
        'Setting of Orientation combo box
        '-----------------------------------------
        ComboOrientation.Items.Add(New ComboItem("PORTRAIT", DM_ORIENT_PORTRAIT))
        ComboOrientation.Items.Add(New ComboItem("LANDSCAPE", DM_ORIENT_LANDSCAPE))
        ComboOrientation.SelectedIndex = 0

        '-----------------------------------------
        'Setting of Border combo box
        '-----------------------------------------
        ComboBorder.Items.Add(New ComboItem("OFF", DM_BORDER_OFF))
        ComboBorder.Items.Add(New ComboItem("ON", DM_BORDER_ON))
        ComboBorder.SelectedIndex = 0

        '-----------------------------------------
        'Setting of Sharpness combo box
        '-----------------------------------------
        ComboSharpness.Items.Add(New ComboItem("-2 (Blur)", 0))
        ComboSharpness.Items.Add(New ComboItem("-1", 1))
        ComboSharpness.Items.Add(New ComboItem("0 (Default)", 2))
        ComboSharpness.Items.Add(New ComboItem("1", 3))
        ComboSharpness.Items.Add(New ComboItem("2", 4))
        ComboSharpness.Items.Add(New ComboItem("3", 5))
        ComboSharpness.Items.Add(New ComboItem("4", 6))
        ComboSharpness.Items.Add(New ComboItem("5", 7))
        ComboSharpness.Items.Add(New ComboItem("6", 8))
        ComboSharpness.Items.Add(New ComboItem("7", 9))
        ComboSharpness.Items.Add(New ComboItem("8 (Hard)", 10))
        ComboSharpness.SelectedIndex = 2

        '-----------------------------------------
        'Setting of PrintQuality combo box
        '-----------------------------------------
        ComboPrintQuality.Items.Add(New ComboItem("300x300dpi", QUALITY_300x300))
        ComboPrintQuality.Items.Add(New ComboItem("300x600dpi", QUALITY_300x600))
        ComboPrintQuality.Items.Add(New ComboItem("600x600dpi", QUALITY_600x600))
        ComboPrintQuality.SelectedIndex = 0

        '-----------------------------------------
        'Setting of OvercoatFinish combo box
        '-----------------------------------------
        ComboOvercoatFinish.Items.Add(New ComboItem("Glossy", DM_OVERCOA_GLOSSY))
        ComboOvercoatFinish.Items.Add(New ComboItem("Matte", DM_OVERCOA_MATTE))
        ComboOvercoatFinish.SelectedIndex = 0

        '-----------------------------------------
        'Setting of PrintRetry combo box
        '-----------------------------------------
        ComboPrintRetry.Items.Add(New ComboItem("OFF", DM_PRN_RETRY_OFF))
        ComboPrintRetry.Items.Add(New ComboItem("ON", DM_PRN_RETRY_ON))
        ComboPrintRetry.SelectedIndex = 0

        '-----------------------------------------
        'Setting of ICM combo box
        '-----------------------------------------
        ComboICM.Items.Add(New ComboItem("OFF", DM_ICMMETHOD_NONE))
        ComboICM.Items.Add(New ComboItem("ON", DM_ICMMETHOD_SYSTEM))
        ComboICM.SelectedIndex = 0

        '-----------------------------------------
        'Setting of ColorAdjustment combo box
        '-----------------------------------------
        ComboColorAdjustment.Items.Add(New ComboItem("OFF", DM_EXCOLORADJ_NONE))
        ComboColorAdjustment.Items.Add(New ComboItem("ON", DM_EXCOLORADJ_DRIVER))
        ComboColorAdjustment.SelectedIndex = 0

        '-----------------------------------------
        'Initializing of ColorAdjustment
        '-----------------------------------------
        TextBoxGamma.Text = 0
        TextBoxBrightness.Text = 0
        TextBoxContrast.Text = 0
        TextBoxChroma.Text = 0

        '-----------------------------------------
        'Searches for top of the private DevMode
        '-----------------------------------------
        ExDevModeTopSearch()

        Timer1.Enabled = True
    End Sub

    '*******************************************************
    '
    '   Print
    '
    '
    '*******************************************************
    Private Sub Command1_Click(ByVal eventSender As System.Object, ByVal eventArgs As System.EventArgs) Handles Command1.Click

        Timer1.Enabled = False

        pd.PrinterSettings.PrinterName = PrinterName

        '-------------------------------------------
        'Get user setting
        '-------------------------------------------
        'Paper Size
        PrnSet.PaperSize = DirectCast(ComboPaperSize.SelectedItem, ComboItem).Number

        'Orientation
        PrnSet.Orientation = DirectCast(ComboOrientation.SelectedItem, ComboItem).Number
        Dim n As Integer = DirectCast(ComboPrintQuality.SelectedItem, ComboItem).Number

        'Print Quality
        If n = QUALITY_300x300 Then
            PrnSet.PrintQuality = 300
            PrnSet.YResolution = 300
        ElseIf n = QUALITY_300x600 Then
            PrnSet.PrintQuality = 300
            PrnSet.YResolution = 600
        Else
            PrnSet.PrintQuality = 600
            PrnSet.YResolution = 600
        End If

        'Border
        PrnSet.Border = DirectCast(ComboBorder.SelectedItem, ComboItem).Number

        'Sharpness
        PrnSet.Sharpness = DirectCast(ComboSharpness.SelectedItem, ComboItem).Number

        'ICM
        PrnSet.ICMMethod = DirectCast(ComboICM.SelectedItem, ComboItem).Number

        'Color Adjustment
        PrnSet.ColorAdjustment = DirectCast(ComboColorAdjustment.SelectedItem, ComboItem).Number
        'Gamma
        PrnSet.AdjGammaR = Val(TextBoxGamma.Text)
        PrnSet.AdjGammaG = Val(TextBoxGamma.Text)
        PrnSet.AdjGammaG = Val(TextBoxGamma.Text)
        'Brightness
        PrnSet.AdjBrightnessR = Val(TextBoxBrightness.Text)
        PrnSet.AdjBrightnessG = Val(TextBoxBrightness.Text)
        PrnSet.AdjBrightnessB = Val(TextBoxBrightness.Text)
        'Contrast
        PrnSet.AdjContrastR = Val(TextBoxContrast.Text)
        PrnSet.AdjContrastG = Val(TextBoxContrast.Text)
        PrnSet.AdjContrastB = Val(TextBoxContrast.Text)
        'Chroma
        PrnSet.AdjChromaR = Val(TextBoxChroma.Text)
        PrnSet.AdjChromaG = Val(TextBoxChroma.Text)
        PrnSet.AdjChromaB = Val(TextBoxChroma.Text)

        'Overcoat Finish (Glossy/MatteÅj
        PrnSet.OvercoatFinish = DirectCast(ComboOvercoatFinish.SelectedItem, ComboItem).Number

        'Print Re-try
        PrnSet.PrintRetry = DirectCast(ComboPrintRetry.SelectedItem, ComboItem).Number

        '2inch Cut
        PrnSet.Cut2inch = DirectCast(ComboCut2inch.SelectedItem, ComboItem).Number

        '-----------------------------------------
        'Print setting
        '-----------------------------------------
        PrintSetting(PrnSet, pd)
        HasMore = PaperSize(ComboPaperSize.SelectedIndex).MultiCut
        CurrentImage = 0

        '-----------------------------------------
        'Print
        '-----------------------------------------
        pd.Print()
        Timer1.Enabled = True

    End Sub

    '-----------------------------------------
    'PrintPage Handler
    '-----------------------------------------
    Private Sub pd_PrintPage(ByVal sender As Object, ByVal e As System.Drawing.Printing.PrintPageEventArgs) Handles pd.PrintPage
        Dim img As Image = Image1.Image
        Dim Ratio As Single = e.PageBounds.Height / img.Height
        Dim Print_Width As Single = img.Width * Ratio
        Dim Print_Height As Single = img.Height * Ratio

        If Print_Width < e.PageBounds.Width Then
            Ratio = e.PageBounds.Width / img.Width
            Print_Width = img.Width * Ratio
            Print_Height = img.Height * Ratio
        End If

        'Centering
        Dim OverWidth As Single = e.PageBounds.Width - Print_Width
        Dim OverHeight As Single = e.PageBounds.Height - Print_Height
        Dim imgTop As Single = OverWidth / 2
        Dim imgLeft As Single = OverHeight / 2

        e.Graphics.DrawImage(img, imgTop, imgLeft, Print_Width, Print_Height)

        HasMore = HasMore - 1
        e.HasMorePages = (HasMore > 0)

    End Sub

    Protected Sub pd_QueryPageSettings(ByVal sender As Object, ByVal e As QueryPageSettingsEventArgs) Handles pd.QueryPageSettings
        File_Open(FileName(CurrentImage))
        CurrentImage = (CurrentImage + 1) Mod 2
    End Sub

    '*******************************************************
    '
    '   Others
    '
    '
    '*******************************************************
    '-----------------------------------------
    'Get printer information
    '-----------------------------------------
    Private Sub Timer1_Tick(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles Timer1.Tick
        Dim media_counter As Integer
		Dim offset_counter As Integer

        'check the job of the print queue
        If CheckPrnJob(PrinterName) = True Then
            Exit Sub
        End If

        'Printer status
        txtPrinterStatus.Text = GetStateStr(PortNo)

		'Media offset counter
		offset_counter = GetMediaCountOffset(PortNo)
		If -1 = offset_counter Then
			offset_counter = 50
		End If

		'Media counter
		media_counter = GetMediaCounter(PortNo) - offset_counter
        If media_counter < 0 Then media_counter = 0
        txtMediaCounter.Text = Str(media_counter)

        'Life counter
        txtLifeCounter.Text = Str(GetCounterL(PortNo))
    End Sub

    '-----------------------------------------
    'Open image file
    '-----------------------------------------
    Private Sub File_Open(ByVal FileName As String)
        On Error GoTo File_Open_Err
        Dim ratio As Single
        Dim OverWidth As Single
        Dim OverHeight As Single

        Me.Image1.Image = System.Drawing.Image.FromFile(FileName)

        'Display size adjustment
        Me.Image1.Width = Panel1.Width
        ratio = Panel1.Width / Me.Image1.Image.Width
        Me.Image1.Height = Me.Image1.Image.Height * ratio
        If Me.Image1.Height > Panel1.Height Then
            Me.Image1.Height = Panel1.Height
            ratio = Panel1.Height / Me.Image1.Image.Height
            Me.Image1.Width = Me.Image1.Image.Width * ratio
        End If

        'Centering
        OverWidth = Panel1.Height - Me.Image1.Height
        OverHeight = Panel1.Width - Me.Image1.Width
        Me.Image1.Top = OverWidth / 2
        Me.Image1.Left = OverHeight / 2

        Me.Show()
        System.Windows.Forms.Application.DoEvents()
        Exit Sub

File_Open_Err:
        MsgBox("File not found : " & FileName)
        End
    End Sub

    '-----------------------------------------
    ' Click ColorAdjustment combo box
    '-----------------------------------------
    Private Sub ComboColorAdjustment_SelectedIndexChanged(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles ComboColorAdjustment.SelectedIndexChanged
        If DirectCast(ComboColorAdjustment.SelectedItem, ComboItem).Number = DM_EXCOLORADJ_DRIVER Then
            TextBoxGamma.Enabled = True
            TextBoxBrightness.Enabled = True
            TextBoxContrast.Enabled = True
            TextBoxChroma.Enabled = True
        Else
            TextBoxGamma.Enabled = False
            TextBoxBrightness.Enabled = False
            TextBoxContrast.Enabled = False
            TextBoxChroma.Enabled = False
        End If
    End Sub

    '-----------------------------------------
    'Setting of upper bound and lower bound
    '-----------------------------------------
    Private Sub TextBoxgamma_TextChanged(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles TextBoxGamma.TextChanged
        If Val(TextBoxGamma.Text) > 100 Then
            TextBoxGamma.Text = 100
        ElseIf Val(TextBoxGamma.Text) < -100 Then
            TextBoxGamma.Text = -100
        End If
    End Sub
    Private Sub TextBoxGamma_LostFocus(ByVal sender As Object, ByVal e As System.EventArgs) Handles TextBoxGamma.LostFocus
        TextBoxGamma.Text = Val(TextBoxGamma.Text)
    End Sub

    Private Sub TextBoxBrightness_TextChanged(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles TextBoxBrightness.TextChanged
        If Val(TextBoxBrightness.Text) > 100 Then
            TextBoxBrightness.Text = 100
        ElseIf Val(TextBoxBrightness.Text) < -100 Then
            TextBoxBrightness.Text = -100
        End If
    End Sub
    Private Sub TextBoxBrightness_LostFocus(ByVal sender As Object, ByVal e As System.EventArgs) Handles TextBoxBrightness.LostFocus
        TextBoxBrightness.Text = Val(TextBoxBrightness.Text)
    End Sub

    Private Sub TextBoxContrast_TextChanged(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles TextBoxContrast.TextChanged
        If Val(TextBoxContrast.Text) > 100 Then
            TextBoxContrast.Text = 100
        ElseIf Val(TextBoxContrast.Text) < -100 Then
            TextBoxContrast.Text = -100
        End If
    End Sub
    Private Sub TextBoxContrast_LostFocus(ByVal sender As Object, ByVal e As System.EventArgs) Handles TextBoxContrast.LostFocus
        TextBoxContrast.Text = Val(TextBoxContrast.Text)
    End Sub

    Private Sub TextBoxChroma_TextChanged(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles TextBoxChroma.TextChanged
        If Val(TextBoxChroma.Text) > 100 Then
            TextBoxChroma.Text = 100
        ElseIf Val(TextBoxChroma.Text) < -100 Then
            TextBoxChroma.Text = -100
        End If
    End Sub
    Private Sub TextBoxChroma_LostFocus(ByVal sender As Object, ByVal e As System.EventArgs) Handles TextBoxChroma.LostFocus
        TextBoxChroma.Text = Val(TextBoxChroma.Text)
    End Sub


    '-----------------------------------------
    'Setting value and text in ComboBox
    '-----------------------------------------
    Public Structure ComboItem
        Public Text As String
        Public Number As Integer
        Public Overrides Function ToString() As String
            Return Text
        End Function
        Public Sub New(ByVal S As String, ByVal I As Integer)
            Text = S
            Number = I
        End Sub
    End Structure

    '-----------------------------------------
    ' Click PaperSize combo box
    '-----------------------------------------
    Private Sub ComboPaperSize_SelectedIndexChanged(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles ComboPaperSize.SelectedIndexChanged
        If PrinterModel = PRN_6IN Then
            If ComboPaperSize.Text = "(6x4)" Or ComboPaperSize.Text = "PR (4x6)" Or ComboPaperSize.Text = "(6x8)" Then
                ComboCut2inch.Enabled = True
            Else
                ComboCut2inch.Enabled = False
                ComboCut2inch.SelectedIndex = DM_CUT2INCH_OFF
            End If
        End If
    End Sub

End Class