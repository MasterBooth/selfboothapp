using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;
using RelayNS;

namespace RelayUI
{
    public partial class Form1 : Form
    {
        bool m_opened;
        int connectedDevice;

        public Form1()
        {
            InitializeComponent();
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        private void Form1_Load(object sender, EventArgs e)
        {
            RelayMgr.initial();
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        private void btnFindDevice_Click(object sender, EventArgs e)
        {
            if (m_opened)
            {
                MessageBox.Show("Close Current Device First", "Attention", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
            cbDeviceList.Items.Clear();
            var devices = RelayMgr.Gets().devices;
            for (int i = 0; i < devices.Length; i++)
            {
                cbDeviceList.Items.Add(devices[i]);
            }
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        private void btnOpenDevice_Click(object sender, EventArgs e)
        {
            if (m_opened)
            {
                MessageBox.Show("Close Current Device First", "Attention", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            int index = cbDeviceList.SelectedIndex;
            if (index > -1)
            {
                var serial = cbDeviceList.Items[index].ToString();
                connectedDevice = RelayMgr.Connect(serial);
                if (connectedDevice != -1)
                {
                    m_opened = true;
                    this.panel_connected.BackColor = Color.Green;
                }
            }
            return;
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////
        private void btnCloseDevice_Click(object sender, EventArgs e)
        {
            if (!m_opened)
            {
                MessageBox.Show("Open Device First", "Attention", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            RelayMgr.Disconnect(connectedDevice);
            m_opened = false;
            this.panel_connected.BackColor = Color.Red;
            connectedDevice = -1;
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        private void btn_openAll_Click(object sender, EventArgs e)
        {
            if (!m_opened)
            {
                MessageBox.Show("Open Device First", "Attention", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            bool opened = RelayMgr.OpenAll(connectedDevice);
            if (opened)
            {
                this.panel1.BackColor = Color.Green;
                this.panel2.BackColor = Color.Green;
            }
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        private void btn_CloseAll_Click(object sender, EventArgs e)
        {
            if (!m_opened)
            {
                MessageBox.Show("Open Device First", "Attention", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            bool closed = RelayMgr.CloseAll(connectedDevice);
            if (closed)
            {
                this.panel1.BackColor = Color.Red;
                this.panel2.BackColor = Color.Red;
            }
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        private void btn_Open1Click(object sender, EventArgs e)
        {
            OpenRelay(1, panel1);
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        private void btn_Open2Click(object sender, EventArgs e)
        {
            OpenRelay(2, panel2);
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        private void btn_Close1Click(object sender, EventArgs e)
        {
            CloseRelay(1, panel1);
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////
        private void btn_Close2Click(object sender, EventArgs e)
        {
            CloseRelay(2, panel2);
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        void OpenRelay(int relayID, Panel panel)
        {
            if (!m_opened)
            {
                MessageBox.Show("Open Device First", "Attention", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            bool ret = RelayMgr.OpenOne(connectedDevice, relayID);
            if (ret)
            {
                panel.BackColor = Color.Green;
            }
        }

        ////////////////////////////////////////////////////////////////////////////////////////////////////

        void CloseRelay(int relayID, Panel panel)
        {
            if (!m_opened)
            {
                MessageBox.Show("Open Device First", "Attention", MessageBoxButtons.OK, MessageBoxIcon.Error);
                return;
            }

            bool ret = RelayMgr.CloseOne(connectedDevice, relayID);
            if (ret)
            {
                panel.BackColor = Color.Red;
            }
        }

        
    }
}
