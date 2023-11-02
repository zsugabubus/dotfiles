use core::array;
use std::collections::HashSet;
// use fxhash::FxHashSet as HashSet;
use std::fmt::Debug;
use std::marker::PhantomData;

pub trait Config<const N: usize> {
    #[inline]
    fn buckets() -> usize {
        8
    }

    fn slots(pattern: &[u8]) -> [u8; N];
}

#[derive(Debug, Clone)]
pub struct TeddyBuilder<'a, const N: usize, C>
where
    C: Config<N>,
{
    height: usize,
    width: usize,
    buckets_len: usize,
    len: usize,
    xs: Vec<u8>,
    board: Box<[HashSet<usize>]>,
    phantom: PhantomData<&'a C>,
}

impl<'a, const N: usize, C> TeddyBuilder<'a, N, C>
where
    C: Config<N>,
{
    pub fn new(masks_len: usize, alphabet_len: usize, buckets_len: usize) -> Self {
        Self {
            height: masks_len,
            width: alphabet_len,
            buckets_len,
            len: 0,
            xs: Vec::new(),
            board: vec![Default::default(); masks_len * alphabet_len * buckets_len]
                .into_boxed_slice(),
            phantom: PhantomData,
        }
    }

    #[inline]
    fn cell_index(&self, y: usize, x: usize, bucket: usize) -> usize {
        debug_assert!(y < self.height);
        debug_assert!(x < self.width);
        debug_assert!(bucket < self.buckets_len);
        bucket * self.width * self.height + y * self.width + x
    }

    #[inline]
    fn cell(&self, y: usize, x: usize, bucket: usize) -> &HashSet<usize> {
        &self.board[self.cell_index(y, x, bucket)]
    }

    #[inline]
    fn cell_mut(&mut self, y: usize, x: usize, bucket: usize) -> &mut HashSet<usize> {
        &mut self.board[self.cell_index(y, x, bucket)]
    }

    pub fn push(&mut self, word: &[u8]) {
        let xs = C::slots(word);
        let i = self.len;
        xs.iter().copied().enumerate().for_each(|(y, x)| {
            if x == u8::MAX {
                for x in 0..self.width {
                    self.cell_mut(y, x, 0).insert(i);
                }
            } else {
                self.cell_mut(y, x as usize, 0).insert(i);
            }
        });
        let b = self.xs.len();
        self.xs.extend(xs);
        debug_assert!(self.xs.len() == b + self.height);
        self.len += 1;
    }

    pub fn clear(&mut self) {
        self.len = 0;
        self.xs.clear();
        self.board.iter_mut().for_each(HashSet::clear);
    }

    #[inline]
    pub fn len(&self) -> usize {
        self.len
    }

    #[inline]
    pub fn is_empty(&self) -> bool {
        self.len == 0
    }

    pub fn build(mut self) {
        use rand::prelude::*;
        let mut rng = rand::thread_rng();

        use std::time::Instant;
        let start = Instant::now();

        let mut total = Instant::now().elapsed();

        let mut zz = 1;
        for _ in 0..28
        /* TODO: Find iteration limit. */
        {
            let mut best: Option<(i64, usize, (usize, usize), usize)> = None;

            // let mut ntie = 0;
            // let mut ktie = 0;

            let mut v = vec![0_u64; self.height].into_boxed_slice();

            for src in 0..self.buckets_len {
                let src_before = (0..self.height).fold(1_u64, |p, y| {
                    p * (0..self.width)
                        .filter(|x| !self.cell(y, *x, src).is_empty())
                        .count() as u64
                });

                for y in 0..self.height {
                    for x in 0..self.width {
                        let square = self.cell(y, x, src);
                        if square.is_empty() {
                            continue;
                        }

                        zz += 1;

                        let coverage = {
                            for i in 0..self.height {
                                v[i] = 0;
                            }
                            for i in square {
                                for (y, x) in self.xs[i * self.height..(i + 1) * self.height]
                                    .iter()
                                    .copied()
                                    .enumerate()
                                {
                                    if x == u8::MAX {
                                        v[y] = !0;
                                    } else {
                                        v[y] |= 1 << x;
                                    }
                                }
                            }
                            &v
                        };

                        let src_after = (0..self.height).fold(1_u64, |p, y| {
                            p * (0..self.width)
                                .filter(|x| {
                                    let c = self.cell(y, *x, src);
                                    !c.is_empty() && !c.is_subset(square)
                                })
                                .count() as u64
                        });

                        let start = Instant::now();
                        for dest in 0..self.buckets_len {
                            if src == dest {
                                continue;
                            }

                            let (dest_before, dest_after) =
                                (0..self.height).fold((1_u64, 1_u64), |p, y| {
                                    let m = (0..self.width)
                                        .filter(|x| !self.cell(y, *x, dest).is_empty())
                                        .fold(0, |m, x| m | (1_u64 << x));
                                    (
                                        p.0 * m.count_ones() as u64,
                                        p.1 * (coverage[y] | m).count_ones() as u64,
                                    )
                                });

                            let delta = src_after as i64 + dest_after as i64
                                - src_before as i64
                                - dest_before as i64;
                            // println!(
                            //     "   rel to bucket {} => {} {} SUM {} sb {}",
                            //     dest, dest_before, dest_after, delta, src_before
                            // );

                            let score = (delta, src, (y, x), dest);
                            if let Some(ref mut best) = best {
                                let tie = best.0 == score.0;
                                if tie {
                                    // ntie += 1;
                                }
                                #[allow(clippy::if_same_then_else)]
                                if best.0 > score.0 {
                                    *best = score;
                                    // XXX: Probably not perfect but not 100% confirmed. We should backtrack on tie.
                                    // ntie = 0;
                                    // ktie = 0;
                                } else if tie
                                    && (best.1 != score.1 && best.2 != score.2)
                                    && rng.gen()
                                {
                                    *best = score;
                                    // ktie = ntie;
                                }
                            } else {
                                best = Some(score);
                            }
                        }
                        total += start.elapsed();
                    }
                }
            }

            if let Some((_, src, (y, x), dest)) = best {
                let relocpats = self.cell(y, x, src).clone();
                debug_assert!(!relocpats.is_empty());

                // println!(
                //     "step end {:3}/{:3} -- {:?} removed pats {:?} -- {:#?}",
                //     ntie,
                //     ktie,
                //     (delta, src, (y, x), dest),
                //     relocpats,
                //     (), //self.board
                // );

                for i in relocpats {
                    for (y, x) in self.xs[i * self.height..(i + 1) * self.height]
                        .iter()
                        .copied()
                        .enumerate()
                    {
                        if x == u8::MAX {
                            unimplemented!();
                        } else {
                            // println!("{:?}: {:?}", (y, x), self.board[self.cell_index(y, x, src)]);
                            let b = self.board[self.cell_index(y, x as usize, src)].remove(&i);
                            debug_assert!(b);
                            let b = self.board[self.cell_index(y, x as usize, dest)].insert(i);
                            debug_assert!(b);
                        }
                        // zz += 2;
                    }
                }
            }
        }

        let sum = (0..self.buckets_len).fold(0_u64, |p, i| {
            p + (0..self.height).fold(1, |p, y| {
                p * (0..self.width)
                    .filter(|x| !self.cell(y, *x, i).is_empty())
                    .count() as u64
            })
        });
        println!("==> {:?} zz={}", sum, zz);

        let mut r = Vec::new();
        for y in 0..self.height {
            let mut v = vec![0_u8; self.width].into_boxed_slice();

            for i in 0..self.buckets_len {
                for x in 0..self.width {
                    if !self.cell(y, x, i).is_empty() {
                        v[x] |= 1 << i;
                    }
                }
            }

            r.push(v);
        }

        let b = r
            .iter()
            .map(|x| x.iter().map(|x| *x as i8).collect::<Vec<_>>())
            .collect::<Vec<_>>();
        println!("{:#?}", b);

        let duration = start.elapsed();
        println!("Time elapsed in expensive_function() is: {duration:?} // {total:?}");

        // todo!();
    }
}

use std::arch::x86_64::__m128i;

#[derive(Clone, Debug)]
pub struct LowNibbleConfig<const N: usize> {
    _masks: [__m128i; N],
}

impl<const N: usize> Config<N> for LowNibbleConfig<N> {
    fn slots(pattern: &[u8]) -> [u8; N] {
        array::from_fn(|i| pattern.get(i).map(|x| x & 0xf).unwrap_or(u8::MAX))
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
    return !_mm_movemask_epi8(_mm_cmpeq_epi8(mask, _mm_setzero_si128())) as u32;
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
