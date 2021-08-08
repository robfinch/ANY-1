/* memset function */
#include <string.h>

void *(memset)(register void *s, register int c, register size_t n)
	{	/* store c throughout unsigned char s[n] */
	const unsigned __int8 uc = c;
	unsigned __int8 *su = (unsigned __int8 *)s;

	for (; n > 0; ++su, --n)
		*su = uc;
	return (s);
	}
