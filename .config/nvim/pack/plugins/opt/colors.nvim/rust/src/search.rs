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
        Action::Named([r, g, b]) => (len, ((r as u32) << 16) | ((g as u32) << 8) | (b as u32)),
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

    macro_rules! test_impl {
        (
            $(
                $test_name:ident : $input:expr => $expected:expr,
            )+
        ) => {
            $(
                #[test]
                fn $test_name() {
                    let mut got = None;
                    search(
                        ($input.to_owned() + "\0").as_bytes(),
                        |m| {
                            got = Some(m);
                            ControlFlow::Continue(())
                        },
                    );
                    assert_eq!(got, Some(Match::new(
                        0..$input.len(),
                        $expected,
                    )));
                }
            )+
        }
    }

    test_impl! {
        red: "red" => 0xff0000,
        green: "green" => 0x008000,
        greenyellow: "greenyellow" => 0xadff2f,
        yellow: "yellow" => 0xffff00,
        blue: "blue" => 0x0000ff,
        lightgoldenrodyellow: "lightgoldenrodyellow" => 0xfafad2,
        hex6_digits: "#003399" => 0x003399,
        hex6_lowercase: "#abcdef" => 0xabcdef,
        hex6_uppercase: "#ABCDEF" => 0xabcdef,
        hex3_digits: "#039" => 0x003399,
        hex3_lowercase: "#abc" => 0xaabbcc,
        hex3_uppercase: "#ABC" => 0xaabbcc,
        hwb: "hwb(0 0% 0%)" => 0xff0000,
        xhex3: "0x123" => 0x112233,
        xhex6: "0x123465" => 0x123465,
        colour0: "colour0" => 0x000000,
        brightcolor0: "brightcolor0" => 0x000000,
        color0: "color0" => 0x000000,
        color1: "color1" => 0x800000,
        color2: "color2" => 0x008000,
        color3: "color3" => 0x808000,
        color7: "color7" => 0xc0c0c0,
        color8: "color8" => 0x808080,
        color9: "color9" => 0xff0000,
        color10: "color10" => 0x00ff00,
        color12: "color12" => 0x0000ff,
        color16: "color16" => 0x000000,
        color17: "color17" => 0x00005f,
        color52: "color52" => 0x5f0000,
        color21: "color21" => 0x0000ff,
        color57: "color57" => 0x5f00ff,
        color196: "color196" => 0xff0000,
        color231: "color231" => 0xffffff,
        color46: "color46" => 0x00ff00,
        color232: "color232" => 0x080808,
        rgb: "rgb(255 0 0)" => 0xff0000,
        rgba: "rgba(255 0 0)" => 0xff0000,
    }

    macro_rules! test_word_boundary_impl {
        (
            $(
                $test_name:ident : $input:expr => $should_match:expr,
            )+
        ) => {
            $(
                #[test]
                fn $test_name() {
                    for i in 0..32 {
                        let mut got = None;
                        search(
                            (" ".repeat(i) + "_" + $input + "\0").as_bytes(),
                            |m| {
                                got = Some(m);
                                ControlFlow::Continue(())
                            },
                        );
                        if $should_match {
                            assert!(got.is_some());
                        } else {
                            assert_eq!(got, None);
                        }
                    }
                }
            )+
        }
    }

    test_word_boundary_impl! {
        word_boundary_space: "red" => true,
        word_boundary_underscore: "_red" => true,
        word_boundary_alphabetic: "xred" => false,
    }

    /*
    fn test_large() {
        use std::fs::File;
        use std::io::prelude::*;
        let mut f = File::open("../../target/large-file.txt").unwrap();
        let mut buffer = Vec::new();
        f.read_to_end(&mut buffer).unwrap();

        use std::time::Instant;
        let start = Instant::now();

        for _i in 0..10 {
            // println!("go!");
            search(buffer.as_ref(), |_m| {
                // println!("MATCH #{} => {:?}", c, m);
                ControlFlow::Continue(())
            });
            // println!("TOTAL MATCH {}", c);
        }

        let duration = start.elapsed();
        println!("Time elapsed in expensive_function() is: {duration:?}");
    }
    */
}
