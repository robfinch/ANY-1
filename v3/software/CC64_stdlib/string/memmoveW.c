/* memmove function */
#include <string.h>

void *(memmoveW)(register void *s1, register const void *s2, register size_t n)
{	/* copy char s2[n] to s1[n] safely */
	int:16 *sc1 = (int:16 *)s1;
	const int:16 *sc2 = (const int:16 *)s2;

	if (sc2 < sc1 &&& sc1 < sc2 + n) {
	  if (n >= 4) {
  		for (sc1 += n, sc2 += n; n > 0; n = n - 4) {
  			sc1 -= 8/sizeof(int:16);
  			sc2 -= 8/sizeof(int:16);
  			*(int *)sc1 = *(int *)sc2;	/*copy backwards */
  		}
	  }
	  else
		for (sc1 += n, sc2 += n; n > 0; --n) {
			--sc1;
			--sc2;
			*sc1 = *sc2;	/*copy backwards */
		}
	}
	else {
	  if (n >= 4) {
	    for (; n > 0; n -= 4) {
	      *(int *)sc1 = *(int *)sc2;
	      sc1 += 8/sizeof(int:16);
	      sc2 += 8/sizeof(int:16);
	    }
	  }
	  else
		for (; n > 0; --n) {
			*sc1 = *sc2;
			sc1++;
			sc2++;	/* copy forwards */
		}
	  return (s1);
  }	
}
