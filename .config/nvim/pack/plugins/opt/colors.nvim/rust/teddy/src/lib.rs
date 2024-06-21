use core::array;
use rand::prelude::*;
use std::{arch::x86_64::__m128i, collections::HashSet, fmt::Debug};

type Mask = u64;

/// `N` is the number of masks.
pub trait Config<const N: usize> {
    type Input: ?Sized;

    /// Returns number of buckets.
    ///
    /// For `i8x16` it should be `8`.
    fn buckets(&self) -> usize;

    /// Returns number of lanes.
    ///
    /// For `i8x16` it should be `16`.
    fn lanes(&self) -> usize;

    /// Returns lane masks that match the input.
    fn fingerprint(&self, input: &Self::Input) -> [Mask; N];
}

#[derive(Clone, Debug)]
pub struct LowNibble<const N: usize>;

impl<const N: usize> Config<N> for LowNibble<N> {
    type Input = [u8];

    fn buckets(&self) -> usize {
        8
    }

    fn lanes(&self) -> usize {
        16
    }

    fn fingerprint(&self, input: &Self::Input) -> [Mask; N] {
        array::from_fn(|i| (1 << (input[i] % 16)))
    }
}

#[derive(Debug, Clone)]
pub struct TeddyBuilder<'a, const N: usize, C> {
    masks: HashSet<[Mask; N]>,
    config: &'a C,
}

impl<'a, const N: usize, C> TeddyBuilder<'a, N, C>
where
    C: Config<N>,
{
    pub fn new(config: &'a C) -> Self {
        Self {
            masks: HashSet::new(),
            config,
        }
    }

    pub fn insert(&mut self, input: &C::Input) {
        self.masks.insert(self.config.fingerprint(input));
    }

    pub fn build(self) {
        const MAX_SCORE: u32 = u32::MAX;

        let mut rng = rand::thread_rng();

        let height = N;
        let width = self.config.lanes();
        let mut buckets = {
            let n = self.config.buckets();
            let capacity = self.masks.len() / n + 1;
            (0..n)
                .map(|_| Vec::with_capacity(capacity))
                .collect::<Vec<_>>()
                .into_boxed_slice()
        };
        let masks = self
            .masks
            .into_iter()
            .collect::<Vec<_>>()
            .into_boxed_slice();

        for i in 0..masks.len() {
            let bucket = rng.gen_range(0..buckets.len());
            let bucket = bucket % buckets.len();
            buckets[bucket].push(i);
        }

        let mut bucket_masks = vec![[0 as Mask; N]; buckets.len()].into_boxed_slice();
        let mut bucket_scores = vec![0; buckets.len()].into_boxed_slice();
        let mut global_score = MAX_SCORE;
        let mut global_best_masks = vec![[0 as Mask; N]; buckets.len()].into_boxed_slice();
        let mut global_best_score = MAX_SCORE;

        let mut shuffles = 0;

        let mut selection = Vec::new();
        let mut best_selection = Vec::new();
        let mut best_src_dest = (0, 0);
        let mut best_src_mask_score = ([0 as Mask; N], 0);
        let mut best_dest_mask_score = ([0 as Mask; N], 0);

        loop {
            fn merge<const N: usize>(dest: &mut [Mask; N], src: &[Mask; N]) {
                for i in 0..N {
                    dest[i] |= src[i];
                }
            }

            fn score<const N: usize>(mask: &[Mask; N]) -> u32 {
                mask.iter().map(|x| x.count_ones()).product()
            }

            if global_score == MAX_SCORE {
                for i in 0..buckets.len() {
                    (bucket_scores[i], bucket_masks[i]) = {
                        let mut v = [0; N];

                        for mask in buckets[i].iter().map(|&i| &masks[i]) {
                            merge(&mut v, mask);
                        }

                        (score(&v), v)
                    };
                }

                global_score = bucket_scores.iter().sum();
            };

            /*
            let mut vs = vec![0_usize; width.pow(height as u32)].into_boxed_slice();

            for a0 in 0..width {
                for b0 in 0..width {
                    for c0 in 0..width {
                        let i = a0 + b0 * width + c0 * width * width;

                        for bi in 0..buckets.len() {
                            if (bucket_masks[bi][0] & (1 << a0)) != 0
                                && (bucket_masks[bi][1] & (1 << b0)) != 0
                                && (bucket_masks[bi][2] & (1 << c0)) != 0
                            {
                                vs[i] |= 1 << bi;
                            }
                        }
                    }
                }
            }
            println!(
                "real score:{global_score} k/n: {}",
                vs.iter().filter(|&&x| x != 0).count()
            );
            */

            let mut best_score = global_score;

            // Find masks in `src` bucket that has a set bit in the `y`th mask at the `x`th lane
            // and move them to `dest` bucket. Find the move that yields the greatest score
            // decrease.
            //
            // Note that instead of moving a single mask (by ID) we move (potentially) multiple
            // masks at once. If a mask is completely overlapped by other masks, it would leave no
            // holes in the source bucket after it had been moved out. It implies that source score
            // remains unchanged thus there is no way for the global score to decrease. So we pick
            // a position and move out all masks under it to make sure source score decrease.
            for src in 0..buckets.len() {
                for (y, &(mut xs)) in bucket_masks[src].iter().enumerate() {
                    while xs != 0 {
                        let x = xs.trailing_zeros();
                        xs ^= 1 << x;

                        selection.clear();

                        let (src_mask_after, selection_mask) = {
                            let mut v = [0; N];
                            let mut w = [0; N];

                            for (i, mask) in buckets[src].iter().map(|&i| &masks[i]).enumerate() {
                                merge(
                                    if (mask[y] & (1 << x)) == 0 {
                                        &mut v
                                    } else {
                                        selection.push(i);
                                        &mut w
                                    },
                                    mask,
                                );
                            }

                            (v, w)
                        };

                        debug_assert!(selection_mask != [0; N]);

                        let src_score_after = score(&src_mask_after);

                        let mut found_best = false;

                        /*
                        let src_mask_before = bucket_masks[src];

                        let mut mink = 0;
                        for a0 in 0..width {
                            for b0 in 0..width {
                                for c0 in 0..width {
                                    let i = a0 + b0 * width + c0 * width * width;
                                    let m = [1 << a0, 1 << b0, 1 << c0];

                                    if vs[i] == (1 << src)
                                        && (((src_mask_before[0] ^ src_mask_after[0]) & m[0]) != 0)
                                        && (((src_mask_before[1] ^ src_mask_after[1]) & m[1]) != 0)
                                        && (((src_mask_before[2] ^ src_mask_after[2]) & m[2]) != 0)
                                    {
                                        mink += 1;
                                    }
                                }
                            }
                        }
                        if mink > 0 {
                            println!("mink={mink}");
                        }
                        */

                        for dest in 0..buckets.len() {
                            if src == dest {
                                continue;
                            }

                            let src_score_before = bucket_scores[src];

                            let dest_score_before = bucket_scores[dest];

                            let dest_mask_before = bucket_masks[dest];

                            let dest_mask_after = {
                                let mut m = dest_mask_before;
                                merge(&mut m, &selection_mask);
                                m
                            };
                            let dest_score_after = score(&dest_mask_after);

                            debug_assert!(src_score_after < src_score_before);
                            debug_assert!(dest_score_after >= dest_score_before);

                            let score_before = src_score_before + dest_score_before;
                            let score_after = src_score_after + dest_score_after;

                            let score = global_score + score_after - score_before;

                            if score > best_score || (score == best_score && rng.gen()) {
                                continue;
                            }

                            found_best = true;

                            best_score = score;
                            best_src_dest = (src, dest);
                            best_src_mask_score = (src_mask_after, src_score_after);
                            best_dest_mask_score = (dest_mask_after, dest_score_after);
                        }

                        if found_best {
                            std::mem::swap(&mut best_selection, &mut selection);
                        }
                    }
                }
            }

            if best_score < global_score {
                let (src, dest) = best_src_dest;

                for &i in best_selection.iter().rev() {
                    let j = buckets[src].swap_remove(i);
                    buckets[dest].push(j);
                }

                global_score = best_score;
                (bucket_masks[src], bucket_scores[src]) = best_src_mask_score;
                (bucket_masks[dest], bucket_scores[dest]) = best_dest_mask_score;

                continue;
            }

            if best_score < global_best_score {
                global_best_score = best_score;
                global_best_masks.clone_from(&bucket_masks);
                shuffles = 0;
            }

            // Local optimum is likely not the global minimum so we keep searching. To get out of
            // the local trap we perturb mask assignments.
            if shuffles < 10 {
                shuffles += 1;

                for _ in 0..masks.len().div_ceil(10) {
                    let src = rng.gen_range(0..buckets.len());
                    let dest = rng.gen_range(0..buckets.len());

                    let x = 0..buckets[src].len();
                    if x.is_empty() {
                        continue;
                    }
                    let i = rng.gen_range(x);
                    let j = buckets[src].swap_remove(i);

                    buckets[dest].push(j);
                }

                global_score = MAX_SCORE;

                continue;
            }

            break;
        }

        let b = (0..height)
            .map(|y| {
                (0..width)
                    .map(|x| {
                        (0..buckets.len()).fold(0, |bits, i| {
                            bits | if (global_best_masks[i][y] & (1 << x)) != 0 {
                                1 << i
                            } else {
                                0
                            }
                        }) as i8
                    })
                    .collect::<Vec<_>>()
                    .into_boxed_slice()
            })
            .collect::<Vec<_>>()
            .into_boxed_slice();

        let mut n = 0;
        let mut k = 0;

        for a0 in 0..width as u8 {
            for b0 in 0..width as u8 {
                for c0 in 0..width as u8 {
                    let input: [u8; 3] = [a0, b0, c0];

                    n += 1;

                    if input
                        .iter()
                        .zip(b.iter())
                        .fold(0xff, |x, (input, b)| x & (b[(input & 0xf) as usize] as u8))
                        != 0
                    {
                        k += 1;
                    }
                }
            }
        }

        let passthrough = (global_best_score as f64) / width.pow(height as u32) as f64;

        println!(
            "P={k}/{:.2}% ({global_best_score}/{:.2}% predicted) LEN={} => {global_best_masks:?} {b:?}",
            k as f64 / n as f64 * 100.0,
            passthrough * 100.0,
            masks.len()
        );

        for (i, bucket) in buckets.iter().enumerate() {
            println!("bucket[{i}]:");
            for y in 0..height {
                let mut v = vec![0; width].into_boxed_slice();

                for mask in bucket.iter().map(|&i| &masks[i]) {
                    for x in 0..width {
                        if (mask[y] & (1 << x)) != 0 {
                            v[x] += 1;
                        }
                    }
                }
                println!("  [{y}]: {v:?}");
            }
        }
    }
}

#[target_feature(enable = "sse2", enable = "ssse3")]
#[inline]
pub unsafe fn check_matches(teddy: &[__m128i], input: __m128i) -> u32 {
    use std::arch::x86_64::*;

    macro_rules! mask {
        ( $i:expr , $( $rest:tt )+ ) => {
            _mm_and_si128(
                _mm_shuffle_epi8(teddy[$i], _mm_srli_si128(input, $i)),
                mask! { $( $rest )+ },
            )
        };
        ( 0 ) => {
            _mm_shuffle_epi8(teddy[0], input)
        }
    }

    macro_rules! len {
        ( $i:expr , $( $rest:tt )+ ) => {
            if $i == teddy.len() {
                mask! { $( $rest )+ }
            } else {
                len! { $( $rest )+ }
            }
        };
        ( 0 ) => {
            unimplemented!();
        }
    }

    let mask = len! { 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 };
    !_mm_movemask_epi8(_mm_cmpeq_epi8(mask, _mm_setzero_si128())) as u32
}

/*
struct Classifier128 {
    values: [Option<u8>; 128],
}

struct Classifier128 {

    pub fn set(&mut self, ch: AsciiChar, value: u8) {
        self.values[ch.as_byte()] = value;
    }

    pub fn build_checker(&mut self) {
        let mut asso = [0; 16];
    }
}
*/
