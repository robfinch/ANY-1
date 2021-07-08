// ============================================================================
//        __
//   \\__/ o\    (C) 2012-2017  Robert Finch, Waterloo
//    \  __ /    All rights reserved.
//     \/_//     robfinch<remove>@finitron.ca
//       ||
//
// C64 - 'C' derived language compiler
//  - 64 bit CPU
//
// This source file is free software: you can redistribute it and/or modify 
// it under the terms of the GNU Lesser General Public License as published 
// by the Free Software Foundation, either version 3 of the License, or     
// (at your option) any later version.                                      
//                                                                          
// This source file is distributed in the hope that it will be useful,      
// but WITHOUT ANY WARRANTY; without even the implied warranty of           
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the            
// GNU General Public License for more details.                             
//                                                                          
// You should have received a copy of the GNU General Public License        
// along with this program.  If not, see <http://www.gnu.org/licenses/>.    
//                                                                          
// ============================================================================
//
#include "stdafx.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef __GNUC__
#include <io.h>
#endif

//#include <unistd.h>

/* ---------------------------------------------------------------------------
   void searchenv(filename, envname, pathname);
   char *filename;
   char *envname;
   char *pathname;

   Description :
      Search for a file by looking in the directories listed in the envname
   environment. Puts the full path name (if you find it) into pathname.
   Otherwise set *pathname to 0. Unlike the DOS PATH command (and the
   microsoft _searchenv), you can use either a space or a semicolon to
   separate directory names. The pathname array must be at least 128
   characters.

   Returns :
      nothing
--------------------------------------------------------------------------- */

void searchenv(char *filename, int fnsz, char *envname, char *pathname, int pthsz)
{
   static char pbuf[5000];
   char *p, *np;
   size_t len;
//   char *strpbrk(), *strtok(), *getenv();

   strcpy_s(pathname, pthsz, filename);
   if (_access(pathname, 0) != -1)
      return;

   /* ----------------------------------------------------------------------
         The file doesn't exist in the current directory. If a specific
      path was requested (ie. file contains \ or /) or if the environment
      isn't set, return a NULL, else search for the file on the path.
   ---------------------------------------------------------------------- */
   _dupenv_s(&p, &len, envname);
   if (len==0)
   {
      *pathname = '\0';
      return;
   }

   strncpy_s(pbuf, sizeof(pbuf), p, sizeof(pbuf));
   np = nullptr;
   if (p = strtok_s(pbuf, ";", &np))
   {
      do
      {
		  if (p[strlen(p)-1]=='\\')
	         sprintf_s(pathname, pthsz-1, "%0.90s%s", p, filename);
		  else
	         sprintf_s(pathname, pthsz, "%0.90s\\%s", p, filename);

         if (_access(pathname, 0) >= 0)
            return;
      }
      while(p = strtok_s(NULL, ";", &np));
   }
   *pathname = 0;
}
