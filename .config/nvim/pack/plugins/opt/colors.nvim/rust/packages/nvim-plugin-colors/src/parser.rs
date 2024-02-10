use crate::ansi::XTERM_256;

use palette::convert::FromColor;
use palette::convert::FromColorUnclamped;
use palette::rgb::channels;
use palette::{Hsl, Hwb, Lab, Lch, LinSrgb, Oklab, Oklch, Srgb};

macro_rules! convert_rgb {
    ($rgb:expr) => {
        $rgb.into_u32::<channels::Rgba>() >> 8
    };
}

macro_rules! convert_lossy {
    ($color:expr) => {
        convert_rgb!(Srgb::<u8>::from_linear(LinSrgb::from_color_unclamped(
            $color
        )))
    };
}

macro_rules! convert_lossless {
    ($color:expr) => {
        convert_rgb!(Srgb::from_color($color).into_format::<u8>())
    };
}

type Result<T> = core::result::Result<(usize, T), ()>;

#[inline]
pub fn peek(input: &[u8], pos: usize) -> Option<u8> {
    input.get(pos).copied()
}

#[inline]
pub fn map<T, U>(lhs: Result<T>, f: impl FnOnce(T) -> U) -> Result<U> {
    lhs.map(|(pos, x)| (pos, f(x)))
}

fn space(input: &[u8], mut pos: usize) -> Result<()> {
    while let Some(b' ' | b'_') = peek(input, pos) {
        pos += 1;
    }
    Ok((pos, ()))
}

fn comma(input: &[u8], mut pos: usize) -> Result<()> {
    while let Some(b' ' | b',' | b'_') = peek(input, pos) {
        pos += 1;
    }
    Ok((pos, ()))
}

fn number(input: &[u8], pos: usize) -> Result<f32> {
    let (value, len) = fast_float::parse_partial::<f32, _>(&input[pos..]).or(Err(()))?;
    Ok((pos + len, value))
}

fn integer(input: &[u8], pos: usize) -> Result<u64> {
    if let Some(b'0'..=b'9') = peek(input, pos) {
        let mut pos = pos;
        let mut value = 0_u64;
        while let Some(digit @ b'0'..=b'9') = peek(input, pos) {
            pos += 1;
            value = value.checked_mul(10).ok_or(())? + (digit - b'0') as u64;
        }
        Ok((pos, value))
    } else {
        Err(())
    }
}

fn rparen(input: &[u8], mut pos: usize) -> Result<()> {
    loop {
        match peek(input, pos) {
            Some(b')') => return Ok((pos + 1, ())),
            Some(_) => pos += 1,
            None => return Err(()),
        }
    }
}

fn number_or_percentage(input: &[u8], pos: usize, hundred: f32) -> Result<f32> {
    let (pos, value) = number(input, pos)?;
    if peek(input, pos) == Some(b'%') {
        Ok((pos + 1, value * (hundred / 100.0)))
    } else {
        Ok((pos, value))
    }
}

fn percentage(input: &[u8], pos: usize, hundred: f32) -> Result<f32> {
    let (pos, value) = number(input, pos)?;
    if peek(input, pos) == Some(b'%') {
        Ok((pos + 1, value * (hundred / 100.0)))
    } else {
        Err(())
    }
}

fn angle(input: &[u8], pos: usize) -> Result<f32> {
    let (pos, value) = number(input, pos)?;
    match &input[pos..] {
        [b'g' | b'G', b'r' | b'R', b'a' | b'A', b'd' | b'D', ..] => {
            Ok((pos + 4, value * 360.0 / 400.0))
        }
        [b'r' | b'R', b'a' | b'A', b'd' | b'D', ..] => Ok((pos + 3, value.to_degrees())),
        [b't' | b'T', b'u' | b'U', b'r' | b'R', b'n' | b'N', ..] => Ok((pos + 4, value * 360.0)),
        [b'd' | b'D', b'e' | b'E', b'g' | b'G', ..] => Ok((pos + 3, value)),
        _ => Ok((pos, value)),
    }
}

fn css_fn<A, B, C>(
    input: &[u8],
    pos: usize,
    a: impl FnOnce(&[u8], usize) -> Result<A>,
    b: impl FnOnce(&[u8], usize) -> Result<B>,
    c: impl FnOnce(&[u8], usize) -> Result<C>,
) -> Result<(A, B, C)> {
    let (pos, _) = space(input, pos)?;
    let (pos, a) = a(input, pos)?;
    let (pos, _) = comma(input, pos)?;
    let (pos, b) = b(input, pos)?;
    let (pos, _) = comma(input, pos)?;
    let (pos, c) = c(input, pos)?;
    let (pos, _) = rparen(input, pos)?;
    Ok((pos, (a, b, c)))
}

pub fn css_rgb_fn(input: &[u8], pos: usize) -> Result<u32> {
    fn component(input: &[u8], pos: usize) -> Result<f32> {
        map(number_or_percentage(input, pos, 255.0), |x| x / 255.0)
    }

    let (pos, (r, g, b)) = css_fn(input, pos, component, component, component)?;
    let color = Srgb::new(r, g, b).into_format::<u8>();
    Ok((pos, convert_rgb!(color)))
}

pub fn css_hsl_fn(input: &[u8], pos: usize) -> Result<u32> {
    fn coord(input: &[u8], pos: usize) -> Result<f32> {
        map(percentage(input, pos, 1.0), |x| x.clamp(0.0, 1.0))
    }

    let (pos, (h, s, l)) = css_fn(input, pos, angle, coord, coord)?;
    let color = Hsl::new(h, s, l);
    Ok((pos, convert_lossless!(color)))
}

pub fn css_hwb_fn(input: &[u8], pos: usize) -> Result<u32> {
    fn coord(input: &[u8], pos: usize) -> Result<f32> {
        percentage(input, pos, 100.0)
    }

    let (pos, (h, w, b)) = css_fn(input, pos, angle, coord, coord)?;
    let color = Hwb::new(h, w, b);
    Ok((pos, convert_lossless!(color)))
}

pub fn css_lab_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (l, a, b)) = css_fn(
        input,
        pos,
        |input, pos| number_or_percentage(input, pos, 100.0),
        |input, pos| number_or_percentage(input, pos, 125.0),
        |input, pos| number_or_percentage(input, pos, 125.0),
    )?;
    let color = Lab::new(l, a, b);
    Ok((pos, convert_lossy!(color)))
}

pub fn css_lch_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (l, c, h)) = css_fn(
        input,
        pos,
        |input, pos| number_or_percentage(input, pos, 100.0),
        |input, pos| number_or_percentage(input, pos, 150.0),
        angle,
    )?;
    let color = Lch::new(l, c, h);
    Ok((pos, convert_lossy!(color)))
}

pub fn css_oklab_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (l, a, b)) = css_fn(
        input,
        pos,
        |input, pos| number_or_percentage(input, pos, 1.0),
        |input, pos| number_or_percentage(input, pos, 0.4),
        |input, pos| number_or_percentage(input, pos, 0.4),
    )?;
    let color = Oklab::new(l, a, b);
    Ok((pos, convert_lossy!(color)))
}

pub fn css_oklch_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (l, c, h)) = css_fn(
        input,
        pos,
        |input, pos| number_or_percentage(input, pos, 1.0),
        |input, pos| number_or_percentage(input, pos, 0.4),
        angle,
    )?;
    let color = Oklch::new(l, c, h);
    Ok((pos, convert_lossy!(color)))
}

#[inline]
unsafe fn hex1_unchecked(input: u8) -> u8 {
    if input <= b'9' {
        input - b'0'
    } else {
        (input | 0x20) - b'a' + 10
    }
}

pub unsafe fn css_hex6_unchecked(input: &[u8], pos: usize) -> (usize, u32) {
    #[inline]
    unsafe fn component(input: &[u8], pos: usize) -> u8 {
        (hex1_unchecked(*input.get_unchecked(pos)) << 4)
            | (hex1_unchecked(*input.get_unchecked(pos + 1)))
    }

    let color = Srgb::<u8>::new(
        component(input, pos),
        component(input, pos + 2),
        component(input, pos + 4),
    );
    (pos + 6, convert_rgb!(color))
}

pub unsafe fn css_hex3_unchecked(input: &[u8], pos: usize) -> (usize, u32) {
    #[inline]
    unsafe fn component(input: &[u8], pos: usize) -> u8 {
        let x = hex1_unchecked(*input.get_unchecked(pos));
        (x << 4) | x
    }

    let color = Srgb::<u8>::new(
        component(input, pos),
        component(input, pos + 1),
        component(input, pos + 2),
    );
    (pos + 3, convert_rgb!(color))
}

pub fn xterm256(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, value) = integer(input, pos)?;
    match XTERM_256.get(value as usize) {
        Some(color) => Ok((pos, convert_rgb!(Srgb::<u8>::from(*color)))),
        None => Err(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[track_caller]
    fn parse<T>(f: impl FnOnce(&[u8], usize) -> Result<T>, input: &str, expected: Option<T>)
    where
        T: std::fmt::Debug + PartialEq,
    {
        let actual = f(input.as_bytes(), 0);
        let expected = match expected {
            Some(color) => Ok((input.len(), color)),
            None => Err(()),
        };
        assert_eq!(actual, expected);
    }

    #[test]
    fn parse_space() {
        parse(space, "", Some(()));
        parse(space, " ", Some(()));
        parse(space, "_", Some(()));
        parse(space, " _ _", Some(()));
    }

    #[test]
    fn parse_comma() {
        parse(comma, "", Some(()));
        parse(comma, ",", Some(()));
        parse(comma, ",,", Some(()));
        parse(comma, " _, ,_ ", Some(()));
    }

    #[test]
    fn parse_number() {
        parse(number, "0", Some(0.0));

        parse(number, "1", Some(1.0));
        parse(number, ".5", Some(0.5));
        parse(number, "123", Some(123.0));

        parse(number, "-1", Some(-1.0));
        parse(number, "-.5", Some(-0.5));
        parse(number, "-123", Some(-123.0));

        parse(number, "10.01", Some(10.01));
        parse(number, "10e3", Some(10000.0));

        assert_eq!(number(b"10,", 0), Ok((2, 10.0)));

        parse(number, "", None);
    }

    #[test]
    fn parse_integer() {
        parse(integer, "0", Some(0));
        parse(integer, "1", Some(1));
        parse(integer, "12", Some(12));
        parse(integer, "123", Some(123));
        parse(integer, "1234", Some(1234));

        parse(integer, "", None);
        parse(integer, "-1", None);
        parse(integer, &"9".repeat(100), None);
    }

    #[test]
    fn parse_rparen() {
        parse(rparen, "X(;\n)", Some(()));

        parse(rparen, "", None);
    }

    #[test]
    fn parse_number_or_percentage() {
        assert_eq!(number_or_percentage(b"100", 0, 100.0), Ok((3, 100.0)));
        assert_eq!(number_or_percentage(b"100%", 0, 100.0), Ok((4, 100.0)));
        assert_eq!(number_or_percentage(b"100%", 0, 1.0), Ok((4, 1.0)));
        assert_eq!(number_or_percentage(b"1%", 0, 1000.0), Ok((2, 10.0)));
        assert_eq!(number_or_percentage(b"0.1%", 0, 1000.0), Ok((4, 1.0)));

        assert_eq!(number_or_percentage(b"", 0, 1.0), Err(()));
    }

    #[test]
    fn parse_percentage() {
        assert_eq!(percentage(b"100%", 0, 100.0), Ok((4, 100.0)));
        assert_eq!(percentage(b"100%", 0, 1.0), Ok((4, 1.0)));
        assert_eq!(percentage(b"1%", 0, 1000.0), Ok((2, 10.0)));
        assert_eq!(percentage(b"0.1%", 0, 1000.0), Ok((4, 1.0)));

        assert_eq!(percentage(b"", 0, 1.0), Err(()));
    }

    #[test]
    fn parse_angle_grad() {
        parse(angle, "400grad", Some(360.0));
        parse(angle, "800.0GRAD", Some(720.0));
    }

    #[test]
    fn parse_angle_rad() {
        parse(angle, "2rad", Some(2_f32.to_degrees()));
        parse(angle, ".5RAD", Some(0.5_f32.to_degrees()));
    }

    #[test]
    fn parse_angle_turn() {
        parse(angle, "2turn", Some(720.0));
        parse(angle, ".5TURN", Some(180.0));
    }

    #[test]
    fn parse_angle_deg() {
        parse(angle, "2deg", Some(2.0));
        parse(angle, ".5DEG", Some(0.5));

        parse(angle, "DEG", None);
    }

    #[test]
    fn parse_angle_unitless() {
        parse(angle, "1.5", Some(1.5));

        parse(angle, "", None);
    }

    #[test]
    fn parse_css_rgb_fn() {
        parse(css_rgb_fn, "1 2 3)", Some(0x010203));
        parse(css_rgb_fn, "1 2 3)", Some(0x010203));
        parse(css_rgb_fn, "1,2,3)", Some(0x010203));
        parse(css_rgb_fn, "1_2_3)", Some(0x010203));
        parse(css_rgb_fn, "1 , 2_,_3)", Some(0x010203));
        parse(css_rgb_fn, " 1 2 3)", Some(0x010203));
        parse(css_rgb_fn, "_1_2_3)", Some(0x010203));
        parse(css_rgb_fn, "1 2 3 junk)", Some(0x010203));
        parse(css_rgb_fn, "1.5 2.5 3.5)", Some(0x020204));
        parse(css_rgb_fn, "100% 50% 0%)", Some(0xff8000));

        parse(css_rgb_fn, "256 0 0)", Some(0xff0000));
        parse(css_rgb_fn, "-0.001 0 0)", Some(0x000000));

        parse(css_rgb_fn, "", None);
        parse(css_rgb_fn, "1 2 junk 3)", None);
        parse(css_rgb_fn, "1 2)", None);
        parse(css_rgb_fn, "1 2 3", None);
    }

    #[test]
    fn parse_xterm256() {
        parse(xterm256, "0", Some(0));
        parse(xterm256, "15", Some(0xffffff));
        parse(xterm256, "255", Some(0xeeeeee));

        parse(xterm256, "256", None);
    }

    #[test]
    fn parse_css_hex6() {
        unsafe {
            assert_eq!(css_hex6_unchecked(b"#00aAAa", 1), (7, 0x00aaaa));
            assert_eq!(css_hex6_unchecked(b"#99FffF", 1), (7, 0x99ffff));
        }
    }

    #[test]
    fn parse_css_hex3() {
        unsafe {
            assert_eq!(css_hex3_unchecked(b"#0aA", 1), (4, 0x00aaaa));
            assert_eq!(css_hex3_unchecked(b"#9Ff", 1), (4, 0x99ffff));
        }
    }
}
