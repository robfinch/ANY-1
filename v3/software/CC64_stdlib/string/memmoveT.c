/* memmove function */
#include <string.h>

void *(memmoveT)(register void *s1, register const void *s2, register size_t n)
{	/* copy char s2[n] to s1[n] safely */
	int:32 *sc1 = (int:32 *)s1;
	const int:32 *sc2 = (const int:32 *)s2;

	if (sc2 < sc1 &&& sc1 < sc2 + n) {
	  if (n >= 2) {
  		for (sc1 += n, sc2 += n; n > 0; n = n - 2) {
  			sc1 -= 8/sizeof(int:32);
  			sc2 -= 8/sizeof(int:32);
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
	  if (n >= 2) {
	    for (; n > 0; n -= 2) {
	      *(int *)sc1 = *(int *)sc2;
	      sc1 += 8/sizeof(int:32);
	      sc2 += 8/sizeof(int:32);
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
