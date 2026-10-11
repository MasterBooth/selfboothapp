namespace RelayUI
{
    partial class Form1
    {
        /// <summary>
        /// Required designer variable.
        /// </summary>
        private System.ComponentModel.IContainer components = null;

        /// <summary>
        /// Clean up any resources being used.
        /// </summary>
        /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
        protected override void Dispose(bool disposing)
        {
            if (disposing && (components != null))
            {
                components.Dispose();
            }
            base.Dispose(disposing);
        }

        #region Windows Form Designer generated code

        /// <summary>
        /// Required method for Designer support - do not modify
        /// the contents of this method with the code editor.
        /// </summary>
        private void InitializeComponent()
        {
            this.btnFindDevice = new System.Windows.Forms.Button();
            this.cbDeviceList = new System.Windows.Forms.ComboBox();
            this.btnOpenDevice = new System.Windows.Forms.Button();
            this.btnCloseDevice = new System.Windows.Forms.Button();
            this.panel_connected = new System.Windows.Forms.Panel();
            this.textBox1 = new System.Windows.Forms.TextBox();
            this.btn_open1 = new System.Windows.Forms.Button();
            this.panel1 = new System.Windows.Forms.Panel();
            this.btn_close1 = new System.Windows.Forms.Button();
            this.btn_close2 = new System.Windows.Forms.Button();
            this.panel2 = new System.Windows.Forms.Panel();
            this.btn_open2 = new System.Windows.Forms.Button();
            this.textBox2 = new System.Windows.Forms.TextBox();
            this.btn_openAll = new System.Windows.Forms.Button();
            this.btn_CloseAll = new System.Windows.Forms.Button();
            this.label1 = new System.Windows.Forms.Label();
            this.SuspendLayout();
            // 
            // btnFindDevice
            // 
            this.btnFindDevice.Location = new System.Drawing.Point(12, 12);
            this.btnFindDevice.Name = "btnFindDevice";
            this.btnFindDevice.Size = new System.Drawing.Size(90, 30);
            this.btnFindDevice.TabIndex = 0;
            this.btnFindDevice.Text = "Find Device";
            this.btnFindDevice.UseVisualStyleBackColor = true;
            this.btnFindDevice.Click += new System.EventHandler(this.btnFindDevice_Click);
            // 
            // cbDeviceList
            // 
            this.cbDeviceList.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
            this.cbDeviceList.FormattingEnabled = true;
            this.cbDeviceList.Location = new System.Drawing.Point(119, 18);
            this.cbDeviceList.Name = "cbDeviceList";
            this.cbDeviceList.Size = new System.Drawing.Size(167, 21);
            this.cbDeviceList.TabIndex = 1;
            // 
            // btnOpenDevice
            // 
            this.btnOpenDevice.Location = new System.Drawing.Point(12, 50);
            this.btnOpenDevice.Name = "btnOpenDevice";
            this.btnOpenDevice.Size = new System.Drawing.Size(90, 30);
            this.btnOpenDevice.TabIndex = 2;
            this.btnOpenDevice.Text = "Open Device";
            this.btnOpenDevice.UseVisualStyleBackColor = true;
            this.btnOpenDevice.Click += new System.EventHandler(this.btnOpenDevice_Click);
            // 
            // btnCloseDevice
            // 
            this.btnCloseDevice.Location = new System.Drawing.Point(196, 50);
            this.btnCloseDevice.Name = "btnCloseDevice";
            this.btnCloseDevice.Size = new System.Drawing.Size(90, 30);
            this.btnCloseDevice.TabIndex = 3;
            this.btnCloseDevice.Text = "Close Device";
            this.btnCloseDevice.UseVisualStyleBackColor = true;
            this.btnCloseDevice.Click += new System.EventHandler(this.btnCloseDevice_Click);
            // 
            // panel_connected
            // 
            this.panel_connected.BackColor = System.Drawing.Color.Red;
            this.panel_connected.Location = new System.Drawing.Point(119, 50);
            this.panel_connected.Name = "panel_connected";
            this.panel_connected.Size = new System.Drawing.Size(60, 30);
            this.panel_connected.TabIndex = 4;
            // 
            // textBox1
            // 
            this.textBox1.Location = new System.Drawing.Point(12, 90);
            this.textBox1.Name = "textBox1";
            this.textBox1.Size = new System.Drawing.Size(89, 20);
            this.textBox1.TabIndex = 5;
            this.textBox1.Text = "Relay 1";
            this.textBox1.TextAlign = System.Windows.Forms.HorizontalAlignment.Center;
            // 
            // btn_open1
            // 
            this.btn_open1.Location = new System.Drawing.Point(119, 84);
            this.btn_open1.Name = "btn_open1";
            this.btn_open1.Size = new System.Drawing.Size(50, 30);
            this.btn_open1.TabIndex = 6;
            this.btn_open1.Text = "open";
            this.btn_open1.UseVisualStyleBackColor = true;
            this.btn_open1.Click += new System.EventHandler(this.btn_Open1Click);
            // 
            // panel1
            // 
            this.panel1.BackColor = System.Drawing.Color.Red;
            this.panel1.Location = new System.Drawing.Point(186, 84);
            this.panel1.Name = "panel1";
            this.panel1.Size = new System.Drawing.Size(30, 30);
            this.panel1.TabIndex = 5;
            // 
            // btn_close1
            // 
            this.btn_close1.Location = new System.Drawing.Point(236, 84);
            this.btn_close1.Name = "btn_close1";
            this.btn_close1.Size = new System.Drawing.Size(50, 30);
            this.btn_close1.TabIndex = 7;
            this.btn_close1.Text = "close";
            this.btn_close1.UseVisualStyleBackColor = true;
            this.btn_close1.Click += new System.EventHandler(this.btn_Close1Click);
            // 
            // btn_close2
            // 
            this.btn_close2.Location = new System.Drawing.Point(236, 120);
            this.btn_close2.Name = "btn_close2";
            this.btn_close2.Size = new System.Drawing.Size(50, 30);
            this.btn_close2.TabIndex = 11;
            this.btn_close2.Text = "close";
            this.btn_close2.UseVisualStyleBackColor = true;
            this.btn_close2.Click += new System.EventHandler(this.btn_Close2Click);
            // 
            // panel2
            // 
            this.panel2.BackColor = System.Drawing.Color.Red;
            this.panel2.Location = new System.Drawing.Point(186, 120);
            this.panel2.Name = "panel2";
            this.panel2.Size = new System.Drawing.Size(30, 30);
            this.panel2.TabIndex = 8;
            // 
            // btn_open2
            // 
            this.btn_open2.Location = new System.Drawing.Point(119, 120);
            this.btn_open2.Name = "btn_open2";
            this.btn_open2.Size = new System.Drawing.Size(50, 30);
            this.btn_open2.TabIndex = 10;
            this.btn_open2.Text = "open";
            this.btn_open2.UseVisualStyleBackColor = true;
            this.btn_open2.Click += new System.EventHandler(this.btn_Open2Click);
            // 
            // textBox2
            // 
            this.textBox2.Location = new System.Drawing.Point(12, 126);
            this.textBox2.Name = "textBox2";
            this.textBox2.Size = new System.Drawing.Size(89, 20);
            this.textBox2.TabIndex = 9;
            this.textBox2.Text = "Relay 2";
            this.textBox2.TextAlign = System.Windows.Forms.HorizontalAlignment.Center;
            // 
            // btn_openAll
            // 
            this.btn_openAll.Location = new System.Drawing.Point(79, 200);
            this.btn_openAll.Name = "btn_openAll";
            this.btn_openAll.Size = new System.Drawing.Size(90, 30);
            this.btn_openAll.TabIndex = 12;
            this.btn_openAll.Text = "Open all relay";
            this.btn_openAll.UseVisualStyleBackColor = true;
            this.btn_openAll.Click += new System.EventHandler(this.btn_openAll_Click);
            // 
            // btn_CloseAll
            // 
            this.btn_CloseAll.Location = new System.Drawing.Point(186, 200);
            this.btn_CloseAll.Name = "btn_CloseAll";
            this.btn_CloseAll.Size = new System.Drawing.Size(90, 30);
            this.btn_CloseAll.TabIndex = 13;
            this.btn_CloseAll.Text = "Close all relay";
            this.btn_CloseAll.UseVisualStyleBackColor = true;
            this.btn_CloseAll.Click += new System.EventHandler(this.btn_CloseAll_Click);
            // 
            // label1
            // 
            this.label1.AutoSize = true;
            this.label1.Location = new System.Drawing.Point(13, 153);
            this.label1.Name = "label1";
            this.label1.Size = new System.Drawing.Size(35, 13);
            this.label1.TabIndex = 14;
            this.label1.Text = "label1";
            // 
            // Form1
            // 
            this.AutoScaleDimensions = new System.Drawing.SizeF(6F, 13F);
            this.AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
            this.ClientSize = new System.Drawing.Size(298, 450);
            this.Controls.Add(this.label1);
            this.Controls.Add(this.btn_CloseAll);
            this.Controls.Add(this.btn_openAll);
            this.Controls.Add(this.btn_close2);
            this.Controls.Add(this.panel2);
            this.Controls.Add(this.btn_open2);
            this.Controls.Add(this.textBox2);
            this.Controls.Add(this.btn_close1);
            this.Controls.Add(this.panel1);
            this.Controls.Add(this.btn_open1);
            this.Controls.Add(this.textBox1);
            this.Controls.Add(this.panel_connected);
            this.Controls.Add(this.btnCloseDevice);
            this.Controls.Add(this.btnOpenDevice);
            this.Controls.Add(this.cbDeviceList);
            this.Controls.Add(this.btnFindDevice);
            this.Name = "Form1";
            this.Text = "Form1";
            this.Load += new System.EventHandler(this.Form1_Load);
            this.ResumeLayout(false);
            this.PerformLayout();

        }

        #endregion

        private System.Windows.Forms.Button btnFindDevice;
        private System.Windows.Forms.ComboBox cbDeviceList;
        private System.Windows.Forms.Button btnOpenDevice;
        private System.Windows.Forms.Button btnCloseDevice;
        private System.Windows.Forms.Panel panel_connected;
        private System.Windows.Forms.TextBox textBox1;
        private System.Windows.Forms.Button btn_open1;
        private System.Windows.Forms.Panel panel1;
        private System.Windows.Forms.Button btn_close1;
        private System.Windows.Forms.Button btn_close2;
        private System.Windows.Forms.Panel panel2;
        private System.Windows.Forms.Button btn_open2;
        private System.Windows.Forms.TextBox textBox2;
        private System.Windows.Forms.Button btn_openAll;
        private System.Windows.Forms.Button btn_CloseAll;
        private System.Windows.Forms.Label label1;
    }
}

