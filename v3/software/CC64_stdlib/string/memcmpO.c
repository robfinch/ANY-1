/* memcmp function */
#include <string.h>

int (memcmpO)(register const void *s1, register const void *s2, register size_t n)
	{	/* compare unsigned char s1[n], s2[n] */
	const unsigned int:64 *su1 = (const unsigned int:64 *)s1;
	const unsigned int:64 *su2 = (const unsigned int:64 *)s2;

	for (; n > 0; ++su1, ++su2, --n)
		if (*su1 != *su2)
			return (*su1 < *su2 ?? -1 : +1);
	return (0);
	}
