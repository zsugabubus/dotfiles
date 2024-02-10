#![no_std]
#![feature(test)]

/// Return length of NUL-terminated string.
///
/// # Safety
///
/// - `s` points to a valid NUL-terminated string.
///
/// - Target features are available.
#[cfg(target_arch = "x86_64")]
#[target_feature(enable = "sse2", enable = "sse4.1", enable = "avx")]
pub unsafe fn strlen(s: *const u8) -> usize {
    use core::arch::x86_64::*;

    const PAGE_SIZE: usize = 4096;

    let mut i = 0;

    macro_rules! zeromask128 {
        (
            $block:expr
        ) => {
            _mm_movemask_epi8(_mm_cmpeq_epi8($block, _mm_setzero_si128()))
        };
    }

    macro_rules! test128 {
        (
            $block:expr
        ) => {
            let nuls = zeromask128!($block) as u32;
            if nuls != 0 {
                return i + nuls.trailing_zeros() as usize;
            }
            i += 16;
        };
    }

    macro_rules! test256 {
        (
            $block:expr
        ) => {
            let nuls = (zeromask128!(_mm256_castsi256_si128($block)) as u32)
                | ((zeromask128!(_mm256_extractf128_si256($block, 1)) as u32) << 16);
            if nuls != 0 {
                return i + nuls.trailing_zeros() as usize;
            }
            i += 32;
        };
    }

    if (s as usize % PAGE_SIZE) <= (PAGE_SIZE - 32) {
        let block = _mm256_loadu_si256(s as *const _);
        test256!(block);
        i -= (s.add(i) as usize) % 32;
    } else {
        while s.add(i).align_offset(16) != 0 {
            if *s.add(i) == 0 {
                return i;
            }
            i += 1;
        }

        if s.add(i).align_offset(32) != 0 {
            let block = _mm_load_si128(s.add(i) as *const _);
            test128!(block);
        }
    }

    if s.add(i).align_offset(64) != 0 {
        let block = _mm256_load_si256(s.add(i) as *const _);
        test256!(block);
    }

    loop {
        // Idea stolen from glibc: _mm_movemask_epi8 is slow so use _mm_min_epi8 instead as a
        // pre-filter.
        //
        // Using _mm_test_all_zeros results in much slower code.
        //
        // Four _mm_load_si128 seems to be faster (maybe can better reordered) than two
        // _mm256_load_si256 split with _mm256_castsi256_si128/_mm256_extractf128_si256.
        let (a, b, c, d) = (
            _mm_load_si128(s.add(i) as *const _),
            _mm_load_si128(s.add(i + 16) as *const _),
            _mm_load_si128(s.add(i + 32) as *const _),
            _mm_load_si128(s.add(i + 48) as *const _),
        );
        let abcd = _mm_min_epi8(_mm_min_epi8(_mm_min_epi8(a, b), c), d);
        let nuls = zeromask128!(abcd) as u64;
        if nuls != 0 {
            let nuls = (zeromask128!(a) as u64)
                | ((zeromask128!(b) as u64) << 16)
                | ((zeromask128!(c) as u64) << 32)
                | (nuls << 48);
            return i + nuls.trailing_zeros() as usize;
        }
        i += 64;
    }
}

#[cfg(test)]
mod tests {
    extern crate test;

    use super::*;
    use test::{black_box, Bencher};

    #[macro_export]
    macro_rules! bench_impl {
        [
            $(
                $bench_name:ident: $len:expr,
            )+
        ] => {
            $(
                #[bench]
                fn $bench_name(b: &mut test::Bencher) {
                    let input = test::black_box("x".repeat($len) + "\0");
                    #[allow(unused_unsafe)]
                    b.iter(|| unsafe { strlen(input.as_ptr()) } );
                }
            )+
        };
        (
            all
        ) => {
            bench_impl! [
                n_0: 0,
                n_1: 1,
                n_8: 8,
                n_15: 15,
                n_16: 16,
                n_32: 32,
                n_48: 48,
                n_64: 64,
                n_96: 96,
                n_100: 100,
                n_128: 128,
                n_192: 192,
                n_256: 256,
                n_512: 512,
                n_1000: 1000,
                n_10000: 10000,
                n_100000: 100000,
            ];

            #[bench]
            fn n_mix(b: &mut Bencher) {
                let input0 = black_box("x".repeat(0) + "\0");
                let input8 = black_box("x".repeat(8) + "\0");
                let input15 = black_box("x".repeat(15) + "\0");
                let input16 = black_box("x".repeat(16) + "\0");
                let input100 = black_box("x".repeat(100) + "\0");
                #[allow(unused_unsafe)]
                b.iter(|| unsafe {
                        strlen(input8.as_ptr()) +
                        strlen(input0.as_ptr()) +
                        strlen(input15.as_ptr()) +
                        strlen(input100.as_ptr()) +
                        strlen(input16.as_ptr()) +
                        0
                } );
            }

        }
    }

    mod libc {
        use super::*;

        extern "C" {
            fn strlen(s: *const u8) -> usize;
        }

        super::bench_impl!(all);
    }

    mod memchr {
        use super::*;

        fn strlen(s: *const u8) -> usize {
            ::memchr::memchr(0, unsafe { core::slice::from_raw_parts(s, 1000000) }).unwrap()
        }

        super::bench_impl!(all);
    }

    super::bench_impl!(all);

    #[test]
    fn it_works() {
        let input = "x".repeat(8192) + "\0";
        for offset in 0..8192 {
            let actual = unsafe { strlen(input.as_bytes().as_ptr().add(offset)) };
            assert_eq!(actual, 8192 - offset);
        }
    }
}
