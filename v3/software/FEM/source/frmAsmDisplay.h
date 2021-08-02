#pragma once
#include "Disassem.h"

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
			animateDelay = 300000;
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
	public:
		bool animate;
		int animateDelay;
		unsigned int ad;

#pragma region Windows Form Designer generated code
		/// <summary>
		/// Required method for Designer support - do not modify
		/// the contents of this method with the code editor.
		/// </summary>
		void InitializeComponent(void)
		{
			this->SuspendLayout();
			// 
			// frmAsmDisplay
			// 
			this->AutoScaleDimensions = System::Drawing::SizeF(6, 13);
			this->AutoScaleMode = System::Windows::Forms::AutoScaleMode::Font;
			this->ClientSize = System::Drawing::Size(668, 398);
			this->DoubleBuffered = true;
			this->FormBorderStyle = System::Windows::Forms::FormBorderStyle::FixedToolWindow;
			this->MaximizeBox = false;
			this->Name = L"frmAsmDisplay";
			this->Text = L"FEM Asm Display";
			this->Paint += gcnew System::Windows::Forms::PaintEventHandler(this, &frmAsmDisplay::frmAsmDisplay_Paint);
			this->ResumeLayout(false);

		}
#pragma endregion
	private: System::Void frmAsmDisplay_Paint(System::Object^  sender, System::Windows::Forms::PaintEventArgs^  e) {
				Graphics^ gr = e->Graphics;
				LARGE_INTEGER perf_count;
				static LARGE_INTEGER operf_count = { 0 };
				static uint64_t old_ad = 0xffffffffffffffffLL;
				char buf[200];
				char *buf2;
				std::string str;
				unsigned int row;
				int xx, yy;
				uint64_t ad1, ad2, csip;
				uint64_t dat;
				static unsigned int ticks;
				int regno;

				ticks++;
				do {
   					QueryPerformanceCounter(&perf_count);
				}	while (perf_count.QuadPart - operf_count.QuadPart < 50LL);
				operf_count = perf_count;

				//ad2 = ad;
				csip = ((cpu1.sregs[15] & 0xFFFFFFF0LL) << 1LL) + cpu1.pc;
				ad2 = csip - 72LL;
				//if (ad2 != old_ad)
				{
					if (animate) {
						if ((ticks % animateDelay)==0)
							cpu1.Step();
					}
					old_ad = ad2;
					xx = 8;
					gr->FillRectangle(bkbr,0,0,700,400);
					for (row = 0; row < 32; row++) {
						yy = row * 12 + 10;
						sprintf(buf,"%06X.%.1X", ad2 >> 1, (ad2 & 1) << 3);
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
						yy = regno * 12 + 10;
						sprintf(buf, "x%d %08X", regno, cpu1.regs[regno][cpu1.rgs]);
						str = std::string(buf);
						gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,320,yy);
					}
					for (regno = 16; regno < 32; regno++)
					{
						yy = (regno - 16) * 12 + 10;
						sprintf(buf, "x%d %08X", regno, cpu1.regs[regno][cpu1.rgs]);
						str = std::string(buf);
						gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,430,yy);
					}
					for (regno = 0; regno < 16; regno++)
					{
						yy = regno * 12 + 10;
						switch (regno) {
						case  0:	strcpy(buf, " ds"); break;
						case 10:	strcpy(buf, " ss"); break;
						case 11:	strcpy(buf, "ios"); break;
						case 12:	strcpy(buf, "ros"); break;
						case 15:	strcpy(buf, " cs"); break;
						default:	strcpy(buf, "   ");
						}
						sprintf(&buf[3], " b%d %08X", regno, cpu1.sregs[regno]);
						str = std::string(buf);
						gr->DrawString(gcnew String(str.c_str()), myfont, fgbr, 540, yy);
					}
					yy = 18 * 12 + 10;
					sprintf(buf, "cs %08I64X", cpu1.sregs[15]);
					str = std::string(buf);
					gr->DrawString(gcnew String(str.c_str()), myfont, fgbr, 320, yy);
					yy = 19 * 12 + 10;
					sprintf(buf, "ip %08I64X.%1X", cpu1.pc >> 1, (unsigned int)(cpu1.pc & 1) << 3);
					str = std::string(buf);
					gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,320,yy);

					this->Invalidate();
				}
			 }
	};
}
