#pragma once
#include "Disassem.h"

extern int64_t perf_frq;
extern int numBreakpoints;
extern uint64_t breakpoints[30];

namespace E64 {

	using namespace System;
	using namespace System::ComponentModel;
	using namespace System::Collections;
	using namespace System::Windows::Forms;
	using namespace System::Data;
	using namespace System::Drawing;

	using namespace System::Drawing::Imaging;
	using namespace System::IO;
	using namespace System::Threading;
	using namespace System::Runtime::InteropServices;

	/// <summary>
	/// Summary for frmAsmDisplay
	/// </summary>
	public ref class frmAsmDisplay : public System::Windows::Forms::Form
	{
	public:
		frmAsmDisplay(void)
		{
			InitializeComponent();
			//
			//TODO: Add the constructor code here
			//
			this->SetStyle(ControlStyles::AllPaintingInWmPaint
				| ControlStyles::Opaque, true);
			myfont = gcnew System::Drawing::Font("Courier New", 8);
			bkbr = gcnew System::Drawing::SolidBrush(System::Drawing::Color::Blue);
			fgbr = gcnew System::Drawing::SolidBrush(System::Drawing::Color::White);
			dgbr = gcnew System::Drawing::SolidBrush(System::Drawing::Color::DarkGreen);
			grbr = gcnew System::Drawing::SolidBrush(System::Drawing::Color::LightGreen);
			animateDelay = 300000;
			firstBase = 0;
			QueryPerformanceFrequency((LARGE_INTEGER*)&perf_frq);
			secsPerCount = (double)1.0 / (double)perf_frq;
		}

	protected:
		/// <summary>
		/// Clean up any resources being used.
		/// </summary>
		~frmAsmDisplay()
		{
			if (components)
			{
				delete components;
			}
		}

	private:
		/// <summary>
		/// Required designer variable.
		/// </summary>
		System::ComponentModel::Container ^components;
		System::Drawing::Font^ myfont;
		SolidBrush^ bkbr;
		SolidBrush^ fgbr;
		SolidBrush^ dgbr;
		SolidBrush^ grbr;
		double secsPerCount;
	public:
		bool animate;
		int animateDelay;
	private: System::Windows::Forms::ToolStrip^ toolStrip1;
	public:
		unsigned int ad;
		unsigned int firstBase;
	private: System::Windows::Forms::ToolStripButton^ toolStripButton1;
	private: System::Windows::Forms::ToolStripButton^ toolStripButton2;

#pragma region Windows Form Designer generated code
		/// <summary>
		/// Required method for Designer support - do not modify
		/// the contents of this method with the code editor.
		/// </summary>
		void InitializeComponent(void)
		{
			System::ComponentModel::ComponentResourceManager^ resources = (gcnew System::ComponentModel::ComponentResourceManager(frmAsmDisplay::typeid));
			this->toolStrip1 = (gcnew System::Windows::Forms::ToolStrip());
			this->toolStripButton1 = (gcnew System::Windows::Forms::ToolStripButton());
			this->toolStripButton2 = (gcnew System::Windows::Forms::ToolStripButton());
			this->toolStrip1->SuspendLayout();
			this->SuspendLayout();
			// 
			// toolStrip1
			// 
			this->toolStrip1->Items->AddRange(gcnew cli::array< System::Windows::Forms::ToolStripItem^  >(2) {
				this->toolStripButton1,
					this->toolStripButton2
			});
			this->toolStrip1->Location = System::Drawing::Point(0, 0);
			this->toolStrip1->Name = L"toolStrip1";
			this->toolStrip1->Size = System::Drawing::Size(767, 25);
			this->toolStrip1->TabIndex = 0;
			this->toolStrip1->Text = L"toolStrip1";
			// 
			// toolStripButton1
			// 
			this->toolStripButton1->DisplayStyle = System::Windows::Forms::ToolStripItemDisplayStyle::Image;
			this->toolStripButton1->Image = (cli::safe_cast<System::Drawing::Image^>(resources->GetObject(L"toolStripButton1.Image")));
			this->toolStripButton1->ImageTransparentColor = System::Drawing::Color::Magenta;
			this->toolStripButton1->Name = L"toolStripButton1";
			this->toolStripButton1->Size = System::Drawing::Size(23, 22);
			this->toolStripButton1->Text = L"toolStripButton1";
			this->toolStripButton1->Click += gcnew System::EventHandler(this, &frmAsmDisplay::toolStripButton1_Click);
			// 
			// toolStripButton2
			// 
			this->toolStripButton2->DisplayStyle = System::Windows::Forms::ToolStripItemDisplayStyle::Image;
			this->toolStripButton2->Image = (cli::safe_cast<System::Drawing::Image^>(resources->GetObject(L"toolStripButton2.Image")));
			this->toolStripButton2->ImageTransparentColor = System::Drawing::Color::Magenta;
			this->toolStripButton2->Name = L"toolStripButton2";
			this->toolStripButton2->Size = System::Drawing::Size(23, 22);
			this->toolStripButton2->Text = L"toolStripButton2";
			// 
			// frmAsmDisplay
			// 
			this->AutoScaleDimensions = System::Drawing::SizeF(6, 13);
			this->AutoScaleMode = System::Windows::Forms::AutoScaleMode::Font;
			this->ClientSize = System::Drawing::Size(767, 450);
			this->Controls->Add(this->toolStrip1);
			this->DoubleBuffered = true;
			this->FormBorderStyle = System::Windows::Forms::FormBorderStyle::FixedToolWindow;
			this->MaximizeBox = false;
			this->Name = L"frmAsmDisplay";
			this->Text = L"FSIM Asm Display";
			this->Paint += gcnew System::Windows::Forms::PaintEventHandler(this, &frmAsmDisplay::frmAsmDisplay_Paint);
			this->toolStrip1->ResumeLayout(false);
			this->toolStrip1->PerformLayout();
			this->ResumeLayout(false);
			this->PerformLayout();

		}
#pragma endregion
	private: System::Void frmAsmDisplay_Paint(System::Object^  sender, System::Windows::Forms::PaintEventArgs^  e) {
				Graphics^ gr = e->Graphics;
				int64_t perf_count;
				static int64_t operf_count = 0;
				static uint64_t old_ad = 0xffffffffffffffffLL;
				char buf[200];
				char *buf2;
				std::string str;
				unsigned int row;
				int xx, yy, ledno, leds;
				uint64_t ad1, ad2, csip;
				uint64_t dat;
				static unsigned int ticks;
				int regno, kk;
				double secsPassed;
				bool run = false;

				ticks++;
				do {
					QueryPerformanceCounter((LARGE_INTEGER*)&perf_count);
					secsPassed = (double)(perf_count - operf_count) * secsPerCount;
				}
				while (secsPassed < (double)0.0167);
				operf_count = perf_count;

				//ad2 = ad;
				csip = ((cpu1.desc[7].base & 0xFFFFFFC0LL) << 1LL) + cpu1.pc;
				ad2 = csip - 72LL;
				//if (ad2 != old_ad)
				{
					if (animate) {
						run = true;
						for (kk = 0; kk < numBreakpoints; kk++) {
							if ((cpu1.pc & 0x1ffffffffLL) == (breakpoints[kk] & 0x1ffffffffLL)) {
								run = false;
							}
						}
						if ((ticks % animateDelay)==0 && run)
							cpu1.Step();
					}
					old_ad = ad2;
					xx = 8;
					gr->FillRectangle(bkbr,0,0,740,430);
					for (row = 0; row < 32; row++) {
						yy = row * 12 + 40;
						sprintf(buf,"%06I64X.%.1X", ((int64_t)ad2 >> 1LL) & 0xffffffffL, (int)(ad2 & 1LL) << 3);
						str = std::string(buf);
						dat = system1.IFetch(ad2);
			//			dat = system1.memory[ad>>2];
						if (ad2==csip) {
							gr->FillRectangle(fgbr,0,yy,300,12);
							gr->DrawString(gcnew String(str.c_str()),myfont,bkbr,xx,yy);
							sprintf(buf,"%09I64X", dat);
							str = std::string(buf);
							gr->DrawString(gcnew String(str.c_str()),myfont,bkbr,xx + 80,yy);
							str = Disassem((unsigned int)	ad2,dat,(unsigned int *)&ad1);
							gr->DrawString(gcnew String(str.c_str()),myfont,bkbr,xx + 144,yy);
						}
						else {
							gr->FillRectangle(bkbr,0,yy,300,12);
							gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,xx,yy);
							sprintf(buf,"%09I64X", dat);
							str = std::string(buf);
							gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,xx + 80,yy);
							str = Disassem((unsigned int)ad2,dat,(unsigned int *)&ad1);
							gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,xx + 144,yy);
						}
						ad2 = ad2 + 9LL;
					}

					for (regno = 0; regno < 16; regno++)
					{
						yy = regno * 12 + 40;
						sprintf(buf, "x%d %016I64X", regno, cpu1.regs[regno][cpu1.rgs]);
						str = std::string(buf);
						gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,320,yy);
					}
					for (regno = 16; regno < 32; regno++)
					{
						yy = (regno - 16) * 12 + 40;
						sprintf(buf, "x%d %016I64X", regno, cpu1.regs[regno][cpu1.rgs]);
						str = std::string(buf);
						gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,470,yy);
					}
					for (regno = firstBase; regno < firstBase + 16; regno++)
					{
						yy = regno * 12 + 40;
						switch (regno) {
						case 0:	strcpy(buf, " ds"); break;
						case 3:	strcpy(buf, " ss"); break;
						case 4:	strcpy(buf, "ios"); break;
						case 5:	strcpy(buf, "ros"); break;
						case 6:	strcpy(buf, " rs"); break;
						case 7:	strcpy(buf, " cs"); break;
						default:	strcpy(buf, "   ");
						}
						sprintf(&buf[3], " b%d %05X", regno, cpu1.sregs[regno]);
						str = std::string(buf);
						gr->DrawString(gcnew String(str.c_str()), myfont, fgbr, 610, yy);
					}
					yy = 18 * 12 + 40;
					sprintf(buf, "cs %05X", cpu1.sregs[7]);
					str = std::string(buf);
					gr->DrawString(gcnew String(str.c_str()), myfont, fgbr, 320, yy);
					yy = 19 * 12 + 40;
					sprintf(buf, "ip %08I64X.%1X", (int64_t)cpu1.pc >> 1, (unsigned int)(cpu1.pc & 1) << 3);
					str = std::string(buf);
					gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,320,yy);

					yy = 33 * 12 + 40;
					sprintf(buf, "LEDS");
					str = std::string(buf);
					gr->DrawString(gcnew String(str.c_str()), myfont, fgbr, 16, yy);
					leds = system1.leds;
					for (ledno = 0; ledno < 8; ledno++) {
						if (leds & 0x80)
							gr->FillRectangle(grbr, 80 + ledno * 16, yy, 12, 12);
						else
							gr->FillRectangle(dgbr, 80 + ledno * 16, yy, 12, 12);
						leds <<= 1;
					}
					this->Invalidate();
				}
			 }
	private: System::Void toolStripButton1_Click(System::Object^ sender, System::EventArgs^ e) {
	}
};
}
