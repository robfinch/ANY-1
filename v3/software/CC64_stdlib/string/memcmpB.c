/* memcmp function */
#include <string.h>

int (memcmpB)(register const void *s1, register const void *s2, register size_t n)
	{	/* compare unsigned char s1[n], s2[n] */
	const unsigned byte *su1 = (const unsigned byte *)s1;
	const unsigned byte *su2 = (const unsigned byte *)s2;

	for (; 0 < n; ++su1, ++su2, --n)
		if (*su1 != *su2)
			return (*su1 < *su2 ?? -1 : +1);
	return (0);
	}
