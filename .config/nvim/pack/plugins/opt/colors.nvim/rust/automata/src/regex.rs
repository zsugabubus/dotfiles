use crate::nfa::{Nfa, StateId};
use std::hash::Hash;
use std::ops::{Deref, DerefMut, Range};

/// A high-level [NFA][`Nfa`] builder.
///
/// # Examples
///
/// ```
/// # use automata::{nfa::Nfa, regex::*};
/// let mut nfa = Nfa::new();
/// let start = nfa.new_state();
///
/// let mut re = Regex::new(&mut nfa);
///
/// let state = re.insert_pattern(start, "#[0-9a-f]{6}", &Flags::new().caseless(true))?;
/// re.set_accept(state, "A color");
///
/// let state = re.insert_literal(start, "Hello World", &Flags::new());
/// re.set_accept(state, "A colorful world");
///
/// # Ok::<(), ParseError>(())
/// ```
#[derive(Debug)]
pub struct Regex<'a, T, A> {
    nfa: &'a mut Nfa<T, A>,
}

impl<'a, T, A> Regex<'a, T, A> {
    /// Constructs a new `Regex`.
    pub fn new(nfa: &'a mut Nfa<T, A>) -> Self {
        Self { nfa }
    }
}

impl<'a, T, A> Regex<'a, T, A>
where
    T: From<u8> + Eq + Hash,
{
    /// Inserts regex.
    ///
    /// Returns end state.
    pub fn insert_pattern(
        &mut self,
        start: StateId,
        pattern: &str,
        flags: &Flags,
    ) -> Result<StateId, ParseError> {
        Ok(self.insert_node(start, &parse(pattern)?, flags))
    }

    /// Inserts literal.
    ///
    /// Returns end state.
    pub fn insert_literal<S: AsRef<[u8]>>(
        &mut self,
        start: StateId,
        literal: S,
        flags: &Flags,
    ) -> StateId {
        self.insert_node(start, &Node::ByteSeq(literal.as_ref()), flags)
    }

    fn insert_node(&mut self, start: StateId, node: &Node, flags: &Flags) -> StateId {
        match node {
            Node::Byte(x) => {
                let end = self.new_state();
                self.insert_transition(start, *x, end, flags);
                end
            }
            Node::ByteSeq(xs) => xs.iter().fold(start, |start, x| {
                let end = self.new_state();
                self.insert_transition(start, *x, end, flags);
                end
            }),
            Node::ByteClass(ranges) => {
                let end = self.new_state();
                for range in ranges.iter() {
                    for x in range.clone() {
                        self.insert_transition(start, x, end, flags);
                    }
                }
                end
            }
            Node::Seq(lhs, rhs) => {
                let start = self.insert_node(start, lhs, flags);
                self.insert_node(start, rhs, flags)
            }
            Node::Repeat(body, times) => {
                (0..*times).fold(start, |start, _| self.insert_node(start, body, flags))
            }
            Node::Flags(body, new_flags) => self.insert_node(start, body, new_flags),
        }
    }

    fn insert_transition(&mut self, from: StateId, terminal: u8, to: StateId, flags: &Flags) {
        if flags.caseless && terminal.is_ascii_alphabetic() {
            self.nfa
                .insert_transition(from, terminal.to_ascii_lowercase(), to);
            self.nfa
                .insert_transition(from, terminal.to_ascii_uppercase(), to);
        } else {
            self.nfa.insert_transition(from, terminal, to);
        }
    }
}

impl<'a, T, A> Deref for Regex<'a, T, A> {
    type Target = Nfa<T, A>;

    fn deref(&self) -> &Self::Target {
        self.nfa
    }
}

impl<'a, T, A> DerefMut for Regex<'a, T, A> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        self.nfa
    }
}

#[derive(Debug, Clone)]
pub struct Flags {
    caseless: bool,
}

impl Flags {
    /// Constructs a new `Flags`.
    #[inline]
    pub fn new() -> Self {
        Self { caseless: false }
    }

    /// Sets caseless flag.
    #[inline]
    pub fn caseless(&mut self, yes: bool) -> &mut Self {
        self.caseless = yes;
        self
    }
}

impl Default for Flags {
    #[inline]
    fn default() -> Self {
        Self::new()
    }
}

#[derive(Debug)]
enum Node<'a> {
    Byte(u8),
    ByteSeq(&'a [u8]),
    ByteClass(Box<[Range<u8>]>),
    Seq(Box<Node<'a>>, Box<Node<'a>>),
    Repeat(Box<Node<'a>>, u64),
    #[allow(dead_code)]
    Flags(Box<Node<'a>>, Flags),
}

#[derive(Debug)]
#[non_exhaustive]
pub enum ParseError {
    ClassOpenExpected {
        byte_pos: usize,
    },
    ClassCloseExpected {
        byte_range: Range<usize>,
    },
    RepeatOpenExpected {
        byte_pos: usize,
    },
    RepeatCloseExpected {
        byte_range: Range<usize>,
    },
    InvalidNumber {
        byte_range: Range<usize>,
        source: std::num::ParseIntError,
    },
}

fn parse(input: &str) -> Result<Node<'static>, ParseError> {
    type Result<T> = core::result::Result<(usize, T), ParseError>;

    #[inline]
    pub fn peek(input: &[u8], pos: usize) -> Option<u8> {
        input.get(pos).copied()
    }

    fn eof(input: &[u8], pos: usize) -> bool {
        pos >= input.len()
    }

    fn byte(input: &[u8], pos: usize) -> Result<Node<'static>> {
        match peek(input, pos) {
            Some(x) => Ok((pos + 1, Node::Byte(x))),
            None => unreachable!(),
        }
    }

    fn byte_class(input: &[u8], mut pos: usize) -> Result<Node<'static>> {
        let start = pos;
        let mut v = Vec::new();

        let Some(b'[') = peek(input, pos) else {
            return Err(ParseError::ClassOpenExpected { byte_pos: pos });
        };
        pos += 1;

        loop {
            let low = match peek(input, pos) {
                Some(b']') => return Ok((pos + 1, Node::ByteClass(v.into_boxed_slice()))),
                Some(x) => {
                    pos += 1;
                    x
                }
                None => {
                    return Err(ParseError::ClassCloseExpected {
                        byte_range: start..pos,
                    })
                }
            };

            if peek(input, pos) != Some(b'-') {
                v.push(low..low + 1);
                continue;
            }
            pos += 1;

            let high = match peek(input, pos) {
                Some(x) => {
                    pos += 1;
                    x
                }
                None => {
                    return Err(ParseError::ClassCloseExpected {
                        byte_range: start..pos,
                    })
                }
            };
            v.push(low..high + 1);
        }
    }

    pub fn take_while<T>(
        input: &[T],
        mut pos: usize,
        pred: impl Fn(&T) -> bool,
    ) -> (usize, core::ops::Range<usize>) {
        let start = pos;
        loop {
            if input.get(pos).is_some_and(&pred) {
                pos += 1;
            } else {
                return (pos, start..pos);
            }
        }
    }

    fn number(input: &[u8], pos: usize) -> Result<u64> {
        let start = pos;

        let (pos, range) = take_while(input, pos, u8::is_ascii_digit);
        // SAFETY: All bytes are of ASCII digits.
        let s = unsafe { std::str::from_utf8_unchecked(&input[range]) };

        match s.parse() {
            Ok(x) => Ok((pos, x)),
            Err(err) => Err(ParseError::InvalidNumber {
                byte_range: start..pos,
                source: err,
            }),
        }
    }

    fn repeat<'a>(input: &[u8], pos: usize, body: Node<'a>) -> Result<Node<'a>> {
        let start = pos;

        let Some(b'{') = peek(input, pos) else {
            return Err(ParseError::RepeatOpenExpected { byte_pos: pos });
        };

        let (pos, times) = number(input, pos + 1)?;

        let Some(b'}') = peek(input, pos) else {
            return Err(ParseError::RepeatCloseExpected {
                byte_range: start..pos,
            });
        };

        Ok((pos + 1, Node::Repeat(Box::new(body), times)))
    }

    fn atom(input: &[u8], pos: usize) -> Result<Node<'static>> {
        let (pos, lhs) = if peek(input, pos) == Some(b'[') {
            byte_class(input, pos)
        } else {
            byte(input, pos)
        }?;

        if peek(input, pos) == Some(b'{') {
            repeat(input, pos, lhs)
        } else {
            Ok((pos, lhs))
        }
    }

    fn seq(input: &[u8], pos: usize) -> Result<Node<'static>> {
        let (mut pos, mut lhs) = atom(input, pos)?;

        loop {
            if eof(input, pos) {
                return Ok((pos, lhs));
            }

            (pos, lhs) = atom(input, pos)
                .map(|(pos, node)| (pos, Node::Seq(Box::new(lhs), Box::new(node))))?;
        }
    }

    let input = input.as_bytes();
    let (pos, node) = seq(input, 0)?;
    debug_assert!(eof(input, pos));
    Ok(node)
}
