#pragma once
#include <Windows.h>
#include <string>
#include "clsSystem.h"
extern clsSystem system1;
extern char refscreen;

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
	/// Summary for frmScreen
	/// </summary>
	public ref class frmScreen : public System::Windows::Forms::Form
	{
	public:
		frmScreen(void)
		{
			InitializeComponent();
			//
			//TODO: Add the constructor code here
			//
			this->SetStyle(ControlStyles::AllPaintingInWmPaint
				| ControlStyles::Opaque, true);
			myfont = gcnew System::Drawing::Font("Courier New", 8);
			ur.X = 0;
			ur.Y = 0;
			ur.Width = 56*12;
			ur.Height = 31*12;
		}

	protected:
		/// <summary>
		/// Clean up any resources being used.
		/// </summary>
		~frmScreen()
		{
			if (components)
			{
				delete components;
			}
		}
	private: System::ComponentModel::IContainer^ components;
	protected:

	private:
		/// <summary>
		/// Required designer variable.
		/// </summary>

		System::Drawing::Rectangle ur;
	private: System::Windows::Forms::Timer^ timer1;
				 System::Drawing::Font^ myfont;

#pragma region Windows Form Designer generated code
		/// <summary>
		/// Required method for Designer support - do not modify
		/// the contents of this method with the code editor.
		/// </summary>
		void InitializeComponent(void)
		{
			this->components = (gcnew System::ComponentModel::Container());
			this->timer1 = (gcnew System::Windows::Forms::Timer(this->components));
			this->SuspendLayout();
			// 
			// timer1
			// 
			this->timer1->Enabled = true;
			this->timer1->Interval = 1000;
			this->timer1->Tick += gcnew System::EventHandler(this, &frmScreen::timer1_Tick);
			// 
			// frmScreen
			// 
			this->AutoScaleDimensions = System::Drawing::SizeF(6, 13);
			this->AutoScaleMode = System::Windows::Forms::AutoScaleMode::Font;
			this->ClientSize = System::Drawing::Size(726, 385);
			this->Name = L"frmScreen";
			this->Text = L"FEM Screen";
			this->Paint += gcnew System::Windows::Forms::PaintEventHandler(this, &frmScreen::frmScreen_Paint);
			this->ResumeLayout(false);

		}
#pragma endregion
	private: char ScreenToAscii(char ch)
{
     ch &= 0xFF;
     if (ch==0x1B)
        return 0x5B;
     if (ch==0x1D)
        return 0x5D;
     if (ch < 27)
        ch += 0x60;
     return ch;
}
  
	private: System::Void frmScreen_Paint(System::Object^  sender, System::Windows::Forms::PaintEventArgs^  e) {
				 char buf[10];
				 unsigned int ndx;
				 int r,g,b;
				 uint64_t v;
				 std::string str;
				 Graphics^ gr = e->Graphics;
				 SolidBrush^ bkbr;
				 SolidBrush^ fgbr;
				 Color^ col;
				 LARGE_INTEGER perf_count;
				 static LARGE_INTEGER operf_count = { 0 };
				 int nn;
				 int xx,yy;
				 int maxx,maxy,minx,miny;
				 maxx = 0; maxy = 0;
				 minx = 1000; miny = 1000;

				 do {
   					QueryPerformanceCounter(&perf_count);
				 }	while (perf_count.QuadPart - operf_count.QuadPart < 45000LL);
				operf_count = perf_count;

				 col = gcnew System::Drawing::Color;
				 bkbr = gcnew System::Drawing::SolidBrush(System::Drawing::Color::Blue);
				 fgbr = gcnew System::Drawing::SolidBrush(System::Drawing::Color::White);

				 for (xx = ur.X; xx < ur.X + ur.Width; xx += 12) {
					 for (yy = ur.Y; yy < ur.Y + ur.Height; yy += 12) {
						 ndx = (xx/12 + yy/12 * 56) * 2;
//						 if (system1.VideoMemDirty[ndx]) {
							v = system1.VideoMem[ndx] | ((uint64_t)system1.VideoMem[ndx+1] << 32LL);
							r = (((v >> 30) & 0x7fLL) << 1LL);
							g = (((v >> 23) & 0x7fLL) << 1LL);
							b = (((v >> 16) & 0x7fLL) << 1LL);
							bkbr->Color = col->FromArgb(255,r,g,b);
							gr->FillRectangle(bkbr,xx,yy,12,12);
							r = (((v >> 51) & 0x7fLL) << 1LL);
							g = (((v >> 44) & 0x7fLL) << 1LL);
							b = (((v >> 37) & 0x7FLL) << 1LL);
							fgbr->Color = col->FromArgb(255,r,g,b);
							sprintf(buf,"%c",(char)(v & 0xffLL));
							str = std::string(buf);
							gr->DrawString(gcnew String(str.c_str()),myfont,fgbr,xx,yy);
							system1.VideoMemDirty[ndx>>1] = false;
//						 }
					 }
				 }
				minx = 672;
				miny = 372;
				maxx = 0;
				maxy = 0;
				for (nn = 0; nn < 4096; nn++) {
					if (system1.VideoMemDirty[nn]) {
						xx = nn % 56;
						yy = nn / 56;
						maxx = max(xx,maxx);
						maxy = max(yy,maxy);
						minx = min(xx,minx);
						miny = min(yy,miny);
					}
				}
				ur.X = minx * 12;
				ur.Y = miny * 12;
				ur.Width = (maxx - minx) * 12;
				ur.Height = (maxy - miny) * 12;
				this->Invalidate(ur);
			 }
	private: System::Void timer1_Tick(System::Object^ sender, System::EventArgs^ e) {
		ur.X = 0;
		ur.Y = 0;
		ur.Width = 672;
		ur.Height = 372;
		this->Refresh();
	}
};
}
