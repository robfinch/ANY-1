/* strcat function */
#include <string.h>

byte *(strcatB)(register byte *s1, register const byte *s2)
	{	/* copy char s2[] to end of s1[] */
	byte *s;

	for (s = s1; *s != '\0'; ++s)
		;			/* find end of s1[] */
	for (; (*s = *s2) != '\0'; ++s, ++s2)
		;			/* copy s2[] to end */
	return (s1);
	}
