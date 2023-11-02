use std::collections::hash_map::Entry::{Occupied, Vacant};
use std::collections::{BTreeSet, HashMap, HashSet};
use std::fmt::Debug;
use std::hash::Hash;
use std::io::Write;
use std::iter::Iterator;
use std::mem::{replace, swap, take};

use crate::automaton::*;
use crate::nfa::{self, Nfa};

automaton_impl! { pub struct StateId; }

/// Possible errors during DFA management.
#[derive(Debug)]
#[non_exhaustive]
pub enum Error {
    /// Attempted to make a nondeterministic transition.
    ///
    /// An equivalent transition already exists in the system but that one has different `to`
    /// endpoint.
    ConflictingTransitions,
    /// Attempted to make a state resolve with multiple values.
    ///
    /// DFAs cannot handle multiple accept values but it is possible to create a "super accept
    /// value" using a custom conflict resolver. See [`Dfa::from_nfa`] and
    /// [`Dfa::set_accept_with`].
    ConflictingAccepts,
    /// Alphabet size is too small to represent a terminal.
    TerminalNotInAlphabet,
}

type Result<T> = std::result::Result<T, Error>;

#[derive(Debug)]
pub(crate) struct State {
    pub(crate) transitions: HashMap<Terminal, StateId>,
}

impl State {
    pub fn new() -> Self {
        Self {
            transitions: HashMap::new(),
        }
    }
}

/// Deterministic finite automaton (DFA).
#[derive(Debug)]
pub struct Dfa<A>
where
    A: Accept,
{
    pub(crate) states: Vec<State>,
    pub(crate) accepts: HashMap<StateId, A>,
}

impl<A> Dfa<A>
where
    A: Accept,
{
    /// Constructs a new DFA.
    pub fn new() -> Self {
        Self {
            states: Vec::new(),
            accepts: HashMap::new(),
        }
    }

    /// Converts NFA to DFA.
    ///
    /// Reverse of [`Nfa::from_dfa`].
    pub fn from_nfa(
        nfa: &Nfa<A>,
        start: nfa::StateId,
        accept_strategy: impl Fn(A, A) -> Option<A>,
    ) -> Result<(Self, StateId)> {
        let mut dfa = Self::new();
        let mut to_be_mapped: Vec<(StateId, BTreeSet<nfa::StateId>)> = Vec::new();
        let mut mapped: HashMap<BTreeSet<nfa::StateId>, StateId> = HashMap::new();

        // TODO: Use function.
        let dfa_start_state = dfa.new_state();
        {
            let tos = {
                let mut x = BTreeSet::new();
                x.insert(start);
                x
            };
            mapped.insert(tos.clone(), dfa_start_state);
            to_be_mapped.push((dfa_start_state, tos));
        }

        while let Some((mapped_state, mut to_be_visited_states)) = to_be_mapped.pop() {
            let mut states_to_merge: HashSet<nfa::StateId> = HashSet::new();
            assert!(!to_be_visited_states.is_empty());
            while !to_be_visited_states.is_empty() {
                for state_id in take(&mut to_be_visited_states) {
                    if !states_to_merge.insert(state_id) {
                        continue;
                    }
                    if let Some(found) = nfa.epsilon_transitions.get(&state_id) {
                        to_be_visited_states.extend(found);
                    }
                }
            }

            for merge_state in states_to_merge.iter() {
                if let Some(with) = nfa.accepts.get(merge_state) {
                    dfa.set_accept_with(mapped_state, (*with).clone(), &accept_strategy)?;
                }
            }

            let mut super_transitions = HashMap::new();
            for merge_state in states_to_merge {
                for (term, tos) in &nfa.states[merge_state.as_usize()].transitions {
                    debug_assert!(!tos.is_empty());
                    super_transitions
                        .entry(*term)
                        .or_insert_with(BTreeSet::new)
                        .extend(tos);
                }
            }

            for (term, tos) in super_transitions {
                debug_assert!(!tos.is_empty());
                if let Some(visited_next_state) = mapped.get(&tos) {
                    dfa.insert_transition(mapped_state, term, *visited_next_state)?;
                } else {
                    let next_state = dfa.new_state();
                    mapped.insert(
                        {
                            let mut x = BTreeSet::new();
                            x.extend(tos.iter());
                            x
                        },
                        next_state,
                    );
                    dfa.insert_transition(mapped_state, term, next_state)?;
                    to_be_mapped.push((next_state, tos));
                }
            }
        }

        Ok((dfa, dfa_start_state))
    }

    /// Creates a new state.
    pub fn new_state(&mut self) -> StateId {
        let id = StateId::from(self.states.len());
        self.states.push(State::new());
        id
    }

    /// Sets accept value of a state.
    pub fn set_accept(&mut self, state: StateId, value: A) -> Result<()> {
        self.set_accept_with(state, value, |_, _| None)
    }

    /// Sets accept value of a state with custom conflict resolver.
    pub fn set_accept_with(
        &mut self,
        state: StateId,
        value: A,
        strategy: impl Fn(A, A) -> Option<A>,
    ) -> Result<()> {
        match self.accepts.entry(state) {
            Occupied(mut entry) => {
                entry
                    .insert(strategy(entry.get().clone(), value).ok_or(Error::ConflictingAccepts)?);
            }
            Vacant(entry) => {
                entry.insert(value);
            }
        }
        Ok(())
    }

    /// Creates a transition between `from` and `to`.
    pub fn insert_transition(&mut self, from: StateId, via: Terminal, to: StateId) -> Result<()> {
        match self.states[from.as_usize()].transitions.entry(via) {
            Occupied(entry) => {
                if *entry.get() != to {
                    Err(Error::ConflictingTransitions)
                } else {
                    Ok(())
                }
            }
            Vacant(entry) => {
                entry.insert(to);
                Ok(())
            }
        }
    }

    /// Turns alphabet into "equivalence classes of the alphabet".
    fn compress_alphabet(&self, alphabet_len: usize) -> Result<Box<[usize]>> {
        struct CompressedAlphabetBuilder {
            classes: Vec<HashSet<Terminal>>,
            terminal_class: Box<[usize]>,
        }

        impl CompressedAlphabetBuilder {
            pub fn new(len: usize) -> Self {
                Self {
                    classes: vec![{
                        let mut class = HashSet::new();
                        class.extend(0..len);
                        class
                    }],
                    terminal_class: vec![0; len].into_boxed_slice(),
                }
            }

            pub fn add_equivalence_class(&mut self, class: &HashSet<Terminal>) -> Result<()> {
                for term in class.iter() {
                    if *term >= self.terminal_class.len() {
                        return Err(Error::TerminalNotInAlphabet);
                    }

                    let term_class = &mut self.classes[self.terminal_class[*term]];
                    if !class.is_superset(term_class) {
                        let new_class = term_class
                            .intersection(class)
                            .copied()
                            .collect::<HashSet<_>>();
                        for t in new_class.iter() {
                            term_class.remove(t);
                        }
                        for t in new_class.iter() {
                            self.terminal_class[*t] = self.classes.len();
                        }
                        self.classes.push(new_class);
                    }
                }
                Ok(())
            }

            pub fn build(self) -> Box<[usize]> {
                self.terminal_class
            }
        }

        let mut alphabet = CompressedAlphabetBuilder::new(alphabet_len);
        let mut classes = HashMap::new();

        for state in self.states.iter() {
            debug_assert!(classes.is_empty());

            for (term, to) in state.transitions.iter() {
                classes.entry(to).or_insert_with(HashSet::new).insert(*term);
            }

            for (_, class) in classes.drain() {
                alphabet.add_equivalence_class(&class)?;
            }
        }

        Ok(alphabet.build())
    }

    /// Writes DOT representation of the automaton for debugging purposes.
    pub fn write_dot(&self, mut writer: impl Write) -> std::io::Result<()> {
        writeln!(writer, "digraph {{")?;
        writeln!(writer, "\trankdir=LR")?;

        writeln!(writer)?;
        writeln!(writer, "\tnode [shape=doublecircle, width=1.5, height=1.5]")?;
        for (state_id, value) in self.accepts.iter() {
            writeln!(
                writer,
                "\t{} [label={:?}]",
                state_id.0,
                format!("{}\n{:?}", state_id.0, value)
            )?;
        }
        writeln!(writer)?;

        writeln!(
            writer,
            "\tnode [shape=circle, width=.75, height=.75, fixedsize=true]"
        )?;
        for (from_id, from) in self.states.iter().enumerate() {
            for (term, to) in from.transitions.iter() {
                writeln!(
                    writer,
                    "\t{} -> {} [label={:?}]",
                    from_id,
                    to.as_usize(),
                    (*term as u8 as char).to_string()
                )?;
            }
        }

        writeln!(writer, "}}")?;
        Ok(())
    }

    /// Returns an iterator that generates all possible non-rejected words having the given length.
    pub fn words_exact(&self, start: StateId, len: usize) -> WordsExact<A> {
        WordsExact::new(self, start, len)
    }

    /// Returns a breadth-first iterator over states.
    pub fn breadth_first_states(
        &self,
        start: StateId,
        max_depth: Option<usize>,
    ) -> BreadthFirstStates<A> {
        BreadthFirstStates::new(self, start, max_depth)
    }

    /// Finds minimum possible input length to an accept state, if any.
    ///
    /// When `max` is given, it can be used to restrict maximum search distance.
    ///
    /// If search ends without reaching an accepting state, `None` is returned.
    // TODO: Dead state elimination should happen in a similar way.
    pub fn shortest_word_len(&self, start: StateId, max_len: Option<usize>) -> Option<usize> {
        for (depth, state_id) in self.breadth_first_states(start, max_len) {
            if self.accepts.contains_key(&state_id) {
                return Some(depth);
            }
        }
        None
    }

    pub fn collect_terminals(&self, start: StateId, max_depth: Option<usize>) -> HashSet<Terminal> {
        let mut terminals = HashSet::new();
        for (_, state_id) in self.breadth_first_states(start, max_depth) {
            terminals.extend(self.states[state_id.as_usize()].transitions.keys());
        }
        terminals
    }

    /// Writes implementation of [`Config`].
    pub fn write_config(
        &self,
        mut writer: impl Write,
        struct_name: &str,
        alphabet_len: usize,
        start: StateId,
    ) -> std::io::Result<()> {
        let alphabet = self.compress_alphabet(alphabet_len).unwrap();

        let alphabet_len = alphabet.iter().max().unwrap() + 1;

        // [..accept, ..reject, ..others]
        // TODO: Maybe simplify with sort_by().
        let mut i = 0;
        let mut state_map = Vec::new();
        let mut accept_vec = Vec::new();
        state_map.resize(self.states.len(), usize::MAX);
        for (accept, value) in self.accepts.iter() {
            state_map[accept.as_usize()] = i;
            accept_vec.push(value);
            i += 1;
        }
        for item in state_map.iter_mut() {
            if *item == usize::MAX {
                *item = i;
                i += 1;
            }
        }
        assert_eq!(i, state_map.len());
        let state_map = state_map;

        // Assume we can use pre-multiplied states.
        assert!(state_map.len() * alphabet_len < (1 << 16));

        let mut gtransitions = Vec::new();
        gtransitions.resize(
            self.states.len() * alphabet_len,
            state_map[start.as_usize()] * alphabet_len,
        );

        for (from_id, from) in self.states.iter().enumerate() {
            let mapped_from_id = state_map[from_id];
            let base = mapped_from_id * alphabet_len;
            for (term, to) in from.transitions.iter() {
                let to = state_map[to.as_usize()];
                gtransitions[base + alphabet[*term]] = to * alphabet_len;
            }
        }

        // FIXME: rejet state: find state that is output only (currently assume start). OTHERWISE allocate explicity state.

        writeln!(
            writer,
            "
            pub struct {};

            impl {} {{
                const CLASSES: [u8; {}] = {:?};
                const ACCEPTS: [<Self as Config>::Accept; {}] = {:?};
                const TRANSITIONS: [u16; {}] = {:?};
            }}

            // TODO: Should these shit functions be unsafe because state must be valid?
            impl Config for {} {{
                type State = u16;
                type Accept = Action;
                type Input = u8;

                #[inline]
                fn start_state(&self) -> Self::State {{
                    {}
                }}

                #[inline]
                fn dead_state(&self) -> Self::State {{
                    {}
                }}

                #[inline]
                unsafe fn is_accept_state(&self, state: Self::State) -> bool {{
                    (state as usize) < Self::ACCEPTS.len() * {}
                }}

                #[inline]
                unsafe fn is_dead_state(&self, state: Self::State) -> bool {{
                    state == self.dead_state()
                }}

                #[inline]
                unsafe fn get_next_state(&self, state: Self::State, input: Self::Input) -> Self::State {{
                    *Self::TRANSITIONS.get_unchecked(state as usize + *Self::CLASSES.get_unchecked(input as usize) as usize)
                }}

                #[inline]
                unsafe fn get_accept_value(&self, accept_state: Self::State) -> &Self::Accept {{
                    Self::ACCEPTS.get_unchecked(((accept_state as u32) / {}) as usize)
                }}
            }}
            ",
            struct_name,
            struct_name,
            alphabet.len(),
            alphabet,
            accept_vec.len(),
            accept_vec,
            gtransitions.len(),
            gtransitions,
            struct_name,
            state_map[start.as_usize()] * alphabet_len,
            state_map[start.as_usize()] * alphabet_len,
            alphabet_len,
            alphabet_len
        )?;

        Ok(())
    }
}

impl<A> Default for Dfa<A>
where
    A: Accept,
{
    fn default() -> Self {
        Self::new()
    }
}

/// A word iterator for [`Dfa`].
pub struct WordsExact<'a, A>
where
    A: Accept,
{
    dfa: &'a Dfa<A>,
    stack: Vec<std::collections::hash_map::Iter<'a, Terminal, StateId>>,
    word: Box<[Terminal]>,
    len: usize,
}

impl<'a, A> WordsExact<'a, A>
where
    A: Accept,
{
    pub(super) fn new(dfa: &'a Dfa<A>, start: StateId, len: usize) -> Self {
        Self {
            dfa,
            stack: {
                let mut x = Vec::with_capacity(len + 1);
                x.push(dfa.states[start.as_usize()].transitions.iter());
                x
            },
            word: vec![0; len].into_boxed_slice(),
            len,
        }
    }
}

impl<'a, A> Iterator for WordsExact<'a, A>
where
    A: Accept,
{
    type Item = Box<[Terminal]>;

    fn next(&mut self) -> Option<Self::Item> {
        while let Some(cur) = self.stack.last_mut() {
            match cur.next() {
                Some((term, to)) => {
                    self.word[self.stack.len() - 1] = *term;
                    if self.stack.len() == self.len {
                        // FIXME: Not that important but find out whether we can use some scratch
                        // space to save the allocation.
                        return Some(self.word.clone());
                    } else {
                        self.stack
                            .push(self.dfa.states[to.as_usize()].transitions.iter());
                    }
                }
                None => {
                    self.stack.pop();
                }
            }
        }
        None
    }
}

/// A breadth-first state iterator for [`Dfa`].
pub struct BreadthFirstStates<'a, A>
where
    A: Accept,
{
    dfa: &'a Dfa<A>,
    current_level: Vec<StateId>,
    next_level: Vec<StateId>,
    has_visited: Box<[bool]>,
    depth: usize,
    max_depth: Option<usize>,
    latest_state: Option<StateId>,
}

impl<'a, A> BreadthFirstStates<'a, A>
where
    A: Accept,
{
    pub(super) fn new(dfa: &'a Dfa<A>, start: StateId, max_depth: Option<usize>) -> Self {
        Self {
            dfa,
            current_level: vec![start],
            next_level: Vec::new(),
            has_visited: vec![false; dfa.states.len()].into_boxed_slice(),
            depth: 0,
            max_depth,
            latest_state: None,
        }
    }
}

impl<'a, A> Iterator for BreadthFirstStates<'a, A>
where
    A: Accept,
{
    type Item = (usize, StateId);

    fn next(&mut self) -> Option<Self::Item> {
        loop {
            // Save some cycles and add next states only if we are still running.
            if let Some(state_id) = self.latest_state.take() {
                self.next_level.extend(
                    self.dfa.states[state_id.as_usize()]
                        .transitions
                        .values()
                        .copied(),
                );
            }

            while let Some(state_id) = self.current_level.pop() {
                if replace(&mut self.has_visited[state_id.as_usize()], true) {
                    continue;
                }

                if self.max_depth.map_or(true, |x| self.depth < x) {
                    self.latest_state = Some(state_id)
                }

                return Some((self.depth, state_id));
            }

            self.depth += 1;

            if self.next_level.is_empty() {
                return None;
            }

            swap(&mut self.next_level, &mut self.current_level);
        }
    }
}

/// Current state of an automaton.
///
/// Exact semantics are defined by executor implementation.
pub enum AutomatonState<'c, A, M> {
    /// Never accepting state.
    ///
    /// Automaton is in a state that (for all inputs) will never lead to an accepting state.
    Dead,
    /// Non-accepting state.
    ///
    /// Automaton is currently in a non-accepting state but it is possible that it will reach an
    /// accepting state in the future for some input.
    Reject,
    /// Accepting state.
    ///
    /// Automaton recognized the input.
    Accept {
        /// Static value of the accepting state supplied at automaton build-time.
        value: &'c A,
        /// Dynamic value supplied to `advance`.
        ///
        /// It can be anything but usually contains some kind of byte offset for tracking purposes.
        meta: M,
    },
}

/// DFA executor confguration.
pub trait Config {
    type State;
    type Accept;
    type Input;

    fn start_state(&self) -> Self::State;
    fn dead_state(&self) -> Self::State;

    /// # Safety
    ///
    /// `state` is a valid state.
    unsafe fn is_accept_state(&self, state: Self::State) -> bool;

    /// # Safety
    ///
    /// `state` is a valid state.
    unsafe fn is_dead_state(&self, state: Self::State) -> bool;

    /// # Safety
    ///
    /// `state` is a valid state.
    unsafe fn get_next_state(&self, state: Self::State, input: Self::Input) -> Self::State;

    /// # Safety
    ///
    /// `accept_state` is a valid accept state.
    unsafe fn get_accept_value(&self, accept_state: Self::State) -> &Self::Accept;
}

/// DFA executor.
pub struct Automaton<'c, C>
where
    C: Config,
{
    state: C::State,
    config: &'c C,
}

impl<'c, C> Automaton<'c, C>
where
    C: Config,
    C::State: Copy + Debug,
    C::Input: Copy + Debug,
{
    /// Creates an executor from the given config.
    pub fn new(config: &'c C) -> Self {
        unsafe { Self::with_start(config, config.start_state()) }
    }

    /// # Safety
    ///
    /// `state` must be a valid state.
    pub unsafe fn with_start(config: &'c C, state: C::State) -> Self {
        Self { state, config }
    }

    #[inline]
    pub fn advance<M>(&mut self, input: C::Input, meta: M) -> AutomatonState<C::Accept, M> {
        unsafe {
            self.state = self.config.get_next_state(self.state, input);

            if self.config.is_accept_state(self.state) {
                AutomatonState::Accept {
                    value: self.config.get_accept_value(self.state),
                    meta,
                }
            } else if !self.config.is_dead_state(self.state) {
                AutomatonState::Reject
            } else {
                AutomatonState::Dead
            }
        }
    }
}

/// DFA executor that returns longest match only.
pub struct DeadAcceptAutomaton<'c, C, M>
where
    C: Config,
{
    state: C::State,
    accept: (C::State, M),
    config: &'c C,
}

impl<'c, C, M> DeadAcceptAutomaton<'c, C, M>
where
    C: Config,
    C::State: Copy + Debug,
    C::Input: Copy + Debug,
    M: Copy + Default,
{
    /// Creates an executor from the given config.
    pub fn new(config: &'c C) -> Self {
        unsafe { Self::with_start(config, config.start_state()) }
    }

    /// # Safety
    ///
    /// `state` must be a valid state.
    pub unsafe fn with_start(config: &'c C, state: C::State) -> Self {
        Self {
            state,
            accept: (config.dead_state(), Default::default()),
            config,
        }
    }

    /// Returns the latest accepting state when automaton reaches a dead state.
    ///
    /// # Return value
    ///
    /// - [`AutomatonState::Dead`]: Automaton reached a dead state.
    /// - [`AutomatonState::Reject`]: Automaton waits for further input.
    /// - [`AutomatonState::Accept`]: Automaton reached a dead state and the latest seen accepting state is returned.
    #[inline]
    pub fn advance(&mut self, input: C::Input, meta: M) -> AutomatonState<C::Accept, M> {
        unsafe {
            self.state = self.config.get_next_state(self.state, input);

            if self.config.is_accept_state(self.state) {
                self.accept = (self.state, meta);
                AutomatonState::Reject
            } else if !self.config.is_dead_state(self.state) {
                AutomatonState::Reject
            } else if self.config.is_dead_state(self.accept.0) {
                AutomatonState::Dead
            } else {
                AutomatonState::Accept {
                    value: self.config.get_accept_value(self.accept.0),
                    meta: self.accept.1,
                }
            }
        }
    }
}
