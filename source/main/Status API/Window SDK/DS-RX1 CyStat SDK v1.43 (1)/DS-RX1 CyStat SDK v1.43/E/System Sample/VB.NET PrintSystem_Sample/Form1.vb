Option Strict Off
Option Explicit On
Imports VB = Microsoft.VisualBasic

Friend Class Form1
    Inherits System.Windows.Forms.Form

    Dim txtState(4) As TextBox
    Dim txtCount(4) As TextBox
    Dim labPrnName(4) As Label

    Const PRINTER_NUM As Byte = 4
    Dim PrinterName(PRINTER_NUM) As String          'Printer Name
    Dim PortNum(PRINTER_NUM) As Integer             'Port Number
    Dim count(4) As Integer, count_ap(4) As Integer 'Counter
    Dim time(4) As Integer, time_tmp(4) As Integer  'Print job time

    Dim ImageNum As Byte                            'JPG file number
    Dim FilePath As String                          'JPG file path

    'Printer check
    Const P_CHK_OK As Byte = 0
    Const P_CHK_BUSY As Byte = 1
    Const P_CHK_ERR As Byte = 2
    Const P_CHK_OFF As Byte = 3


    '==================================================================
    ' Form Load
    '==================================================================
    Private Sub Form1_Load(ByVal eventSender As System.Object, ByVal eventArgs As System.EventArgs) Handles MyBase.Load
        Dim port As String
        Dim n As Integer

        subTextBoxArraySet()

        ImageNum = 1
        FilePath = "Data\"  'Image data folder（Print from 01.JPG through 04.JPG of this folder repeatedly）

        'Set Printer Device Name
        PrinterName(0) = "DS-RX1_1"
        PrinterName(1) = "DS-RX1_2"
        PrinterName(2) = "DS-RX1_3"
        PrinterName(3) = "DS-RX1_4"
        For n = 0 To PRINTER_NUM - 1
            labPrnName(n).Text = PrinterName(n)
        Next n

        'Get printer port number（Initialized status API）
        For n = 0 To PRINTER_NUM - 1
            If PrnSearch(PrinterName(n)) = True Then
                port = GetPortName(PrinterName(n))
                If port = "OFF LINE" Then
                    txtState(n).Text = "OFF LINE"
                    txtState(n).BackColor = Color.LightGray
                    PortNum(n) = -1
                Else
                    PortNum(n) = PortInitialize(port)
                End If
            Else
                labPrnName(n).Enabled = False
                txtState(n).BackColor = Color.LightGray
                PortNum(n) = -1
            End If
        Next n

        'Get status of each printer
        For n = 0 To PRINTER_NUM - 1
            If PortNum(n) > 0 Then
                txtState(n).Text = GetStateStr(PortNum(n))
            Else
                txtState(n).Text = ""
            End If
        Next n

        'Get counter value of each printer
        For n = 0 To PRINTER_NUM - 1
            If PortNum(n) > 0 Then
                txtCount(n).Text = CStr(GetCounterL(PortNum(n)))
            Else
                txtCount(n).Text = ""
            End If
        Next n

        'Set default value for the number of prints
        txtQuantity.Text = CStr(1)

    End Sub


    '==================================================================
    ' Print button
    '==================================================================
    Private Sub buttonPrint_Click(ByVal sender As System.Object, ByVal e As System.EventArgs) Handles buttonPrint.Click
        Dim n As Integer
        Dim currentPrn As Integer
        Dim fopen_flg As Boolean
        Dim prn_chk As Byte
        Dim num As Integer
        Dim prn_chk_ok As Boolean
        Dim cnt As Integer

        buttonPrint.Enabled = False

        'Set the number of prints
        num = Val(txtQuantity.Text)
        If num < 1 Or num > 1000 Then
            num = 1
            txtQuantity.Text = CStr(num)
        End If

        'Get counter value of each printer
        For n = 0 To PRINTER_NUM - 1
            If PortNum(n) > 0 Then
                count(n) = GetCounterL(PortNum(n))
                count_ap(n) = count(n)                      'Set application counter value to match printer count value
                txtCount(n).Text = CStr(count(n))           'Display counter value
            Else
                txtCount(n).Text = ""
            End If
        Next n

        currentPrn = 0                  'Set current printer to printer #0
        fopen_flg = False               'Clear the flag for the file already opened

        For n = 0 To PRINTER_NUM - 1
            time(n) = VB.Timer()        'Initialization of temporary for timer
        Next n


        '---------------------------------------------
        'Loop equivalent times to the number of prints
        '---------------------------------------------
        n = 0
        prn_chk_ok = False
        Do
            If fopen_flg = False Then
                File_Open()             'Open image file
                fopen_flg = True
            End If

            '--- Printer check ---
            prn_chk = PrinterCheck(currentPrn)
            If prn_chk <> P_CHK_ERR And prn_chk <> P_CHK_OFF Then
                prn_chk_ok = True
            End If
            System.Windows.Forms.Application.DoEvents()

            '--- Print process ---
            If prn_chk = P_CHK_OK Then 'Is there any printer available to send data?
                Dim pd As New System.Drawing.Printing.PrintDocument
                AddHandler pd.PrintPage, AddressOf pd_PrintPage
                pd.PrinterSettings.PrinterName = PrinterName(currentPrn)
                pd.Print()
                pd.Dispose()

                count_ap(currentPrn) = count_ap(currentPrn) + 1 'Count up the application counter
                fopen_flg = False
                n = n + 1
                txtRemain.Text = CStr(num - n)
            End If

            '--- Chenge current printer ---
            currentPrn = currentPrn + 1
            If currentPrn >= PRINTER_NUM Then
                If prn_chk_ok = False Then
                    Exit Do
                End If
                currentPrn = 0
                prn_chk_ok = False
            End If

            Sleep(100)
        Loop While n < num


        '---------------------------------------------
        'Check completion
        '---------------------------------------------
        Do
            'Printer check
            For n = 0 To PRINTER_NUM - 1
                prn_chk = PrinterCheck(n)
                If prn_chk = P_CHK_ERR Then Exit Do
            Next n

            'Counter check
            For n = 0 To PRINTER_NUM - 1
                If PortNum(n) > 0 Then
                    cnt = GetCounterL(PortNum(n))
                    If cnt < count_ap(n) Then Exit For
                End If
            Next n

            If n = PRINTER_NUM Then
                Exit Do     'Completed
            End If

            System.Windows.Forms.Application.DoEvents()
            Sleep(100)
        Loop


        'Display each printer status and counter
        For n = 0 To PRINTER_NUM - 1
            If PortNum(n) > 0 Then
                txtState(n).Text = GetStateStr(PortNum(n))
                txtCount(n).Text = GetCounterL(PortNum(n))
            End If
        Next n

        txtRemain.Text = CStr(0)
        buttonPrint.Enabled = True
        System.Windows.Forms.Application.DoEvents()

    End Sub


    '==================================================================
    ' Printer check
    '==================================================================
    Private Function PrinterCheck(ByVal prn As Integer) As Integer
        Dim cnt As Integer
        Dim state As String
        Dim time_cnt As Integer
        Dim pJob As Integer
        Dim free_buff As Integer

        If PortNum(prn) > 0 Then
            pJob = CheckPrnJob(PrinterName(prn))                'Check print job
            If pJob = 0 Then                                'If there is no print job, check count value
                cnt = CvGetCounterL(PortNum(prn))           'Get life counter
                If cnt >= 0 Then
                    txtCount(prn).Text = CStr(cnt)
                Else
                    txtCount(prn).Text = " ---"
                End If

                state = GetStateStr(PortNum(prn))           'Get printer status
                txtState(prn).Text = state

                If state = "Idle" Or state = "Printing" Or state = "Cooling" Then 'Check error
                    free_buff = GetFreeBuffer(PortNum(prn)) 'Get free image buffer
                    If free_buff >= 1 Then
                        PrinterCheck = P_CHK_OK             'There is an free buffer
                    Else
                        PrinterCheck = P_CHK_BUSY           'Buffer is full
                    End If
                Else
                    PrinterCheck = P_CHK_ERR                'Error
                    count_ap(prn) = cnt                     'If error is detected, initialize count value
                    MsgBox("Printer Error" & Chr(13) & Chr(10) & "[" & PrinterName(prn) & "] : " & state, vbCritical)
                    '---- Error Recovery ----
                    '
                    '
                    '
                    '------------------------
                End If
                time_tmp(prn) = VB.Timer()
            Else
                PrinterCheck = P_CHK_BUSY
                time_cnt = VB.Timer() - time_tmp(prn)       'Check waiting time of the print job in print queue.
                If time_cnt > 60 Then                       'Error process if there is a job which stays more than 1 minute.
                    MsgBox("Please check Print Job" & Chr(13) & Chr(10) & "[" & PrinterName(prn) & "]", vbCritical)
                    '---- Error Recovery ----
                    '
                    '
                    '
                    '------------------------
                End If
            End If
        Else
            PrinterCheck = P_CHK_OFF
        End If

    End Function


    '==================================================================
    ' Opne image file
    '==================================================================
    Private Sub File_Open()
        On Error GoTo File_Open_Err
        Dim fName As Object
        Dim ratio As Single
        Dim OverWidth As Single
        Dim OverHeight As Single

        fName = FilePath + Format(ImageNum, "00") + ".jpg"

        'Load image
        Me.Image1.Image = System.Drawing.Image.FromFile(fName)

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

        ImageNum = ImageNum + 1
        If ImageNum >= 5 Then ImageNum = 1 '01.JPG - 04.JPG

        Exit Sub

File_Open_Err:
        MsgBox(fName & "is not found")
        End
    End Sub


    '==================================================================
    ' Print
    '==================================================================
    Private Sub pd_PrintPage(ByVal sender As Object, ByVal e As System.Drawing.Printing.PrintPageEventArgs)
        'Output size calucration
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
        e.HasMorePages = False
    End Sub


    '==================================================================
    ' Get printer status
    '==================================================================
    Function GetStateStr(ByVal UsbPort As Integer) As String
        Dim state As Long
        Dim stateStr As String

        stateStr = ""

        state = GetStatus(UsbPort)
        If state And GROUP_USUALLY Then
            Select Case state
                Case STATUS_USUALLY_IDLE : stateStr = "Idle"
                Case STATUS_USUALLY_PRINTING : stateStr = "Printing"
                Case STATUS_USUALLY_PAPER_END : stateStr = "Paper End"
                Case STATUS_USUALLY_RIBBON_END : stateStr = "Ribbon End"
                Case STATUS_USUALLY_COOLING : stateStr = "Cooling"
                Case STATUS_USUALLY_MOTCOOLING : stateStr = "Cooling"
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
            stateStr = "OFF LINE"
        End If

        GetStateStr = stateStr
    End Function


    '==================================================================
    '
    '==================================================================
    Public Sub subTextBoxArraySet()
        'Printer status
        txtState(0) = txtState0
        txtState(1) = txtState1
        txtState(2) = txtState2
        txtState(3) = txtState3

        'Life counter
        txtCount(0) = txtCount0
        txtCount(1) = txtCount1
        txtCount(2) = txtCount2
        txtCount(3) = txtCount3

        'Printer name
        labPrnName(0) = labPrnName0
        labPrnName(1) = labPrnName1
        labPrnName(2) = labPrnName2
        labPrnName(3) = labPrnName3
    End Sub

End Class