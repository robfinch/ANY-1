/* strcat function */
#include <string.h>

char *(strcat)(register char *s1, register const char *s2)
	{	/* copy char s2[] to end of s1[] */
	char *s;

	for (s = s1; *s != '\0'; ++s)
		;			/* find end of s1[] */
	for (; (*s = *s2) != '\0'; ++s, ++s2)
		;			/* copy s2[] to end */
	return (s1);
	}
