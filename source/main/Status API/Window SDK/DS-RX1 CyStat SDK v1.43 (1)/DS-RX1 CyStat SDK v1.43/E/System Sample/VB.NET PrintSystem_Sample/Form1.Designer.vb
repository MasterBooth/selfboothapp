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
    'メモ: 以下のプロシージャは Windows フォーム デザイナで必要です。
    'Windows フォーム デザイナを使って変更できます。
    'コード エディタを使用して、変更しないでください。
	<System.Diagnostics.DebuggerStepThrough()> Private Sub InitializeComponent()
        Me.components = New System.ComponentModel.Container
        Me.Panel1 = New System.Windows.Forms.Panel
        Me.Image1 = New System.Windows.Forms.PictureBox
        Me.buttonPrint = New System.Windows.Forms.Button
        Me.labPrnName2 = New System.Windows.Forms.Label
        Me.txtState3 = New System.Windows.Forms.TextBox
        Me.txtState2 = New System.Windows.Forms.TextBox
        Me.txtState1 = New System.Windows.Forms.TextBox
        Me.txtState0 = New System.Windows.Forms.TextBox
        Me.labPrnName3 = New System.Windows.Forms.Label
        Me.ToolTip1 = New System.Windows.Forms.ToolTip(Me.components)
        Me.labPrnName1 = New System.Windows.Forms.Label
        Me.labPrnName0 = New System.Windows.Forms.Label
        Me.txtCount3 = New System.Windows.Forms.TextBox
        Me.CommonDialog1Open = New System.Windows.Forms.OpenFileDialog
        Me.txtRemain = New System.Windows.Forms.TextBox
        Me.txtQuantity = New System.Windows.Forms.TextBox
        Me.CommonDialog1Save = New System.Windows.Forms.SaveFileDialog
        Me.txtCount2 = New System.Windows.Forms.TextBox
        Me.txtCount1 = New System.Windows.Forms.TextBox
        Me.txtCount0 = New System.Windows.Forms.TextBox
        Me.CommonDialog1Font = New System.Windows.Forms.FontDialog
        Me.Label4 = New System.Windows.Forms.Label
        Me.CommonDialog1Color = New System.Windows.Forms.ColorDialog
        Me.CommonDialog1Print = New System.Windows.Forms.PrintDialog
        Me.Label2 = New System.Windows.Forms.Label
        Me.Panel1.SuspendLayout()
        CType(Me.Image1, System.ComponentModel.ISupportInitialize).BeginInit()
        Me.SuspendLayout()
        '
        'Panel1
        '
        Me.Panel1.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.Panel1.Controls.Add(Me.Image1)
        Me.Panel1.Location = New System.Drawing.Point(8, 8)
        Me.Panel1.Name = "Panel1"
        Me.Panel1.Size = New System.Drawing.Size(376, 276)
        Me.Panel1.TabIndex = 55
        '
        'Image1
        '
        Me.Image1.Cursor = System.Windows.Forms.Cursors.Default
        Me.Image1.Location = New System.Drawing.Point(42, 26)
        Me.Image1.Name = "Image1"
        Me.Image1.Size = New System.Drawing.Size(180, 156)
        Me.Image1.SizeMode = System.Windows.Forms.PictureBoxSizeMode.StretchImage
        Me.Image1.TabIndex = 0
        Me.Image1.TabStop = False
        '
        'buttonPrint
        '
        Me.buttonPrint.Location = New System.Drawing.Point(296, 368)
        Me.buttonPrint.Name = "buttonPrint"
        Me.buttonPrint.Size = New System.Drawing.Size(88, 32)
        Me.buttonPrint.TabIndex = 54
        Me.buttonPrint.Text = "Print"
        Me.buttonPrint.UseVisualStyleBackColor = True
        '
        'labPrnName2
        '
        Me.labPrnName2.BackColor = System.Drawing.SystemColors.Control
        Me.labPrnName2.Cursor = System.Windows.Forms.Cursors.Default
        Me.labPrnName2.ForeColor = System.Drawing.SystemColors.ControlText
        Me.labPrnName2.Location = New System.Drawing.Point(200, 296)
        Me.labPrnName2.Name = "labPrnName2"
        Me.labPrnName2.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.labPrnName2.Size = New System.Drawing.Size(88, 16)
        Me.labPrnName2.TabIndex = 48
        Me.labPrnName2.Text = "DS-RX1_3"
        '
        'txtState3
        '
        Me.txtState3.AcceptsReturn = True
        Me.txtState3.BackColor = System.Drawing.SystemColors.Window
        Me.txtState3.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtState3.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtState3.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtState3.Location = New System.Drawing.Point(296, 312)
        Me.txtState3.MaxLength = 0
        Me.txtState3.Name = "txtState3"
        Me.txtState3.ReadOnly = True
        Me.txtState3.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtState3.Size = New System.Drawing.Size(88, 19)
        Me.txtState3.TabIndex = 53
        Me.txtState3.TabStop = False
        '
        'txtState2
        '
        Me.txtState2.AcceptsReturn = True
        Me.txtState2.BackColor = System.Drawing.SystemColors.Window
        Me.txtState2.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtState2.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtState2.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtState2.Location = New System.Drawing.Point(200, 312)
        Me.txtState2.MaxLength = 0
        Me.txtState2.Name = "txtState2"
        Me.txtState2.ReadOnly = True
        Me.txtState2.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtState2.Size = New System.Drawing.Size(88, 19)
        Me.txtState2.TabIndex = 52
        Me.txtState2.TabStop = False
        '
        'txtState1
        '
        Me.txtState1.AcceptsReturn = True
        Me.txtState1.BackColor = System.Drawing.SystemColors.Window
        Me.txtState1.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtState1.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtState1.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtState1.Location = New System.Drawing.Point(104, 312)
        Me.txtState1.MaxLength = 0
        Me.txtState1.Name = "txtState1"
        Me.txtState1.ReadOnly = True
        Me.txtState1.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtState1.Size = New System.Drawing.Size(88, 19)
        Me.txtState1.TabIndex = 51
        Me.txtState1.TabStop = False
        '
        'txtState0
        '
        Me.txtState0.BackColor = System.Drawing.SystemColors.Window
        Me.txtState0.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtState0.Location = New System.Drawing.Point(8, 312)
        Me.txtState0.Name = "txtState0"
        Me.txtState0.ReadOnly = True
        Me.txtState0.Size = New System.Drawing.Size(88, 19)
        Me.txtState0.TabIndex = 50
        Me.txtState0.TabStop = False
        Me.txtState0.Text = "Idle"
        '
        'labPrnName3
        '
        Me.labPrnName3.BackColor = System.Drawing.SystemColors.Control
        Me.labPrnName3.Cursor = System.Windows.Forms.Cursors.Default
        Me.labPrnName3.ForeColor = System.Drawing.SystemColors.ControlText
        Me.labPrnName3.Location = New System.Drawing.Point(296, 296)
        Me.labPrnName3.Name = "labPrnName3"
        Me.labPrnName3.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.labPrnName3.Size = New System.Drawing.Size(88, 16)
        Me.labPrnName3.TabIndex = 49
        Me.labPrnName3.Text = "DS-RX1_4"
        '
        'labPrnName1
        '
        Me.labPrnName1.BackColor = System.Drawing.SystemColors.Control
        Me.labPrnName1.Cursor = System.Windows.Forms.Cursors.Default
        Me.labPrnName1.ForeColor = System.Drawing.SystemColors.ControlText
        Me.labPrnName1.Location = New System.Drawing.Point(104, 296)
        Me.labPrnName1.Name = "labPrnName1"
        Me.labPrnName1.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.labPrnName1.Size = New System.Drawing.Size(88, 16)
        Me.labPrnName1.TabIndex = 47
        Me.labPrnName1.Text = "DS-RX1_2"
        '
        'labPrnName0
        '
        Me.labPrnName0.BackColor = System.Drawing.SystemColors.Control
        Me.labPrnName0.Cursor = System.Windows.Forms.Cursors.Default
        Me.labPrnName0.ForeColor = System.Drawing.SystemColors.ControlText
        Me.labPrnName0.Location = New System.Drawing.Point(8, 296)
        Me.labPrnName0.Name = "labPrnName0"
        Me.labPrnName0.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.labPrnName0.Size = New System.Drawing.Size(88, 16)
        Me.labPrnName0.TabIndex = 46
        Me.labPrnName0.Text = "DS-RX1_1"
        '
        'txtCount3
        '
        Me.txtCount3.AcceptsReturn = True
        Me.txtCount3.BackColor = System.Drawing.SystemColors.Window
        Me.txtCount3.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtCount3.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtCount3.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtCount3.Location = New System.Drawing.Point(296, 336)
        Me.txtCount3.MaxLength = 0
        Me.txtCount3.Name = "txtCount3"
        Me.txtCount3.ReadOnly = True
        Me.txtCount3.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtCount3.Size = New System.Drawing.Size(88, 19)
        Me.txtCount3.TabIndex = 45
        Me.txtCount3.TabStop = False
        '
        'txtRemain
        '
        Me.txtRemain.AcceptsReturn = True
        Me.txtRemain.BackColor = System.Drawing.SystemColors.Window
        Me.txtRemain.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtRemain.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtRemain.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtRemain.Location = New System.Drawing.Point(184, 368)
        Me.txtRemain.MaxLength = 0
        Me.txtRemain.Name = "txtRemain"
        Me.txtRemain.ReadOnly = True
        Me.txtRemain.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtRemain.Size = New System.Drawing.Size(65, 19)
        Me.txtRemain.TabIndex = 40
        Me.txtRemain.TabStop = False
        Me.txtRemain.Text = "0"
        Me.txtRemain.TextAlign = System.Windows.Forms.HorizontalAlignment.Right
        '
        'txtQuantity
        '
        Me.txtQuantity.AcceptsReturn = True
        Me.txtQuantity.BackColor = System.Drawing.SystemColors.Window
        Me.txtQuantity.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtQuantity.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtQuantity.Location = New System.Drawing.Point(60, 368)
        Me.txtQuantity.MaxLength = 0
        Me.txtQuantity.Name = "txtQuantity"
        Me.txtQuantity.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtQuantity.Size = New System.Drawing.Size(65, 19)
        Me.txtQuantity.TabIndex = 39
        Me.txtQuantity.Text = "1"
        Me.txtQuantity.TextAlign = System.Windows.Forms.HorizontalAlignment.Right
        '
        'txtCount2
        '
        Me.txtCount2.AcceptsReturn = True
        Me.txtCount2.BackColor = System.Drawing.SystemColors.Window
        Me.txtCount2.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtCount2.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtCount2.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtCount2.Location = New System.Drawing.Point(200, 336)
        Me.txtCount2.MaxLength = 0
        Me.txtCount2.Name = "txtCount2"
        Me.txtCount2.ReadOnly = True
        Me.txtCount2.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtCount2.Size = New System.Drawing.Size(88, 19)
        Me.txtCount2.TabIndex = 44
        Me.txtCount2.TabStop = False
        '
        'txtCount1
        '
        Me.txtCount1.AcceptsReturn = True
        Me.txtCount1.BackColor = System.Drawing.SystemColors.Window
        Me.txtCount1.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtCount1.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtCount1.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtCount1.Location = New System.Drawing.Point(104, 336)
        Me.txtCount1.MaxLength = 0
        Me.txtCount1.Name = "txtCount1"
        Me.txtCount1.ReadOnly = True
        Me.txtCount1.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtCount1.Size = New System.Drawing.Size(88, 19)
        Me.txtCount1.TabIndex = 43
        Me.txtCount1.TabStop = False
        '
        'txtCount0
        '
        Me.txtCount0.AcceptsReturn = True
        Me.txtCount0.BackColor = System.Drawing.SystemColors.Window
        Me.txtCount0.BorderStyle = System.Windows.Forms.BorderStyle.FixedSingle
        Me.txtCount0.Cursor = System.Windows.Forms.Cursors.IBeam
        Me.txtCount0.ForeColor = System.Drawing.SystemColors.WindowText
        Me.txtCount0.Location = New System.Drawing.Point(8, 336)
        Me.txtCount0.MaxLength = 0
        Me.txtCount0.Name = "txtCount0"
        Me.txtCount0.ReadOnly = True
        Me.txtCount0.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.txtCount0.Size = New System.Drawing.Size(88, 19)
        Me.txtCount0.TabIndex = 42
        Me.txtCount0.TabStop = False
        Me.txtCount0.Text = "123"
        '
        'Label4
        '
        Me.Label4.BackColor = System.Drawing.SystemColors.Control
        Me.Label4.Cursor = System.Windows.Forms.Cursors.Default
        Me.Label4.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label4.Location = New System.Drawing.Point(140, 372)
        Me.Label4.Name = "Label4"
        Me.Label4.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.Label4.Size = New System.Drawing.Size(48, 16)
        Me.Label4.TabIndex = 41
        Me.Label4.Text = "Remain"
        '
        'Label2
        '
        Me.Label2.BackColor = System.Drawing.SystemColors.Control
        Me.Label2.Cursor = System.Windows.Forms.Cursors.Default
        Me.Label2.ForeColor = System.Drawing.SystemColors.ControlText
        Me.Label2.Location = New System.Drawing.Point(7, 372)
        Me.Label2.Name = "Label2"
        Me.Label2.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.Label2.Size = New System.Drawing.Size(57, 17)
        Me.Label2.TabIndex = 38
        Me.Label2.Text = "Quantity"
        '
        'Form1
        '
        Me.AutoScaleDimensions = New System.Drawing.SizeF(6.0!, 12.0!)
        Me.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font
        Me.BackColor = System.Drawing.SystemColors.Control
        Me.ClientSize = New System.Drawing.Size(393, 406)
        Me.Controls.Add(Me.Panel1)
        Me.Controls.Add(Me.buttonPrint)
        Me.Controls.Add(Me.labPrnName2)
        Me.Controls.Add(Me.txtState3)
        Me.Controls.Add(Me.txtState2)
        Me.Controls.Add(Me.txtState1)
        Me.Controls.Add(Me.txtState0)
        Me.Controls.Add(Me.labPrnName3)
        Me.Controls.Add(Me.labPrnName1)
        Me.Controls.Add(Me.labPrnName0)
        Me.Controls.Add(Me.txtCount3)
        Me.Controls.Add(Me.txtRemain)
        Me.Controls.Add(Me.txtQuantity)
        Me.Controls.Add(Me.txtCount2)
        Me.Controls.Add(Me.txtCount1)
        Me.Controls.Add(Me.txtCount0)
        Me.Controls.Add(Me.Label4)
        Me.Controls.Add(Me.Label2)
        Me.Cursor = System.Windows.Forms.Cursors.Default
        Me.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle
        Me.Location = New System.Drawing.Point(8, 34)
        Me.MaximizeBox = False
        Me.MinimizeBox = False
        Me.Name = "Form1"
        Me.RightToLeft = System.Windows.Forms.RightToLeft.No
        Me.Text = "DS-RX1 Print Setting Sample"
        Me.Panel1.ResumeLayout(False)
        CType(Me.Image1, System.ComponentModel.ISupportInitialize).EndInit()
        Me.ResumeLayout(False)
        Me.PerformLayout()

    End Sub
    Friend WithEvents Panel1 As System.Windows.Forms.Panel
    Public WithEvents Image1 As System.Windows.Forms.PictureBox
    Friend WithEvents buttonPrint As System.Windows.Forms.Button
    Public WithEvents labPrnName2 As System.Windows.Forms.Label
    Public WithEvents txtState3 As System.Windows.Forms.TextBox
    Public WithEvents txtState2 As System.Windows.Forms.TextBox
    Public WithEvents txtState1 As System.Windows.Forms.TextBox
    Public WithEvents txtState0 As System.Windows.Forms.TextBox
    Public WithEvents labPrnName3 As System.Windows.Forms.Label
    Public WithEvents ToolTip1 As System.Windows.Forms.ToolTip
    Public WithEvents labPrnName1 As System.Windows.Forms.Label
    Public WithEvents labPrnName0 As System.Windows.Forms.Label
    Public WithEvents txtCount3 As System.Windows.Forms.TextBox
    Public WithEvents CommonDialog1Open As System.Windows.Forms.OpenFileDialog
    Public WithEvents txtRemain As System.Windows.Forms.TextBox
    Public WithEvents txtQuantity As System.Windows.Forms.TextBox
    Public WithEvents CommonDialog1Save As System.Windows.Forms.SaveFileDialog
    Public WithEvents txtCount2 As System.Windows.Forms.TextBox
    Public WithEvents txtCount1 As System.Windows.Forms.TextBox
    Public WithEvents txtCount0 As System.Windows.Forms.TextBox
    Public WithEvents CommonDialog1Font As System.Windows.Forms.FontDialog
    Public WithEvents Label4 As System.Windows.Forms.Label
    Public WithEvents CommonDialog1Color As System.Windows.Forms.ColorDialog
    Public WithEvents CommonDialog1Print As System.Windows.Forms.PrintDialog
    Public WithEvents Label2 As System.Windows.Forms.Label
#End Region
End Class