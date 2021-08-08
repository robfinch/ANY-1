/* strlen function */
#include <string.h>

size_t (strlen)(const char *s)
{	// find length of s[]
  int n, k;
  
  for (n = -1, k = 0; n < 0; k += 8, s += 4)
    n = __wydendx(*(int *)s,0);
  k += n;
  return (k);  
/*
	__asm {
		push		$t1
		push		$t0
		ldi			$t0,#0					; $t0 = memory offset / length
		ldo			$t1,24[$sp]			; $t1 = char pointer
		ldo			$a0,[$t1]				; fetch first word
.0002:
		wydndx.	$a1,$a0,$x0			; get index of null char
		bge			.found
		add			$t0,$t0,#8			; increment memory offset
		ldo			$a0,[$t1+$t0]		; fetch another strip of characters
		bra			.0002
.found:
		lsr			$t0,$t0,#1			; adjust for 16 bits per char
		add			$a0,$t0,$a1			; add the wyde index
		ldo			$t0,[$sp]
		ldo			$t1,8[$sp]
		rts			#24							; 2 temps + arg
	}
*/
}
