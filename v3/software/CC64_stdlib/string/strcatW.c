/* strcatT function */
#include <string.h>

int:16 *(strcatW)(register int:16 *s1, register const int:16 *s2)
	{	/* copy char s2[] to end of s1[] */
	int:16 *s;

	for (s = s1; *s != '\0'; ++s)
		;			/* find end of s1[] */
	for (; (*s = *s2) != '\0'; ++s, ++s2)
		;			/* copy s2[] to end */
	return (s1);
	}
