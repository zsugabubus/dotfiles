//! This library implements <https://github.com/Myndex/SAPC-APCA/blob/master/documentation/APCA-W3-LaTeX.md>.
use num_traits::{Float, One, Zero};
use std::cmp::Ordering;

type Srgb<T> = (T, T, T);

fn black<T: Zero>() -> Srgb<T> {
    (T::zero(), T::zero(), T::zero())
}

fn white<T: One>() -> Srgb<T> {
    (T::one(), T::one(), T::one())
}

/// Designates usage of `T` to be related to text color.
#[derive(Debug, Clone)]
#[repr(transparent)]
#[must_use]
pub struct Text<T>(pub T);

/// Designates usage of `T` to be related to background color.
#[derive(Debug, Clone)]
#[repr(transparent)]
#[must_use]
pub struct Background<T>(pub T);

/// APCA lightness contrast.
#[derive(Debug, Clone)]
pub struct LightnessContrast<T>(T);

impl<T: Float> LightnessContrast<T> {
    /// Returns the contrast amount.
    ///
    /// # Examples
    ///
    /// ```
    /// # use apca::*;
    /// # use approx::assert_abs_diff_eq;
    /// let black = (0.0_f64, 0.0, 0.0);
    /// let white = (1.0_f64, 1.0, 1.0);
    ///
    /// let contrast = lightness_contrast(Text(white), Background(black));
    ///
    /// assert_abs_diff_eq!(contrast.value(), 107.9, epsilon = 0.1);
    /// ```
    #[inline]
    #[must_use]
    pub fn value(&self) -> T {
        self.0.abs()
    }

    /// Returns the raw signed value.
    ///
    /// # Examples
    ///
    /// ```
    /// # use apca::*;
    /// # use approx::assert_abs_diff_eq;
    /// let black = (0.0_f64, 0.0, 0.0);
    /// let white = (1.0_f64, 1.0, 1.0);
    ///
    /// let contrast = lightness_contrast(Text(white), Background(black));
    ///
    /// assert_abs_diff_eq!(contrast.signed_value(), -107.9, epsilon = 0.1);
    /// ```
    #[inline]
    #[must_use]
    pub fn signed_value(&self) -> T {
        self.0
    }

    /// Returns whether it represents light text on dark background.
    ///
    /// # Examples
    ///
    /// ```
    /// # use apca::*;
    /// let black = (1.0_f32, 0.0, 0.0);
    /// let white = (1.0_f32, 1.0, 1.0);
    ///
    /// let contrast = lightness_contrast(Text(white), Background(black));
    ///
    /// assert!(contrast.is_light_text_on_dark_background());
    /// assert!(!contrast.is_dark_text_on_light_background());
    /// ```
    #[inline]
    #[must_use]
    pub fn is_light_text_on_dark_background(&self) -> bool {
        self.signed_value() < T::zero()
    }

    /// Returns whether it represents dark text on light background.
    ///
    /// # Examples
    ///
    /// ```
    /// # use apca::*;
    /// let black = (1.0_f32, 0.0, 0.0);
    /// let white = (1.0_f32, 1.0, 1.0);
    ///
    /// let contrast = lightness_contrast(Text(black), Background(white));
    ///
    /// assert!(!contrast.is_light_text_on_dark_background());
    /// assert!(contrast.is_dark_text_on_light_background());
    /// ```
    ///
    /// ```
    /// # use apca::*;
    /// # let black = (1.0_f32, 0.0, 0.0);
    /// # let white = (1.0_f32, 1.0, 1.0);
    /// let contrast = lightness_contrast(Text(black), Background(black));
    ///
    /// assert!(!contrast.is_light_text_on_dark_background());
    /// assert!(!contrast.is_dark_text_on_light_background());
    /// ```
    #[inline]
    #[must_use]
    pub fn is_dark_text_on_light_background(&self) -> bool {
        self.signed_value() > T::zero()
    }
}

impl<T: Float> PartialEq for LightnessContrast<T> {
    fn eq(&self, other: &Self) -> bool {
        self.value() == other.value()
    }
}

impl<T: Float> Eq for LightnessContrast<T> {}

impl<T: Float> PartialOrd for LightnessContrast<T> {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        PartialOrd::partial_cmp(&self.value(), &other.value())
    }
}

impl<T: Float + Ord> Ord for LightnessContrast<T> {
    fn cmp(&self, other: &Self) -> Ordering {
        Ord::cmp(&self.value(), &other.value())
    }
}

/// Calculates APCA-W3 lightness contrast.
///
/// `text` and `background` should be sRGB colors where components are \[0,1\].
///
/// # Examples
///
/// ```
/// # use apca::*;
/// # use approx::assert_abs_diff_eq;
/// let red = (1.0_f32, 0.0, 0.0);
/// let blue = (0.0, 0.0, 1.0_f32);
///
/// let contrast = lightness_contrast(Text(red), Background(blue));
///
/// assert_abs_diff_eq!(contrast.value(), 20.3, epsilon = 0.1);
/// ```
#[allow(non_snake_case)]
#[must_use]
pub fn lightness_contrast<T: Float>(
    text: Text<Srgb<T>>,
    background: Background<Srgb<T>>,
) -> LightnessContrast<T> {
    macro_rules! f {
        ($literal:expr) => {
            T::from($literal).unwrap()
        };
    }

    let N_text = f!(0.57);
    let N_background = f!(0.56);

    let R_text = f!(0.62);
    let R_background = f!(0.65);

    let W_scale = f!(1.14);
    let W_offset = f!(0.027);
    let W_clamp = f!(0.1);

    fn sRGB_to_Y<T: Float>((red, green, blue): Srgb<T>) -> T {
        let S_trc = f!(2.4);
        let S_rco = f!(0.2126729);
        let S_gco = f!(0.7151522);
        let S_bco = f!(0.0721750);

        red.powf(S_trc) * S_rco + green.powf(S_trc) * S_gco + blue.powf(S_trc) * S_bco
    }

    fn f_sc<T: Float>(Y_c: T) -> T {
        let B_clip = f!(1.414);
        let B_threshold = f!(0.022);

        if Y_c < f!(0.0) {
            f!(0.0)
        } else if Y_c < B_threshold {
            Y_c + (B_threshold - Y_c).powf(B_clip)
        } else {
            Y_c
        }
    }

    let Y_text = f_sc(sRGB_to_Y(text.0));
    let Y_background = f_sc(sRGB_to_Y(background.0));

    let S_apc = if Y_background >= Y_text {
        (Y_background.powf(N_background) - Y_text.powf(N_text)) * W_scale
    } else {
        (Y_background.powf(R_background) - Y_text.powf(R_text)) * W_scale
    };

    let L_c = if S_apc.abs() < W_clamp {
        f!(0.0)
    } else if S_apc > f!(0.0) {
        (S_apc - W_offset) * f!(100.0)
    } else {
        (S_apc + W_offset) * f!(100.0)
    };

    LightnessContrast(L_c)
}

mod private {
    pub trait Sealed {}
}

use private::Sealed;

/// Color lightness.
#[derive(Debug, Clone, Eq, PartialEq, Hash)]
pub enum Lightness {
    /// Dark color.
    ///
    /// Should be displayed with/on white background/text for maximum contrast.
    Dark,
    /// Light color.
    ///
    /// Should be displayed on/with black background/text for maximum contrast.
    Light,
}

pub trait TextOrBackgroundLightness: Sealed {
    #[doc(hidden)]
    fn lightness(&self) -> Lightness;
}

impl<T> Sealed for Text<T> {}
impl<T> Sealed for Background<T> {}

impl<T: Float> TextOrBackgroundLightness for Text<Srgb<T>> {
    fn lightness(&self) -> Lightness {
        if lightness_contrast(Text(self.0), Background(black()))
            > lightness_contrast(Text(self.0), Background(white()))
        {
            Lightness::Light
        } else {
            Lightness::Dark
        }
    }
}

impl<T: Float> TextOrBackgroundLightness for Background<Srgb<T>> {
    fn lightness(&self) -> Lightness {
        if lightness_contrast(Text(black()), Background(self.0))
            > lightness_contrast(Text(white()), Background(self.0))
        {
            Lightness::Light
        } else {
            Lightness::Dark
        }
    }
}

/// Returns whether color is dark or light.
///
/// `color` should be an sRGB color where components are \[0,1\].
///
/// # Examples
///
/// ```
/// # use apca::*;
/// let red = (1.0_f32, 0.0, 0.0);
/// let black = (1.0_f32, 0.0, 0.0);
/// let white = (1.0_f32, 1.0, 1.0);
///
/// assert_eq!(lightness(Background(red)), Lightness::Dark);
/// assert_eq!(lightness(Background(black)), Lightness::Dark);
///
/// assert_eq!(lightness(Text(white)), Lightness::Light);
/// assert_eq!(lightness(Text(black)), Lightness::Dark);
/// ```
#[inline]
pub fn lightness(color: impl TextOrBackgroundLightness) -> Lightness {
    color.lightness()
}

#[cfg(test)]
mod tests {
    use crate::*;

    fn to_color((red, green, blue): (u8, u8, u8)) -> Srgb<f64> {
        (
            red as f64 / 255.0,
            green as f64 / 255.0,
            blue as f64 / 255.0,
        )
    }

    #[test]
    fn test_lightness_contrast() {
        // https://github.com/Myndex/SAPC-APCA/tree/master/documentation
        for (text, background, expected) in vec![
            ((0x88, 0x88, 0x88), (0xff, 0xff, 0xff), 63.056469930209424),
            ((0xff, 0xff, 0xff), (0x88, 0x88, 0x88), -68.54146436644962),
            ((0x00, 0x00, 0x00), (0xaa, 0xaa, 0xaa), 58.146262578561334),
            ((0xaa, 0xaa, 0xaa), (0x00, 0x00, 0x00), -56.24113336839742),
            ((0x11, 0x22, 0x33), (0xdd, 0xee, 0xff), 91.66830811481631),
            ((0xdd, 0xee, 0xff), (0x11, 0x22, 0x33), -93.06770049484275),
            ((0x11, 0x22, 0x33), (0x44, 0x44, 0x44), 8.32326136957393),
            ((0x44, 0x44, 0x44), (0x11, 0x22, 0x33), -7.526878460278154),
            // ((0x11, 0x22, 0x33), (0x22, 0x33, 0x44), 1.7512243099356113),
            // ((0x22, 0x33, 0x44), (0x11, 0x22, 0x33), -1.6349191031377903),
        ] {
            let actual = lightness_contrast(Text(to_color(text)), Background(to_color(background)))
                .signed_value();
            approx::assert_abs_diff_eq!(actual, expected, epsilon = f64::EPSILON);
        }
    }
}
