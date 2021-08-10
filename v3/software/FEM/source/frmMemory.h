#pragma once
#include "stdafx.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <string>

extern clsSystem system1;

namespace E64 {

	using namespace System;
	using namespace System::ComponentModel;
	using namespace System::Collections;
	using namespace System::Windows::Forms;
	using namespace System::Data;
	using namespace System::Drawing;
	using namespace System::Runtime::InteropServices;

	/// <summary>
	/// Summary for frmMemory
	/// </summary>
	public ref class frmMemory : public System::Windows::Forms::Form
	{
	public:
		frmMemory(void)
		{
			InitializeComponent();
			//
			//TODO: Add the constructor code here
			//
		}

	protected:
		/// <summary>
		/// Clean up any resources being used.
		/// </summary>
		~frmMemory()
		{
			if (components)
			{
				delete components;
			}
		}
	private: System::Windows::Forms::TextBox^  textBoxAddr;
	protected: 

	protected: 
	private: System::Windows::Forms::Label^  label1;
	private: System::Windows::Forms::TextBox^  textBoxMem;
	private: System::Windows::Forms::Button^ button1;

	private:
		/// <summary>
		/// Required designer variable.
		/// </summary>
		System::ComponentModel::Container ^components;

#pragma region Windows Form Designer generated code
		/// <summary>
		/// Required method for Designer support - do not modify
		/// the contents of this method with the code editor.
		/// </summary>
		void InitializeComponent(void)
		{
			this->textBoxAddr = (gcnew System::Windows::Forms::TextBox());
			this->label1 = (gcnew System::Windows::Forms::Label());
			this->textBoxMem = (gcnew System::Windows::Forms::TextBox());
			this->button1 = (gcnew System::Windows::Forms::Button());
			this->SuspendLayout();
			// 
			// textBoxAddr
			// 
			this->textBoxAddr->Location = System::Drawing::Point(75, 18);
			this->textBoxAddr->Name = L"textBoxAddr";
			this->textBoxAddr->Size = System::Drawing::Size(100, 20);
			this->textBoxAddr->TabIndex = 0;
			this->textBoxAddr->TextChanged += gcnew System::EventHandler(this, &frmMemory::textBox1_TextChanged);
			// 
			// label1
			// 
			this->label1->AutoSize = true;
			this->label1->Location = System::Drawing::Point(24, 21);
			this->label1->Name = L"label1";
			this->label1->Size = System::Drawing::Size(45, 13);
			this->label1->TabIndex = 1;
			this->label1->Text = L"Address";
			// 
			// textBoxMem
			// 
			this->textBoxMem->Font = (gcnew System::Drawing::Font(L"Lucida Console", 8.25F, System::Drawing::FontStyle::Regular, System::Drawing::GraphicsUnit::Point,
				static_cast<System::Byte>(0)));
			this->textBoxMem->Location = System::Drawing::Point(27, 44);
			this->textBoxMem->Multiline = true;
			this->textBoxMem->Name = L"textBoxMem";
			this->textBoxMem->ScrollBars = System::Windows::Forms::ScrollBars::Vertical;
			this->textBoxMem->Size = System::Drawing::Size(561, 353);
			this->textBoxMem->TabIndex = 2;
			// 
			// button1
			// 
			this->button1->Location = System::Drawing::Point(204, 15);
			this->button1->Name = L"button1";
			this->button1->Size = System::Drawing::Size(75, 23);
			this->button1->TabIndex = 3;
			this->button1->Text = L"Dump TLB";
			this->button1->UseVisualStyleBackColor = true;
			this->button1->Click += gcnew System::EventHandler(this, &frmMemory::button1_Click);
			// 
			// frmMemory
			// 
			this->AutoScaleDimensions = System::Drawing::SizeF(6, 13);
			this->AutoScaleMode = System::Windows::Forms::AutoScaleMode::Font;
			this->ClientSize = System::Drawing::Size(614, 409);
			this->Controls->Add(this->button1);
			this->Controls->Add(this->textBoxMem);
			this->Controls->Add(this->label1);
			this->Controls->Add(this->textBoxAddr);
			this->FormBorderStyle = System::Windows::Forms::FormBorderStyle::FixedDialog;
			this->Name = L"frmMemory";
			this->Text = L"FSIM Memory";
			this->ResumeLayout(false);
			this->PerformLayout();

		}
#pragma endregion
	private: System::Void textBox1_TextChanged(System::Object^  sender, System::EventArgs^  e) {
				 uint64_t nn;
        		char* str = (char*)(void*)Marshal::StringToHGlobalAnsi(this->textBoxAddr->Text);
				std::string str2;
				char buf[50];

				str2 = "";
				 for (nn = strtoull(str,NULL,16); nn < strtoull(str,NULL,16) + 512; nn++) {
					 if ((nn % 16LL)==0) {
						 sprintf(buf, "\r\n%06I64X ", nn);
						 str2 += buf;
					 }
					 sprintf(buf, "%02X ", (system1.Read(nn) >> ((nn & 3LL)<<3LL)) & 0xFFLL);
					 str2 += buf;
				 }
				 this->textBoxMem->Text = gcnew String(str2.c_str());
			 }
	private: System::Void button1_Click(System::Object^ sender, System::EventArgs^ e) {
		char buf[100];
		std::string str;
		int way;
		int entryno;

		str = "";
		for (way = 0; way < 4; way++) {
			sprintf_s(buf, sizeof(buf), "Way Entry ASID G D A U CRWX  VPN  PPN   \r\n");
			str += buf;
			str += "-----------------------------------------------\r\n";
			for (entryno = 0; entryno < 1024; entryno++) {
				sprintf_s(buf, sizeof(buf), " %d  %04d  %04X %c %c %c %c %c%c%c%c %04X %05X\r\n",
					way, entryno,
					cpu1.tlb.entries[way][entryno].ASID,
					cpu1.tlb.entries[way][entryno].G ? 'G' : ' ',
					cpu1.tlb.entries[way][entryno].D ? 'D' : ' ',
					cpu1.tlb.entries[way][entryno].A ? 'A' : ' ',
					cpu1.tlb.entries[way][entryno].U ? 'U' : ' ',
					cpu1.tlb.entries[way][entryno].C ? 'C' : ' ',
					cpu1.tlb.entries[way][entryno].R ? 'R' : ' ',
					cpu1.tlb.entries[way][entryno].W ? 'W' : ' ',
					cpu1.tlb.entries[way][entryno].X ? 'X' : ' ',
					cpu1.tlb.entries[way][entryno].vpn,
					cpu1.tlb.entries[way][entryno].ppn
				);
				str += buf;
			}
			str += "\r\n";
		}
		this->textBoxMem->Text = gcnew String(str.c_str());
	}
};
}
