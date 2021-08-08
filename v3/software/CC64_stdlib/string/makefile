# Makefile for STRING
#
PATH = $PATH;D:\cores2021\ANY1\v3\software\CC64\C64\debug\;D:\cores2021\ANY1\v3\software\AS64\A64\debug\;D:\cores2021\ANY1\v3\software\FPP\FPP\debug\;D:\cores2021\ANY1\v3\software\APP\debug\;"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.27.29110\bin\Hostx64\x64"
FPPINC = D:\cores2021\ANY1\v3\software\source\;D:\cores2021\ANY1\v3\software\FMTK\source\kernel\;D:\cores2021\ANY1\v3\software\inc
APPINC = D:\cores2021\ANY1\v3\software\source\;D:\cores2021\ANY1\v3\software\FMTK\source\kernel\;D:\cores2021\ANY1\v3\software\inc
INC = D:\cores2021\ANY1\v3\software\source\;D:\cores2021\ANY1\v3\software\FMTK\source\kernel\;D:\cores2021\ANY1\v3\software\inc
INCLUDE = D:\cores2021\ANY1\v3\software\source\;D:\cores2021\ANY1\v3\software\FMTK\source\kernel\;D:\cores2021\ANY1\v3\software\inc
CXX = cc64 -w -S
#CCX = cc64
CFLAGS = -w -S
ASMS = \
	memchr.s \
	memcmp.s \
	memcpy.s \
	memcpyB.s \
	memcpyW.s \
	memcpyT.s \
	memcpyO.s \
	memmove.s \
	memset.s \
	memsetB.s \
	memsetW.s \
	memsetT.s \
	memsetO.s \
	strcat.s \
	strcatB.s \
	strcatW.s \
	strcatT.s \
	strchr.s \
	strcmp.s \
	strcpy.s \
	strcspn.s \
	strerror.s \
	strlen.s \
	strncat.s \
	strncpy.s \
	strpbrk.s \
	strrchr.s \
	strspn.s \
	strstr.s \
	strtok.s \
	strxfrm.s \
	xstrxfrm.s

#	strcoll.s \

all:	$(ASMS)
	echo "made STRING"
           
STRING:	$(ASMS)
  copy *.r64 string.l64
	echo "made STRING"

.c.s:
	cc64 $(CFLAGS) $<

clean:
	del *.s
	del *.lis
	del *.c.xml
	del *.fpp
	del *.hir

