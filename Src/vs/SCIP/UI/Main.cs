﻿using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;

namespace UI
{
    public partial class Main : Form
    {
        public Main()
        {
            InitializeComponent();
        }

        private void buttonEditIndividualDrivers_Click(object sender, EventArgs e)
        {
            FormIndividualDrivers child = new FormIndividualDrivers();

            this.Enabled = false;
            child.ShowDialog();
            this.Enabled = true;

        }
    }
}
