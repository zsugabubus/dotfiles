use crate::ansi::XTERM_256;

use palette::convert::FromColor;
use palette::convert::FromColorUnclamped;
use palette::rgb::channels;
use palette::{Hsl, Hwb, Lab, Lch, LinSrgb, Oklab, Oklch, Srgb};

macro_rules! color_to_u32 {
    (
        $color:expr
    ) => {
        Srgb::<u8>::from_linear(LinSrgb::from_color_unclamped($color)).into_u32::<channels::Rgba>()
            >> 8
    };
}

macro_rules! rgb_to_u32 {
    (
        $rgb:expr
    ) => {
        $rgb.into_u32::<channels::Rgba>() >> 8
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

fn css_generic_fn<A, B, C>(
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

    let (pos, (r, g, b)) = css_generic_fn(input, pos, component, component, component)?;
    let color = Srgb::new(r, g, b);
    Ok((
        pos,
        color.into_format::<u8>().into_u32::<channels::Rgba>() >> 8,
    ))
}

pub fn css_hsl_fn(input: &[u8], pos: usize) -> Result<u32> {
    fn coord(input: &[u8], pos: usize) -> Result<f32> {
        map(percentage(input, pos, 1.0), |x| x.clamp(0.0, 1.0))
    }

    let (pos, (h, s, l)) = css_generic_fn(input, pos, angle, coord, coord)?;
    let color = Hsl::new(h, s, l);
    let rgb = Srgb::from_color(color).into_format::<u8>();
    Ok((pos, rgb_to_u32!(rgb)))
}

pub fn css_hwb_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (h, w, b)) = css_generic_fn(
        input,
        pos,
        angle,
        |input, pos| percentage(input, pos, 100.0),
        |input, pos| percentage(input, pos, 100.0),
    )?;
    let color = Hwb::new(h, w, b);
    let rgb = Srgb::from_color(color).into_format::<u8>();
    Ok((pos, rgb_to_u32!(rgb)))
}

pub fn css_lab_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (l, a, b)) = css_generic_fn(
        input,
        pos,
        |input, pos| number_or_percentage(input, pos, 100.0),
        |input, pos| number_or_percentage(input, pos, 125.0),
        |input, pos| number_or_percentage(input, pos, 125.0),
    )?;
    let color = Lab::new(l, a, b);
    Ok((pos, color_to_u32!(color)))
}

pub fn css_lch_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (l, c, h)) = css_generic_fn(
        input,
        pos,
        |input, pos| number_or_percentage(input, pos, 100.0),
        |input, pos| number_or_percentage(input, pos, 150.0),
        angle,
    )?;
    let color = Lch::new(l, c, h);
    Ok((pos, color_to_u32!(color)))
}

pub fn css_oklab_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (l, a, b)) = css_generic_fn(
        input,
        pos,
        |input, pos| number_or_percentage(input, pos, 1.0),
        |input, pos| number_or_percentage(input, pos, 0.4),
        |input, pos| number_or_percentage(input, pos, 0.4),
    )?;
    let color = Oklab::new(l, a, b);
    Ok((pos, color_to_u32!(color)))
}

pub fn css_oklch_fn(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, (l, c, h)) = css_generic_fn(
        input,
        pos,
        |input, pos| number_or_percentage(input, pos, 1.0),
        |input, pos| number_or_percentage(input, pos, 0.4),
        angle,
    )?;
    let color = Oklch::new(l, c, h);
    Ok((pos, color_to_u32!(color)))
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

    (pos + 6, color.into_u32::<channels::Rgba>() >> 8)
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

    (pos + 3, color.into_u32::<channels::Rgba>() >> 8)
}

pub fn xterm256(input: &[u8], pos: usize) -> Result<u32> {
    let (pos, value) = integer(input, pos)?;
    match XTERM_256.get(value as usize) {
        Some(color) => Ok((
            pos,
            Srgb::<u8>::from(*color).into_u32::<channels::Rgba>() >> 8,
        )),
        None => Err(()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    mod rgb {
        use super::*;

        macro_rules! tests_impl {
            (
                $(
                    $test_name:ident : $input:literal -> Ok($expected_color:expr),
                )+
            ) => {
                $(
                    #[test]
                    fn $test_name() {
                        let actual = css_rgb_fn($input.as_bytes(), 0);
                        let expected = Ok(($input.len(), $expected_color));
                        assert_eq!(actual, expected);
                    }
                )+
            };
            (
                $(
                    $test_name:ident : $input:literal -> Err,
                )+
            ) => {
                $(
                    #[test]
                    fn $test_name() {
                        let actual = css_rgb_fn($input.as_bytes(), 0);
                        let expected = Err(());
                        assert_eq!(actual, expected);
                    }
                )+
            };
        }

        tests_impl! {
            space_separators: "1 2 3)" -> Ok(0x010203),
            comma_separators: "1,2,3)" -> Ok(0x010203),
            underscore_separators: "1_2_3)" -> Ok(0x010203),
            mixed_separators: "1 , 2_,_3)" -> Ok(0x010203),
            leading_space: " 1 2 3)" -> Ok(0x010203),
            leading_underscore: "_1_2_3)" -> Ok(0x010203),
            junk_after_third_component: "1 2 3 junk)" -> Ok(0x010203),
            floats: "1.5 2.5 3.5)" -> Ok(0x020204),
            percents: "100% 50% 0%)" -> Ok(0xff8000),

            gamut_overflow: "256 0 0)" -> Ok(0xff0000),
            gamut_underflow: "-0.001 0 0)" -> Ok(0x000000),
        }

        tests_impl! {
            junk_before_third_component: "1 2 junk 3)" -> Err,
            empty: "" -> Err,
            missing_component: "1 2)" -> Err,
            missing_close_parenthesis: "1 2 3" -> Err,
        }
    }
}
