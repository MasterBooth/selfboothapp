<Global.Microsoft.VisualBasic.CompilerServices.DesignerGenerated()> Partial Class Form1
#Region "Windows フォーム デザイナによって生成されたコード "
	<System.Diagnostics.DebuggerNonUserCode()> Public Sub New()
		MyBase.New()
		'この呼び出しは、Windows フォーム デザイナで必要です。
		InitializeComponent()
	End Sub
	'Form は、コンポーネント一覧に後処理を実行するために dispose をオーバーライドします。
	<System.Diagnostics.DebuggerNonUserCode()> Protected Overloads Overrides Sub Dispose(ByVal Disposing As Boolean)
		If Disposing Then
			If Not components Is Nothing Then
				components.Dispose()
			End If
		End If
		MyBase.Dispose(Disposing)
	End Sub
	'Windows フォーム デザイナで必要です。
	Private components As System.ComponentModel.IContainer
    Public WithEvents Command1 As System.Windows.Forms.Button
    'メモ: 以下のプロシージャは Windows フォーム デザイナで必要です。
    'Windows フォーム デザイナを使って変更できます。
    'コード エディタを使用して、変更しないでください。
	<System.Diagnostics.DebuggerStepThrough()> Private Sub InitializeComponent()
        Me.components = New System.ComponentModel.Container
        Me.Command1 = New System.Windows.Forms.Button
        Me.Label1 = New System.Windows.Forms.Label
        Me.Label2 = New System.Windows.Forms.Label
        Me.Label3 = New System.Windows.Forms.Label
        Me.Label4 = New System.Windows.Forms.Label
        Me.Label5 = New System.Windows.Forms.Label
        Me.txtPrinterName = New System.Windows.Forms.TextBox
        Me.txtPortName = New System.Windows.Forms.TextBox
        Me.txtPrinterStatus = New System.Windows.Forms.TextBox
        Me.txtMediaCounter = New System.Windows.Forms.TextBox
        Me.txtLifeCounter = New System.Windows.Forms.TextBox
        Me.ComboOrientation = New System.Windows.Forms.ComboBox
        Me.Label6 = New System.Windows.Forms.Label
        Me.Label7 = New System.Windows.Forms.Label
        Me.ComboPaperSize = New System.Windows.Forms.ComboBox
        Me.Timer1 = New System.Windows.Forms.Timer(Me.components)
        Me.Label8 = New System.Windows.Forms.Label
        Me.ComboPrintQuality = New System.Windows.Forms.ComboBox
        Me.Label10 = New System.Windows.Forms.Label
        Me.Label11 = New System.Windows.Forms.Label
        Me.TextBoxBrightness = New System.Windows.Forms.TextBox
        Me.TextBoxContrast = New System.Windows.Forms.TextBox
        Me.ComboBorder = New System.Windows.Forms.ComboBox
        Me.ComboSharpness = New System.Windows.Forms.ComboBox
        Me.Label12 = New System.Windows.Forms.Label
        Me.Label13 = New System.Windows.Forms.Label
        Me.ComboOvercoatFinish = New System.Windows.Forms.ComboBox
        Me.Label14 = New System.Windows.Forms.Label
        Me.ComboPrintRetry = New System.Windows.Forms.ComboBox
        Me.Label15 = New System.Windows.Forms.Label
        Me.Label16 = New System.Windows.Forms.Label
        Me.ComboICM = New System.Windows.Forms.ComboBox
        Me.Label17 = New System.Windows.Forms.Label
        Me.ComboColorAdjustment = New System.Windows.Forms.ComboBox
        Me.Label18 = New System.Windows.Forms.Label
        Me.TextBoxGamma = New System.Windows.Forms.TextBox
        Me.Label9 = New System.Windows.Forms.Label
        Me.TextBoxChroma = New System.Windows.Forms.TextBox
        Me.GroupBox1 = New System.Windows.Forms.GroupBox
        Me.GroupBox2 = New System.Windows.Forms.GroupBox
        Me.PrintDialog1 = New System.Windows.Forms.PrintDialog
        Me.pd = New System.Drawing.Printing.PrintDocument
        Me.Image1 = New System.Windows.Forms.PictureBox
        Me.Panel1 = New System.Windows.Forms.Panel
        Me.Label19 = New System.Windows.Forms.Label
        Me.ComboCut2inch = New System.Windows.Forms.ComboBox
        Me.GroupBox1.SuspendLayout()
        Me.GroupBox2.SuspendLayout()
        CType(Me.Image1, System.ComponentModel.ISupportInitialize).BeginInit()
        Me.Panel1.SuspendLayout()
        Me.SuspendLayout()
        '
        'Command1
        '
        Me.Command1.BackColor = System.Drawing.SystemColors.Control
        Me.Command1.Cursor = System.Windows.Forms.Cursors.Default
        Me.Command1.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Command1.Location = New System.Drawing.Point(304, 356)
        Me.Command1.Name = "Command1"
        Me.Command1.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.Command1.Size = New System.Drawing.Size(97, 33)
        Me.Command1.TabIndex = 0
        Me.Command1.Text = "Print"
        Me.Command1.UseVisualStyleBackColor = False
        '
        'Label1
        '
        Me.Label1.AutoSize = True
        Me.Label1.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label1.Location = New System.Drawing.Point(52, 24)
        Me.Label1.Name = "Label1"
        Me.Label1.Size = New System.Drawing.Size(39, 12)
        Me.Label1.TabIndex = 16
        Me.Label1.Text = "Printer"
        '
        'Label2
        '
        Me.Label2.AutoSize = True
        Me.Label2.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label2.Location = New System.Drawing.Point(64, 48)
        Me.Label2.Name = "Label2"
        Me.Label2.Size = New System.Drawing.Size(26, 12)
        Me.Label2.TabIndex = 17
        Me.Label2.Text = "Port"
        '
        'Label3
        '
        Me.Label3.AutoSize = True
        Me.Label3.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label3.Location = New System.Drawing.Point(52, 72)
        Me.Label3.Name = "Label3"
        Me.Label3.Size = New System.Drawing.Size(38, 12)
        Me.Label3.TabIndex = 18
        Me.Label3.Text = "Status"
        '
        'Label4
        '
        Me.Label4.AutoSize = True
        Me.Label4.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label4.Location = New System.Drawing.Point(11, 95)
        Me.Label4.Name = "Label4"
        Me.Label4.Size = New System.Drawing.Size(79, 12)
        Me.Label4.TabIndex = 19
        Me.Label4.Text = "Media Counter"
        '
        'Label5
        '
        Me.Label5.AutoSize = True
        Me.Label5.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label5.Location = New System.Drawing.Point(24, 120)
        Me.Label5.Name = "Label5"
        Me.Label5.Size = New System.Drawing.Size(68, 12)
        Me.Label5.TabIndex = 20
        Me.Label5.Text = "Life Counter"
        '
        'txtPrinterName
        '
        Me.txtPrinterName.Location = New System.Drawing.Point(96, 20)
        Me.txtPrinterName.Name = "txtPrinterName"
        Me.txtPrinterName.ReadOnly = True
        Me.txtPrinterName.Size = New System.Drawing.Size(100, 19)
        Me.txtPrinterName.TabIndex = 21
        Me.txtPrinterName.TabStop = False
        '
        'txtPortName
        '
        Me.txtPortName.Location = New System.Drawing.Point(96, 44)
        Me.txtPortName.Name = "txtPortName"
        Me.txtPortName.ReadOnly = True
        Me.txtPortName.Size = New System.Drawing.Size(100, 19)
        Me.txtPortName.TabIndex = 22
        Me.txtPortName.TabStop = False
        '
        'txtPrinterStatus
        '
        Me.txtPrinterStatus.Location = New System.Drawing.Point(96, 68)
        Me.txtPrinterStatus.Name = "txtPrinterStatus"
        Me.txtPrinterStatus.ReadOnly = True
        Me.txtPrinterStatus.Size = New System.Drawing.Size(100, 19)
        Me.txtPrinterStatus.TabIndex = 23
        Me.txtPrinterStatus.TabStop = False
        '
        'txtMediaCounter
        '
        Me.txtMediaCounter.Location = New System.Drawing.Point(96, 92)
        Me.txtMediaCounter.Name = "txtMediaCounter"
        Me.txtMediaCounter.ReadOnly = True
        Me.txtMediaCounter.Size = New System.Drawing.Size(100, 19)
        Me.txtMediaCounter.TabIndex = 24
        Me.txtMediaCounter.TabStop = False
        '
        'txtLifeCounter
        '
        Me.txtLifeCounter.Location = New System.Drawing.Point(96, 116)
        Me.txtLifeCounter.Name = "txtLifeCounter"
        Me.txtLifeCounter.ReadOnly = True
        Me.txtLifeCounter.Size = New System.Drawing.Size(100, 19)
        Me.txtLifeCounter.TabIndex = 25
        Me.txtLifeCounter.TabStop = False
        '
        'ComboOrientation
        '
        Me.ComboOrientation.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboOrientation.FormattingEnabled = True
        Me.ComboOrientation.Location = New System.Drawing.Point(96, 44)
        Me.ComboOrientation.Name = "ComboOrientation"
        Me.ComboOrientation.Size = New System.Drawing.Size(100, 20)
        Me.ComboOrientation.TabIndex = 2
        '
        'Label6
        '
        Me.Label6.AutoSize = True
        Me.Label6.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label6.Location = New System.Drawing.Point(28, 48)
        Me.Label6.Name = "Label6"
        Me.Label6.Size = New System.Drawing.Size(61, 12)
        Me.Label6.TabIndex = 27
        Me.Label6.Text = "Orientation"
        '
        'Label7
        '
        Me.Label7.AutoSize = True
        Me.Label7.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label7.Location = New System.Drawing.Point(36, 24)
        Me.Label7.Name = "Label7"
        Me.Label7.Size = New System.Drawing.Size(55, 12)
        Me.Label7.TabIndex = 29
        Me.Label7.Text = "PaperSize"
        '
        'ComboPaperSize
        '
        Me.ComboPaperSize.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboPaperSize.FormattingEnabled = True
        Me.ComboPaperSize.Location = New System.Drawing.Point(96, 20)
        Me.ComboPaperSize.Name = "ComboPaperSize"
        Me.ComboPaperSize.Size = New System.Drawing.Size(100, 20)
        Me.ComboPaperSize.TabIndex = 1
        '
        'Timer1
        '
        Me.Timer1.Interval = 500
        '
        'Label8
        '
        Me.Label8.AutoSize = True
        Me.Label8.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label8.Location = New System.Drawing.Point(20, 120)
        Me.Label8.Name = "Label8"
        Me.Label8.Size = New System.Drawing.Size(69, 12)
        Me.Label8.TabIndex = 31
        Me.Label8.Text = "Print Quality"
        '
        'ComboPrintQuality
        '
        Me.ComboPrintQuality.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboPrintQuality.FormattingEnabled = True
        Me.ComboPrintQuality.Location = New System.Drawing.Point(96, 116)
        Me.ComboPrintQuality.Name = "ComboPrintQuality"
        Me.ComboPrintQuality.Size = New System.Drawing.Size(100, 20)
        Me.ComboPrintQuality.TabIndex = 5
        '
        'Label10
        '
        Me.Label10.AutoSize = True
        Me.Label10.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label10.Location = New System.Drawing.Point(272, 100)
        Me.Label10.Name = "Label10"
        Me.Label10.Size = New System.Drawing.Size(60, 12)
        Me.Label10.TabIndex = 33
        Me.Label10.Text = "Brightness"
        '
        'Label11
        '
        Me.Label11.AutoSize = True
        Me.Label11.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label11.Location = New System.Drawing.Point(280, 124)
        Me.Label11.Name = "Label11"
        Me.Label11.Size = New System.Drawing.Size(49, 12)
        Me.Label11.TabIndex = 34
        Me.Label11.Text = "Contrast"
        '
        'TextBoxBrightness
        '
        Me.TextBoxBrightness.Location = New System.Drawing.Point(336, 96)
        Me.TextBoxBrightness.MaxLength = 4
        Me.TextBoxBrightness.Name = "TextBoxBrightness"
        Me.TextBoxBrightness.Size = New System.Drawing.Size(36, 19)
        Me.TextBoxBrightness.TabIndex = 11
        Me.TextBoxBrightness.TextAlign = System.Windows.Forms.HorizontalAlignment.Right
        '
        'TextBoxContrast
        '
        Me.TextBoxContrast.Location = New System.Drawing.Point(336, 120)
        Me.TextBoxContrast.MaxLength = 4
        Me.TextBoxContrast.Name = "TextBoxContrast"
        Me.TextBoxContrast.Size = New System.Drawing.Size(36, 19)
        Me.TextBoxContrast.TabIndex = 12
        Me.TextBoxContrast.TextAlign = System.Windows.Forms.HorizontalAlignment.Right
        '
        'ComboBorder
        '
        Me.ComboBorder.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboBorder.FormattingEnabled = True
        Me.ComboBorder.Location = New System.Drawing.Point(96, 68)
        Me.ComboBorder.Name = "ComboBorder"
        Me.ComboBorder.Size = New System.Drawing.Size(100, 20)
        Me.ComboBorder.TabIndex = 3
        '
        'ComboSharpness
        '
        Me.ComboSharpness.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboSharpness.FormattingEnabled = True
        Me.ComboSharpness.Location = New System.Drawing.Point(96, 92)
        Me.ComboSharpness.MaxDropDownItems = 11
        Me.ComboSharpness.Name = "ComboSharpness"
        Me.ComboSharpness.Size = New System.Drawing.Size(100, 20)
        Me.ComboSharpness.TabIndex = 4
        '
        'Label12
        '
        Me.Label12.AutoSize = True
        Me.Label12.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label12.Location = New System.Drawing.Point(52, 72)
        Me.Label12.Name = "Label12"
        Me.Label12.Size = New System.Drawing.Size(39, 12)
        Me.Label12.TabIndex = 39
        Me.Label12.Text = "Border"
        '
        'Label13
        '
        Me.Label13.AutoSize = True
        Me.Label13.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label13.Location = New System.Drawing.Point(32, 96)
        Me.Label13.Name = "Label13"
        Me.Label13.Size = New System.Drawing.Size(58, 12)
        Me.Label13.TabIndex = 40
        Me.Label13.Text = "Sharpness"
        '
        'ComboOvercoatFinish
        '
        Me.ComboOvercoatFinish.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboOvercoatFinish.FormattingEnabled = True
        Me.ComboOvercoatFinish.Location = New System.Drawing.Point(96, 140)
        Me.ComboOvercoatFinish.Name = "ComboOvercoatFinish"
        Me.ComboOvercoatFinish.Size = New System.Drawing.Size(100, 20)
        Me.ComboOvercoatFinish.TabIndex = 6
        '
        'Label14
        '
        Me.Label14.AutoSize = True
        Me.Label14.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label14.Location = New System.Drawing.Point(4, 144)
        Me.Label14.Name = "Label14"
        Me.Label14.Size = New System.Drawing.Size(86, 12)
        Me.Label14.TabIndex = 42
        Me.Label14.Text = "Overcoat Finish"
        '
        'ComboPrintRetry
        '
        Me.ComboPrintRetry.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboPrintRetry.FormattingEnabled = True
        Me.ComboPrintRetry.Location = New System.Drawing.Point(96, 164)
        Me.ComboPrintRetry.Name = "ComboPrintRetry"
        Me.ComboPrintRetry.Size = New System.Drawing.Size(100, 20)
        Me.ComboPrintRetry.TabIndex = 7
        '
        'Label15
        '
        Me.Label15.AutoSize = True
        Me.Label15.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label15.Location = New System.Drawing.Point(28, 168)
        Me.Label15.Name = "Label15"
        Me.Label15.Size = New System.Drawing.Size(61, 12)
        Me.Label15.TabIndex = 44
        Me.Label15.Text = "Print Retry"
        '
        'Label16
        '
        Me.Label16.AutoSize = True
        Me.Label16.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label16.Location = New System.Drawing.Point(272, 24)
        Me.Label16.Name = "Label16"
        Me.Label16.Size = New System.Drawing.Size(25, 12)
        Me.Label16.TabIndex = 46
        Me.Label16.Text = "ICM"
        '
        'ComboICM
        '
        Me.ComboICM.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboICM.FormattingEnabled = True
        Me.ComboICM.Location = New System.Drawing.Point(304, 20)
        Me.ComboICM.Name = "ComboICM"
        Me.ComboICM.Size = New System.Drawing.Size(84, 20)
        Me.ComboICM.TabIndex = 8
        '
        'Label17
        '
        Me.Label17.AutoSize = True
        Me.Label17.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label17.Location = New System.Drawing.Point(204, 48)
        Me.Label17.Name = "Label17"
        Me.Label17.Size = New System.Drawing.Size(94, 12)
        Me.Label17.TabIndex = 48
        Me.Label17.Text = "Color Adjustment"
        '
        'ComboColorAdjustment
        '
        Me.ComboColorAdjustment.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboColorAdjustment.FormattingEnabled = True
        Me.ComboColorAdjustment.Location = New System.Drawing.Point(304, 44)
        Me.ComboColorAdjustment.Name = "ComboColorAdjustment"
        Me.ComboColorAdjustment.Size = New System.Drawing.Size(84, 20)
        Me.ComboColorAdjustment.TabIndex = 9
        '
        'Label18
        '
        Me.Label18.AutoSize = True
        Me.Label18.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label18.Location = New System.Drawing.Point(288, 76)
        Me.Label18.Name = "Label18"
        Me.Label18.Size = New System.Drawing.Size(43, 12)
        Me.Label18.TabIndex = 50
        Me.Label18.Text = "Gamma"
        '
        'TextBoxGamma
        '
        Me.TextBoxGamma.Location = New System.Drawing.Point(336, 72)
        Me.TextBoxGamma.MaxLength = 4
        Me.TextBoxGamma.Name = "TextBoxGamma"
        Me.TextBoxGamma.Size = New System.Drawing.Size(36, 19)
        Me.TextBoxGamma.TabIndex = 10
        Me.TextBoxGamma.TextAlign = System.Windows.Forms.HorizontalAlignment.Right
        '
        'Label9
        '
        Me.Label9.AutoSize = True
        Me.Label9.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label9.Location = New System.Drawing.Point(288, 148)
        Me.Label9.Name = "Label9"
        Me.Label9.Size = New System.Drawing.Size(44, 12)
        Me.Label9.TabIndex = 52
        Me.Label9.Text = "Chroma"
        '
        'TextBoxChroma
        '
        Me.TextBoxChroma.Location = New System.Drawing.Point(336, 144)
        Me.TextBoxChroma.MaxLength = 4
        Me.TextBoxChroma.Name = "TextBoxChroma"
        Me.TextBoxChroma.Size = New System.Drawing.Size(36, 19)
        Me.TextBoxChroma.TabIndex = 13
        Me.TextBoxChroma.TextAlign = System.Windows.Forms.HorizontalAlignment.Right
        '
        'GroupBox1
        '
        Me.GroupBox1.Controls.Add(Me.txtLifeCounter)
        Me.GroupBox1.Controls.Add(Me.txtMediaCounter)
        Me.GroupBox1.Controls.Add(Me.txtPrinterStatus)
        Me.GroupBox1.Controls.Add(Me.txtPortName)
        Me.GroupBox1.Controls.Add(Me.txtPrinterName)
        Me.GroupBox1.Controls.Add(Me.Label5)
        Me.GroupBox1.Controls.Add(Me.Label4)
        Me.GroupBox1.Controls.Add(Me.Label3)
        Me.GroupBox1.Controls.Add(Me.Label2)
        Me.GroupBox1.Controls.Add(Me.Label1)
        Me.GroupBox1.ForeColor = System.Drawing.Color.Blue
        Me.GroupBox1.Location = New System.Drawing.Point(8, 302)
        Me.GroupBox1.Name = "GroupBox1"
        Me.GroupBox1.Size = New System.Drawing.Size(208, 148)
        Me.GroupBox1.TabIndex = 54
        Me.GroupBox1.TabStop = False
        Me.GroupBox1.Text = "Printer Information"
        '
        'GroupBox2
        '
        Me.GroupBox2.Controls.Add(Me.Label19)
        Me.GroupBox2.Controls.Add(Me.ComboCut2inch)
        Me.GroupBox2.Controls.Add(Me.TextBoxChroma)
        Me.GroupBox2.Controls.Add(Me.Label9)
        Me.GroupBox2.Controls.Add(Me.TextBoxGamma)
        Me.GroupBox2.Controls.Add(Me.Label18)
        Me.GroupBox2.Controls.Add(Me.ComboColorAdjustment)
        Me.GroupBox2.Controls.Add(Me.Label17)
        Me.GroupBox2.Controls.Add(Me.ComboICM)
        Me.GroupBox2.Controls.Add(Me.Label16)
        Me.GroupBox2.Controls.Add(Me.Label15)
        Me.GroupBox2.Controls.Add(Me.ComboPrintRetry)
        Me.GroupBox2.Controls.Add(Me.Label14)
        Me.GroupBox2.Controls.Add(Me.ComboOvercoatFinish)
        Me.GroupBox2.Controls.Add(Me.Label13)
        Me.GroupBox2.Controls.Add(Me.Label12)
        Me.GroupBox2.Controls.Add(Me.ComboSharpness)
        Me.GroupBox2.Controls.Add(Me.ComboBorder)
        Me.GroupBox2.Controls.Add(Me.TextBoxContrast)
        Me.GroupBox2.Controls.Add(Me.TextBoxBrightness)
        Me.GroupBox2.Controls.Add(Me.Label11)
        Me.GroupBox2.Controls.Add(Me.Label10)
        Me.GroupBox2.Controls.Add(Me.Label8)
        Me.GroupBox2.Controls.Add(Me.ComboPrintQuality)
        Me.GroupBox2.Controls.Add(Me.Label7)
        Me.GroupBox2.Controls.Add(Me.ComboPaperSize)
        Me.GroupBox2.Controls.Add(Me.Label6)
        Me.GroupBox2.Controls.Add(Me.ComboOrientation)
        Me.GroupBox2.ForeColor = System.Drawing.Color.Blue
        Me.GroupBox2.Location = New System.Drawing.Point(8, 460)
        Me.GroupBox2.Name = "GroupBox2"
        Me.GroupBox2.Size = New System.Drawing.Size(396, 216)
        Me.GroupBox2.TabIndex = 54
        Me.GroupBox2.TabStop = False
        Me.GroupBox2.Text = "Print Option"
        '
        'PrintDialog1
        '
        Me.PrintDialog1.UseEXDialog = True
        '
        'pd
        '
        '
        'Image1
        '
        Me.Image1.Cursor = System.Windows.Forms.Cursors.Default
        Me.Image1.Location = New System.Drawing.Point(135, 75)
        Me.Image1.Name = "Image1"
        Me.Image1.Size = New System.Drawing.Size(133, 81)
        Me.Image1.SizeMode = System.Windows.Forms.PictureBoxSizeMode.StretchImage
        Me.Image1.TabIndex = 0
        Me.Image1.TabStop = False
        '
        'Panel1
        '
        Me.Panel1.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.Panel1.Controls.Add(Me.Image1)
        Me.Panel1.Location = New System.Drawing.Point(8, 8)
        Me.Panel1.Name = "Panel1"
        Me.Panel1.Size = New System.Drawing.Size(396, 280)
        Me.Panel1.TabIndex = 55
        '
        'Label19
        '
        Me.Label19.AutoSize = True
        Me.Label19.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label19.Location = New System.Drawing.Point(36, 192)
        Me.Label19.Name = "Label19"
        Me.Label19.Size = New System.Drawing.Size(54, 12)
        Me.Label19.TabIndex = 56
        Me.Label19.Text = "2inch Cut"
        '
        'ComboCut2inch
        '
        Me.ComboCut2inch.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList
        Me.ComboCut2inch.FormattingEnabled = True
        Me.ComboCut2inch.Location = New System.Drawing.Point(96, 188)
        Me.ComboCut2inch.Name = "ComboCut2inch"
        Me.ComboCut2inch.Size = New System.Drawing.Size(100, 20)
        Me.ComboCut2inch.TabIndex = 55
        '
        'Form1
        '
        Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 12.0!)
        Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
        Me.BackColor = System.Drawing.SystemColors.Control
        Me.ClientSize = New System.Drawing.Size(412, 684)
        Me.Controls.Add(Me.Panel1)
        Me.Controls.Add(Me.GroupBox1)
        Me.Controls.Add(Me.GroupBox2)
        Me.Controls.Add(Me.Command1)
        Me.Cursor = System.Windows.Forms.Cursors.Default
        Me.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle
        Me.Location = New System.Drawing.Point(8, 34)
        Me.MaximizeBox = False
        Me.MinimizeBox = False
        Me.Name = "Form1"
        Me.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.Text = "DS-RX1 Print Setting Sample"
        Me.GroupBox1.ResumeLayout(False)
        Me.GroupBox1.PerformLayout()
        Me.GroupBox2.ResumeLayout(False)
        Me.GroupBox2.PerformLayout()
        CType(Me.Image1, System.ComponentModel.ISupportInitialize).EndInit()
        Me.Panel1.ResumeLayout(False)
        Me.ResumeLayout(False)

    End Sub
    Friend WithEvents Label1 As System.Windows.Forms.Label
    Friend WithEvents Label2 As System.Windows.Forms.Label
    Friend WithEvents Label3 As System.Windows.Forms.Label
    Friend WithEvents Label4 As System.Windows.Forms.Label
    Friend WithEvents Label5 As System.Windows.Forms.Label
    Friend WithEvents txtPrinterName As System.Windows.Forms.TextBox
    Friend WithEvents txtPortName As System.Windows.Forms.TextBox
    Friend WithEvents txtPrinterStatus As System.Windows.Forms.TextBox
    Friend WithEvents txtMediaCounter As System.Windows.Forms.TextBox
    Friend WithEvents txtLifeCounter As System.Windows.Forms.TextBox
    Friend WithEvents ComboOrientation As System.Windows.Forms.ComboBox
    Friend WithEvents Label6 As System.Windows.Forms.Label
    Friend WithEvents Label7 As System.Windows.Forms.Label
    Friend WithEvents ComboPaperSize As System.Windows.Forms.ComboBox
    Friend WithEvents Timer1 As System.Windows.Forms.Timer
    Friend WithEvents Label8 As System.Windows.Forms.Label
    Friend WithEvents ComboPrintQuality As System.Windows.Forms.ComboBox
    Friend WithEvents Label10 As System.Windows.Forms.Label
    Friend WithEvents Label11 As System.Windows.Forms.Label
    Friend WithEvents TextBoxBrightness As System.Windows.Forms.TextBox
    Friend WithEvents TextBoxContrast As System.Windows.Forms.TextBox
    Friend WithEvents ComboBorder As System.Windows.Forms.ComboBox
    Friend WithEvents ComboSharpness As System.Windows.Forms.ComboBox
    Friend WithEvents Label12 As System.Windows.Forms.Label
    Friend WithEvents Label13 As System.Windows.Forms.Label
    Friend WithEvents ComboOvercoatFinish As System.Windows.Forms.ComboBox
    Friend WithEvents Label14 As System.Windows.Forms.Label
    Friend WithEvents ComboPrintRetry As System.Windows.Forms.ComboBox
    Friend WithEvents Label15 As System.Windows.Forms.Label
    Friend WithEvents Label16 As System.Windows.Forms.Label
    Friend WithEvents ComboICM As System.Windows.Forms.ComboBox
    Friend WithEvents Label17 As System.Windows.Forms.Label
    Friend WithEvents ComboColorAdjustment As System.Windows.Forms.ComboBox
    Friend WithEvents Label18 As System.Windows.Forms.Label
    Friend WithEvents TextBoxGamma As System.Windows.Forms.TextBox
    Friend WithEvents Label9 As System.Windows.Forms.Label
    Friend WithEvents TextBoxChroma As System.Windows.Forms.TextBox
    Friend WithEvents GroupBox1 As System.Windows.Forms.GroupBox
    Friend WithEvents GroupBox2 As System.Windows.Forms.GroupBox
    Friend WithEvents PrintDialog1 As System.Windows.Forms.PrintDialog
    Friend WithEvents pd As System.Drawing.Printing.PrintDocument
    Public WithEvents Image1 As System.Windows.Forms.PictureBox
    Friend WithEvents Panel1 As System.Windows.Forms.Panel
    Friend WithEvents Label19 As System.Windows.Forms.Label
    Friend WithEvents ComboCut2inch As System.Windows.Forms.ComboBox
#End Region
End Class