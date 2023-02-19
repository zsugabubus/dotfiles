# vim:set ft=c
return [=[
/*
 * Stolen from:
 * https://ninedegreesbelow.com/photography/xyz-rgb.html
 * https://www.w3.org/TR/css-color-4/#color-conversion-code
 * https://css.land/lch/
 */

#define DEFINE_COLOR3(name, a, b, c) \
	struct name { \
		union { \
			struct { \
				float a, b, c; \
			}; \
			float u[3]; \
		}; \
	};

DEFINE_COLOR3(lab, l, a, b)
DEFINE_COLOR3(lch, l, c, h)
DEFINE_COLOR3(hsl, h, s, l)
DEFINE_COLOR3(hwb, h, w, b)
DEFINE_COLOR3(xyz, x, y, z)
DEFINE_COLOR3(rgb, r, g, b)

static void
lch_to_lab(struct lch const *lch, struct lab *lab)
{
	lab->l = lch->l;
	lab->a = lch->c * cosf(lch->h * (float)M_PI / 180);
	lab->b = lch->c * sinf(lch->h * (float)M_PI / 180);
}

static uint8_t
hex_from_digit(uint8_t c)
{
	return (uint8_t)((c | 0x20) - (c <= '9' ? '0' : 'a' - 10));
}

static uint8_t
hex1_to_rgb24_c(uint8_t c)
{
	uint8_t x = hex_from_digit(c);
	return (x << 4) | x;
}

static uint8_t
hex2_to_rgb24_c(char const *s)
{
	return (
		(hex_from_digit(((uint8_t *)s)[0]) << 4) |
		hex_from_digit(((uint8_t *)s)[1])
	);
}

static void
hex3_to_rgb24(char const *s, struct rgb24 *rgb)
{
	rgb->r = hex1_to_rgb24_c(((uint8_t *)s)[0]);
	rgb->g = hex1_to_rgb24_c(((uint8_t *)s)[1]);
	rgb->b = hex1_to_rgb24_c(((uint8_t *)s)[2]);
}

static void
hex6_to_rgb24(char const *s, struct rgb24 *rgb)
{
	rgb->r = hex2_to_rgb24_c(s + 0);
	rgb->g = hex2_to_rgb24_c(s + 2);
	rgb->b = hex2_to_rgb24_c(s + 4);
}

static void
rgb24_from_u32(struct rgb24 *rgb, uint32_t x)
{
	rgb->r = (uint8_t)(x >> 24);
	rgb->g = (uint8_t)(x >> 16);
	rgb->b = (uint8_t)(x >> 8);
}

static int
try_parse_rgb_c(char const **p, float *c)
{
	char *end;
	*c = strtof(*p, &end);
	if (*p == end)
		return 0;
	*p = end;

	if (**p == '%') {
		*p += 1;
		*c /= 100;
	} else {
		*c /= 255;
	}

	if (!(0 <= *c && *c <= 1))
		return 0;

	return 1;
}

static int
try_parse_hsl_h(char const **p, float *h)
{
	char *end;
	*h = strtof(*p, &end);
	if (*p == end)
		return 0;
	*p = end;

	if (!strncasecmp(*p, "deg", 3)) {
		*p += 3;
	} else if (!strncasecmp(*p, "grad", 4)) {
		*p += 4;
		*h = *h * 360 / 400;
	} else if (!strncasecmp(*p, "rad", 3)) {
		*p += 3;
		*h = *h * 180 / (float)M_PI;
	} else if (!strncasecmp(*p, "turn", 4)) {
		*p += 4;
		*h = *h * 360;
	}

	return 1;
}

static float
fclampf(float x, float min, float max)
{
	return fminf(fmaxf(x, min), max);
}

static int
try_parse_percent(char const **p, float *x, float one)
{
	char *end;
	*x = strtof(*p, &end);
	if (*p == end)
		return 0;
	*p = end;

	if (**p == '%') {
		*p += 1;
		*x = *x * one / 100;
	} else {
		return 0;
	}

	return 1;
}

static int
try_parse_percent_or_number(char const **p, float *x, float one)
{
	char *end;
	*x = strtof(*p, &end);
	if (*p == end)
		return 0;
	*p = end;

	if (**p == '%') {
		*p += 1;
		*x = *x * one / 100;
	}

	return 1;
}

static int
try_parse_lightness(char const **p, float *l)
{
	if (!try_parse_percent_or_number(p, l, 100))
		return 0;
	*l = fclampf(*l, 0, 100);
	return 1;
}

static void
parse_fn_end(char const **p)
{
	*p += strcspn(*p, ")");
}

static void
hsl_to_srgb(struct hsl const *hsl, struct rgb *rgb)
{
	float h = hsl->h;
	if (h < 0)
		h = fmodf(h, 360) + 360;

	float a = hsl->s * fminf(hsl->l, 1 - hsl->l);

#define xmacro(c, n) do { \
	float k = fmodf(n + h / 30, 12.0); \
	rgb->c = hsl->l - a * fmaxf(-1, fminf(k - 3, fminf(9 - k, 1))); \
} while (0)

	xmacro(r, 0);
	xmacro(g, 8);
	xmacro(b, 4);

#undef xmacro
}

static void
rgb_to_rgb24(struct rgb const *s, struct rgb24 *d)
{
	d->r = (uint8_t)(s->r * 255);
	d->g = (uint8_t)(s->g * 255);
	d->b = (uint8_t)(s->b * 255);
}

static void
rgb24_to_rgb(struct rgb24 const *s, struct rgb *d)
{
	d->r = (float)s->r / 255.0f;
	d->g = (float)s->g / 255.0f;
	d->b = (float)s->b / 255.0f;
}

static void
srgb_to_lin(struct rgb const *srgb, struct rgb *slin)
{
#define xmacro(c) do { \
	if (srgb->c <= 0.04045f) \
		slin->c = srgb->c / 12.92f; \
	else \
		slin->c = powf((srgb->c + 0.055f) / 1.055f, 2.4f); \
} while (0)
	xmacro(r);
	xmacro(g);
	xmacro(b);
#undef xmacro
}

static void
mat33_mul_v(float out[3], float const M[3][3], float const v[3])
{
#define row(i) out[i] = ( \
	M[i][0] * v[0] + \
	M[i][1] * v[1] + \
	M[i][2] * v[2] \
)
	row(0);
	row(1);
	row(2);
#undef row
}

/* Linear sRGB to XYZ (D65). */
static void
lin_srgb_to_xyz(struct rgb const *rgb, struct xyz *xyz)
{
	/* https://www.avsforum.com/threads/ground-truth-re-bt-709-rgb-cie-xyz.1115923/ */
	static float const M[3][3] = {
		{ 506752.0f / 1228815.0f, 87881.0f  / 245763.0f, 12673.0f   / 70218.0f },
		{ 87098.0f  / 409605.0f,  175762.0f / 245763.0f, 12673.0f   / 175545.0f },
		{ 7918.0f   / 409605.0f,  87881.0f  / 737289.0f, 1001167.0f / 1053270.0f },
	};
	mat33_mul_v(xyz->u, M, rgb->u);
}

static float const D50[] = {
	0.3457f / 0.3585f,
	1.0f,
	(1.0f - 0.3457f - 0.3585f) / 0.3585f,
};

static float const D65[] = {
	0.3127f / 0.3290f,
	1.0f,
	(1.0f - 0.3127f - 0.3290f) / 0.3290f,
};

static void
xyz_to_lab(struct xyz const *xyz, float const D[3], struct lab *lab)
{
	float const d = 6.0f / 29.0f;
	float const e = 216.0f / 24389.0f; /* (6/29)^3 */

	float x = xyz->x / D[0];
	float y = xyz->y;
	float z = xyz->z / D[2];

#define f(t) (t > e ? cbrtf(t) : t / (3 * d * d) + 4.0f / 29.0f)
	float fx = f(x);
	float fy = f(y);
	float fz = f(z);
	lab->l = 116 * fy - 16;
	lab->a = 500.0f * (fx - fy);
	lab->b = 200.0f * (fy - fz);
#undef f
}

static void
lab_to_xyz(struct lab const *lab, struct xyz *xyz, float const D[3])
{
	float const k = 24389.0f / 27.0f;  /* (29/3)^3 */
	float const e = 216.0f / 24389.0f; /* (6/29)^3 */

	float fy = (lab->l + 16) / 116;
	float fx = fy + lab->a / 500;
	float fz = fy - lab->b / 200;

	float x = powf(fx, 3) > e ? powf(fx, 3) : (116 * fx - 16) / k;
	float y = lab->l > k * e ? powf(fy, 3) : lab->l / k;
	float z = powf(fz, 3) > e ? powf(fz, 3) : (116 * fz - 16) / k;

	xyz->x = x * D[0];
	xyz->y = y;
	xyz->z = z * D[2];
}

static void
srgb_to_xyz(struct rgb const *srgb, struct xyz *xyz)
{
	struct rgb slin;
	srgb_to_lin(srgb, &slin);
	lin_srgb_to_xyz(&slin, xyz);
}

static void
srgb_apply_gamma(struct rgb const *lin, struct rgb *rgb)
{
#define xmacro(c) do { \
	float c_abs = fabsf(lin->c); \
	if (c_abs > 0.0031308f) \
		rgb->c = (lin->c < 0 ? -1.0f : 1.0f) * (1.055f * powf(c_abs, 1.0f / 2.4f) - 0.055f); \
	else \
		rgb->c = 12.92f * lin->c; \
} while (0)

	xmacro(r);
	xmacro(g);
	xmacro(b);

#undef xmacro
}

static void
srgb_to_lab(struct rgb const *srgb, struct lab *lab)
{
	struct xyz xyz;
	srgb_to_xyz(srgb, &xyz);
	xyz_to_lab(&xyz, D65, lab);
}

int
rgb24_is_bright(struct rgb24 const *rgb24)
{
	struct rgb rgb;
	rgb24_to_rgb(rgb24, &rgb);
	struct lab lab;
	srgb_to_lab(&rgb, &lab);
	return lab.l >= 50.0f;
}

static void
hwb_to_srgb(struct hwb const *hwb, struct rgb *rgb) {
	float wb = hwb->w + hwb->b;
	if (wb >= 1) {
		float c = hwb->w / wb;
		rgb->r = rgb->g = rgb->b = c;
	} else {
		struct hsl hsl;
		hsl.h = hwb->h;
		hsl.s = 1;
		hsl.l = .5;
		hsl_to_srgb(&hsl, rgb);
		rgb->r = rgb->r * (1 - wb) + hwb->w;
		rgb->g = rgb->g * (1 - wb) + hwb->w;
		rgb->b = rgb->b * (1 - wb) + hwb->w;
	}
}

/* XYZ (D65) to linear sRGB. */
static void
xyz_to_lin_srgb(struct xyz const *xyz, struct rgb *rgb)
{
	static float const M[3][3] = {
		{   12831.0f /   3959,    -329.0f /    214, -1974.0f /   3959 },
		{ -851781.0f / 878810, 1648619.0f / 878810, 36519.0f / 878810 },
		{     705.0f /  12673,   -2585.0f /  12673,   705.0f /    667 },
	};
	mat33_mul_v(rgb->u, M, xyz->u);
}

/* Chromatic adaptation. */
static void
xyz_d50_to_d65(struct xyz const *s, struct xyz *d)
{
	struct xyz tmp;
	tmp.x =  0.9554734527042182f   * s->x + -0.023098536874261423f * s->y + 0.0632593086610217f   * s->z;
	tmp.y = -0.028369706963208136f * s->x +  1.0099954580058226f   * s->y + 0.021041398966943008f * s->z;
	tmp.z =  0.012314001688319899f * s->x + -0.020507696433477912f * s->y + 1.3303659366080753f   * s->z;
	*d = tmp;
}

static void
lab_to_srgb(struct lab const *lab, struct rgb *rgb)
{
	struct xyz xyz;
	lab_to_xyz(lab, &xyz, D50);
	/* sRGB expects D65. */
	xyz_d50_to_d65(&xyz, &xyz);
	struct rgb slin;
	xyz_to_lin_srgb(&xyz, &slin);
	srgb_apply_gamma(&slin, rgb);
}

static int
srgb_in_gamut(struct rgb const *rgb)
{
	return (
		(0 <= rgb->r && rgb->r <= 1) &&
		(0 <= rgb->g && rgb->g <= 1) &&
		(0 <= rgb->b && rgb->b <= 1)
	);
}

static void
lch_to_srgb(struct lch const *lch, struct rgb *rgb)
{
	struct lab lab;
	lch_to_lab(lch, &lab);
	lab_to_srgb(&lab, rgb);
}

static void
lab_to_lch(struct lab const *lab, struct lch *lch)
{
	lch->l = lab->l;
	lch->c = sqrtf(lab->a * lab->a + lab->b * lab->b);
	float h = atan2f(lab->b, lab->a) * 180 / (float)M_PI;
	lch->h = h >= 0 ? h : h + 360;
}

static void
lch_to_rgb24_lossy(struct lch const *lch, struct rgb24 *rgb24)
{
	struct rgb rgb;
	lch_to_srgb(lch, &rgb);
	if (srgb_in_gamut(&rgb)) {
		rgb_to_rgb24(&rgb, rgb24);
		return;
	}

	struct lch cur;
	cur.l = lch->l;
	cur.h = lch->h;

	struct rgb last;
	memset(&last, 0, sizeof last);

	float lo = 0, hi = lch->c;
	for (; hi - lo > 0.1;) {
		cur.c = (lo + hi) / 2;
		lch_to_srgb(&cur, &rgb);
		if (srgb_in_gamut(&rgb)) {
			lo = cur.c;
			rgb_to_rgb24(&rgb, rgb24);
			if (!memcmp(&last, rgb24, sizeof last))
				return;
			memcpy(&last, rgb24, sizeof last);
		} else {
			hi = cur.c;
		}
	}
	cur.c = lo;
	lch_to_srgb(&cur, &rgb);
	rgb_to_rgb24(&rgb, rgb24);
	assert(srgb_in_gamut(&rgb));
}

static void
tcolor_to_rgb24(uint8_t tc, struct rgb24 *rgb)
{
	if (tc < 16) {
		/* User palette */
		if (tc == 7) {
			rgb->r = rgb->g = rgb->b = 0xc0;
		} else if (tc == 8) {
			rgb->r = rgb->g = rgb->b = 0x80;
		} else {
			uint8_t c = tc < 8 ? 0x80 : 0xff;
			rgb->r = tc & 0x1 ? c : 0;
			rgb->g = tc & 0x2 ? c : 0;
			rgb->b = tc & 0x4 ? c : 0;
		}
	} else if (tc < 16 + 6 * 6 * 6) {
		/* Cube colors */
		tc -= 16;
#define x(i) ((i == 0 ? 0 : 0x37L + 0x28 * i) << (i * 8)) |
		static uint64_t const CUBE = x(0)x(1)x(2)x(3)x(4)x(5)0;
#undef x
		rgb->r = (uint8_t)(CUBE >> (tc / 36) % 6);
		rgb->g = (uint8_t)(CUBE >> (tc / 6) % 6);
		rgb->b = (uint8_t)(CUBE >> tc % 6);
	} else {
		/* Grey scale. */
		tc -= 16 + 6 * 6 * 6;
		rgb->r = rgb->g = rgb->b = (uint8_t)(0x08 + 0x0a * tc);
	}
}

size_t
match(char const *sbj, size_t len, struct highlight *hls, size_t nhls)
{
	size_t ret = 0;
	size_t from = 0;
	uint16_t accept = 0;
	size_t backtrack = 1;
	uint16_t state = S;

	/* Allow equality to read terminating NUL. */
	for (size_t i = 0; i <= len;) {
		state = TRANSITIONS[state * K + CHARMAP[((uint8_t *)sbj)[i]]];
		if (ACCEPTS[state]) {
			accept = state;
			backtrack = i + 1;
		}
		if (state) {
			++i;
			continue;
		}

		if (accept) {
			struct highlight *hl = &hls[ret];
			hl->first = from;
			hl->last = backtrack;
			uint32_t arg = ACCEPTS[accept];
			accept = 0;
			char const *p = sbj + backtrack;
			uint8_t ty = (uint8_t)arg;
			switch (ty) {
			case T_NAMED:
				rgb24_from_u32(&hl->color, arg);
				break;

			case T_RRGGBB:
				p -= 6 + ((arg >> 8) & 0xff);
				hex6_to_rgb24(p, &hl->color);
				break;

			case T_RGB:
				p -= 3 + ((arg >> 8) & 0xff);
				hex3_to_rgb24(p, &hl->color);
				break;

			case T_RGB_FN:
			{
				struct rgb rgb;
				if (!try_parse_rgb_c(&p, &rgb.r))
					goto invalid;
				p += strspn(p, ", ");
				if (!try_parse_rgb_c(&p, &rgb.g))
					goto invalid;
				p += strspn(p, ", ");
				if (!try_parse_rgb_c(&p, &rgb.b))
					goto invalid;
				parse_fn_end(&p);
				rgb_to_rgb24(&rgb, &hl->color);
				hl->last = (size_t)(p + 1 - sbj);
			}
				break;

			case T_HSL_FN:
			case T_HWB_FN:
			{
				struct hsl hsl;
				if (!try_parse_hsl_h(&p, &hsl.h))
					goto invalid;
				p += strspn(p, ", ");
				if (!try_parse_percent(&p, &hsl.s, 1))
					goto invalid;
				hsl.s = fclampf(hsl.s, 0, 1);
				p += strspn(p, ", ");
				if (!try_parse_percent(&p, &hsl.l, 1))
					goto invalid;
				hsl.l = fclampf(hsl.l, 0, 1);
				parse_fn_end(&p);

				struct rgb rgb;
				if (ty == T_HWB_FN) {
					struct hwb hwb = {
						.h = hsl.h,
						.w = hsl.s,
						.b = hsl.l,
					};
					hwb_to_srgb(&hwb, &rgb);
				} else {
					hsl_to_srgb(&hsl, &rgb);
				}

				rgb_to_rgb24(&rgb, &hl->color);
				hl->last = (size_t)(p + 1 - sbj);
			}
				break;

			case T_LAB_FN:
			{
				struct lab lab;
				if (!try_parse_lightness(&p, &lab.l))
					goto invalid;
				if (!try_parse_percent_or_number(&p, &lab.a, 125))
					goto invalid;
				if (!try_parse_percent_or_number(&p, &lab.b, 125))
					goto invalid;
				parse_fn_end(&p);
				struct lch lch;
				lab_to_lch(&lab, &lch);
				lch_to_rgb24_lossy(&lch, &hl->color);
				hl->last = (size_t)(p + 1 - sbj);
			}
				break;

			case T_LCH_FN:
			{
				struct lch lch;
				if (!try_parse_lightness(&p, &lch.l))
					goto invalid;
				if (!try_parse_percent_or_number(&p, &lch.c, 150))
					goto invalid;
				if (!try_parse_hsl_h(&p, &lch.h))
					goto invalid;
				parse_fn_end(&p);
				lch_to_rgb24_lossy(&lch, &hl->color);
				hl->last = (size_t)(p + 1 - sbj);
			}
				break;

			case T_SGR_256:
				hl->first += 1;
				backtrack -= 1;
				/* FALLTHROUGH */
			case T_COLOR:
			{
				p -= 1 /* [0-9] */;
				char *end;
				unsigned long n = strtoul(p, &end, 10);
				if (256 <= n)
					goto invalid;
				tcolor_to_rgb24((uint8_t)n, &hl->color);
				hl->last = (size_t)(end - sbj);
			}
				break;

			case T_SGR_8:
			case T_SGR_BRIGHT_8:
				tcolor_to_rgb24((uint8_t)(p[-2] - '0' + (T_SGR_BRIGHT_8 == ty ? 8 : 0)), &hl->color);
				hl->first += 1;
				hl->last -= 1;
				backtrack -= 1;
				break;

			case T_SGR_RGB:
			{
				hl->first += 1;
				p -= 1;
				struct rgb24 rgb;
				char *end;
				rgb.r = (uint8_t)strtoul(p, &end, 10);
				if (';' != *end)
					goto invalid;
				p = end + 1;
				rgb.g = (uint8_t)strtoul(p, &end, 10);
				if (';' != *end)
					goto invalid;
				p = end + 1;
				rgb.b = (uint8_t)strtoul(p, &end, 10);
				if (';' != *end && 'm' != *end)
					goto invalid;
				p = end;
				hl->color = rgb;
				hl->last = (size_t)(p - sbj);
				backtrack = hl->last;
			}
				break;

			default:
				abort();
			}
			ret += 1;
			if (nhls <= ret)
				break;
		invalid:;
		}

		/* TODO: It is not very efficient because it means that every
		position is examined multiple times. Backtracking information could be
		precomputed (like it was in case of the Lua matcher). It can easily mean a
		2x speedup. */
		i = backtrack;
		backtrack = i + 1;
		from = i;
	}

	return ret;
}
]=]
