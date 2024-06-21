use build::Action;
use std::ops::{ControlFlow, Range};
// use std::sync::atomic::{AtomicU8, Ordering};

mod generated {
    use automata::dfa::Config;
    use build::Action::{self, *};

    include! {
        concat!(env!("OUT_DIR"), "/generated.rs")
    }
}
use generated::*;

// static IMPLEMENTATION: AtomicU8 = AtomicU8::new(0);

#[derive(Debug, PartialEq)]
pub struct Match {
    range: Range<usize>,
    color: u32,
}

impl Match {
    #[inline]
    pub fn new(range: Range<usize>, color: u32) -> Self {
        Self { range, color }
    }

    #[inline]
    pub fn first(&self) -> usize {
        self.range.start
    }

    #[inline]
    pub fn last(&self) -> usize {
        self.range.end - 1
    }

    #[inline]
    pub fn color(&self) -> u32 {
        self.color
    }
}

// fn is_available() -> bool {
//     #[cfg(target_arch = "x86_64")]
//     {
//         is_x86_feature_detected!("sse2")
//             && is_x86_feature_detected!("ssse3")
//             && is_x86_feature_detected!("sse4.1")
//             && is_x86_feature_detected!("sse4.2")
//     }

//     #[cfg(not(target_arch = "x86_64"))]
//     false
// }

pub fn search(haystack: &[u8], f: impl FnMut(Match) -> ControlFlow<()>) {
    // XXX: Kills performance?
    /*
    let is_available = match IMPLEMENTATION.load(Ordering::Relaxed) {
        0 => {
            let b = is_available();
            IMPLEMENTATION.store(if b { 1 } else { 0 }, Ordering::Relaxed);
            b
        },
        _ => true,
    };

    if is_available
    */
    {
        unsafe {
            search_sse2(haystack, f);
        }
    }
}

#[target_feature(
    enable = "sse2",
    enable = "ssse3",
    enable = "sse4.1",
    enable = "sse4.2"
)]
unsafe fn search_sse2(haystack: &[u8], mut f: impl FnMut(Match) -> ControlFlow<()>) {
    use std::arch::x86_64::*;

    const WINDOW: usize = 14;
    const SHORTEST_MATCH: usize = 3;

    #[target_feature(
        enable = "sse2",
        enable = "ssse3",
        enable = "sse4.1",
        enable = "sse4.2"
    )]
    unsafe fn search_blocks(
        mut haystack: &[u8],
        mut f: impl FnMut(Match) -> ControlFlow<()>,
        mut offset: usize,
        mut wb: u32,
    ) -> ControlFlow<(), (&[u8], usize, u32)> {
        while haystack.len() >= 16 {
            let block = _mm_loadu_si128(haystack.as_ptr() as *const _);

            /* Pre-filter: Word boundary (minimum three letters). */
            let nonword = {
                // [A-Za-z0-9#]
                let word_asso = _mm_setr_epi8(
                    0x00, 0x00, 0x00, 0x00, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x04, 0x08, 0x08,
                    0x08, 0x08, 0x08,
                );
                let word_shift = _mm_setr_epi8(
                    i8::MIN,
                    i8::MIN,
                    -0x23,
                    -0x30,
                    -0x41,
                    -0x50,
                    -0x61,
                    -0x34,
                    -0x44,
                    -0x4b,
                    -0x64,
                    -0x6b,
                    i8::MIN,
                    i8::MIN,
                    i8::MIN,
                    i8::MIN,
                );

                let high = _mm_srli_epi32(block, 3);
                let hash = _mm_avg_epu8(_mm_shuffle_epi8(word_asso, block), high);
                let nonwordv = _mm_adds_epi8(_mm_shuffle_epi8(word_shift, hash), block);
                _mm_movemask_epi8(nonwordv) as u32
            };
            let word = nonword ^ 0xffff;
            let mut matches = word & (word >> 1) & (word >> 2) & ((nonword << 1) | wb);
            wb = (nonword >> (WINDOW as i32 - 1)) & 1;

            /* Pre-filter: Character patterns (first three letters). */
            matches &= {
                teddy::check_matches(
                    &[
                        _mm_setr_epi8(
                            -6, 74, 91, 52, 91, 2, 25, 50, 104, 112, 8, 16, -119, -56, -126, 115,
                        ),
                        _mm_setr_epi8(
                            4, -82, 23, -92, 4, 127, 20, 12, -34, -3, 2, 36, 82, 10, 68, -17,
                        ),
                        _mm_setr_epi8(
                            -124, 20, 12, -123, 68, 6, -124, -124, -124, 6, 0, 0, 32, 1, 12, 20,
                        ),
                    ],
                    block,
                )
            };

            while matches != 0 {
                let k = matches.trailing_zeros() as usize;
                matches &= !(1 << k);

                // f(Match {
                //     start: offset + k,
                //     end: offset + k + 1,
                //     color: 0xff0000,
                // });

                let rest = &haystack.get_unchecked(k..);
                if let Some((action, len)) = verify_literal(rest) {
                    let m = match verify_all(rest, offset + k, len, action) {
                        Some(x) => x,
                        None => continue,
                    };
                    if let ControlFlow::Break(_) = f(m) {
                        return ControlFlow::Break(());
                    }
                }
            }

            haystack = haystack.get_unchecked(WINDOW..);
            offset += WINDOW;
        }
        ControlFlow::Continue((haystack, offset, wb))
    }

    if let ControlFlow::Continue((haystack, offset, wb)) = search_blocks(haystack, &mut f, 0, 1) {
        if haystack.len() >= SHORTEST_MATCH {
            let mut buf: [u8; 16] = [0; 16];
            buf[..haystack.len()].copy_from_slice(haystack);
            search_blocks(&buf, &mut f, offset, wb);
        }
    }
}

fn verify_all(s: &[u8], offset: usize, len: usize, action: Action) -> Option<Match> {
    use crate::parser::*;

    let (len, color) = match action {
        Action::Named(r, g, b) => (len, ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)),
        Action::Xrrggbb => unsafe { css_hex6_unchecked(s, 1) },
        Action::XXrrggbb => unsafe { css_hex6_unchecked(s, 2) },
        Action::Xrgb => unsafe { css_hex3_unchecked(s, 1) },
        Action::XXrgb => unsafe { css_hex3_unchecked(s, 2) },
        Action::RgbFn => css_rgb_fn(s, 4).ok()?,
        Action::RgbaFn => css_rgb_fn(s, 5).ok()?,
        Action::HslFn => css_hsl_fn(s, 4).ok()?,
        Action::HslaFn => css_hsl_fn(s, 5).ok()?,
        Action::LabFn => css_lab_fn(s, 4).ok()?,
        Action::LchFn => css_lch_fn(s, 4).ok()?,
        Action::OklabFn => css_oklab_fn(s, 6).ok()?,
        Action::OklchFn => css_oklch_fn(s, 6).ok()?,
        Action::HwbFn => css_hwb_fn(s, 4).ok()?,
        Action::Color => xterm256(s, 5).ok()?,
        Action::BrightColor => xterm256(s, 11).ok()?,
        Action::Colour => xterm256(s, 6).ok()?,
    };
    Some(Match::new(offset..offset + len, color))
}

#[inline]
pub fn verify_literal(input: &[u8]) -> Option<(Action, usize)> {
    use automata::dfa::{AutomatonState, DeadAcceptAutomaton};
    let mut dfa = DeadAcceptAutomaton::new(&MyDfa);
    let mut i = 0;
    loop {
        // SAFETY: Input is NUL-terminated and NUL always leads to dead state.
        match dfa.advance(unsafe { *input.get_unchecked(i) }, i) {
            AutomatonState::Reject => {}
            AutomatonState::Dead => return None,
            AutomatonState::Accept { value, meta: i } => return Some((*value, i + 1)),
        }
        i += 1;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches() {
        #[track_caller]
        fn assert_match2(input: &str, expected: u32) {
            let mut got = None;

            search((input.to_owned() + "\0").as_bytes(), |m| {
                got = Some(m);
                ControlFlow::Continue(())
            });

            assert_eq!(got, Some(Match::new(0..input.len(), expected)));
        }

        #[track_caller]
        fn assert_match(input: &str, expected: u32) {
            assert_match2(&input.to_ascii_lowercase(), expected);
            assert_match2(&input.to_ascii_uppercase(), expected);
        }

        assert_match("hsl(0 0% 100%)", 0xffffff);
        assert_match("hsla(0 0% 100%)", 0xffffff);
        assert_match("hwb(0 100% 0%)", 0xffffff);
        assert_match("lab(100 0 0)", 0xffffff);
        assert_match("lch(100% 0% 0)", 0xffffff);
        assert_match("oklab(1 0 0)", 0xffffff);
        assert_match("oklch(100% 0 0)", 0xffffff);
        assert_match("rgb(255 255 255)", 0xffffff);
        assert_match("rgba(100% 100% 100%)", 0xffffff);
        assert_match("color15", 0xffffff);
        assert_match("brightcolor15", 0xffffff);
        assert_match("colour15", 0xffffff);
        assert_match("#fff", 0xffffff);
        assert_match("#ffffff", 0xffffff);
        assert_match("0xfff", 0xffffff);
        assert_match("0xffffff", 0xffffff);

        assert_match("#010", 0x001100);
        assert_match("#230", 0x223300);
        assert_match("#450", 0x445500);
        assert_match("#670", 0x667700);
        assert_match("#890", 0x889900);
        assert_match("#ab0", 0xaabb00);
        assert_match("#cd0", 0xccdd00);
        assert_match("#ef0", 0xeeff00);

        assert_match("rebeccapurple", 0x663399);

        for (name, color) in &NAMED_COLORS {
            assert_match(name, *color);
        }
    }

    #[test]
    fn word_boundary() {
        #[track_caller]
        fn assert_match(input: &str, expected_offset: Option<usize>) {
            for i in 0..32 {
                let mut got = None;

                search((" ".repeat(i) + input + "\0").as_bytes(), |m| {
                    got = Some(m.first());
                    ControlFlow::Continue(())
                });

                assert_eq!(got, expected_offset.map(|x| i + x));
            }
        }

        assert_match("red", Some(0));
        assert_match("_red", Some(1));
        assert_match("-red", Some(1));
        assert_match("xred", None);
        assert_match("#red", None);
    }
}
