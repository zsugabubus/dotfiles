use std::collections::{HashMap, HashSet};
use std::fmt::Debug;
use std::hash::Hash;
use std::io::Write;
use std::iter::Iterator;

use crate::automaton::*;
use crate::dfa::Dfa;

automaton_impl! { pub struct StateId; }

#[derive(Debug)]
pub(crate) struct State<T> {
    pub(crate) transitions: HashMap<T, HashSet<StateId>>,
}

impl<T> State<T> {
    pub fn new() -> Self {
        Self {
            transitions: HashMap::new(),
        }
    }
}

/// Nondeterministic finite automaton (NFA).
///
/// An NFA is rarely useful on its own but it is mostly used as an intermediate layer to build a
/// DFA. See [`Dfa::from_nfa`].
#[derive(Debug)]
pub struct Nfa<T, A> {
    pub(crate) states: Vec<State<T>>,
    pub(crate) epsilon_transitions: HashMap<StateId, HashSet<StateId>>,
    pub(crate) accepts: HashMap<StateId, A>,
}

impl<T, A> Nfa<T, A> {
    /// Constructs a new NFA.
    pub fn new() -> Self {
        Self {
            accepts: HashMap::new(),
            states: Vec::new(),
            epsilon_transitions: HashMap::new(),
        }
    }

    /// Converts DFA to NFA.
    ///
    /// Reverse of [`Dfa::from_nfa`].
    pub fn from_dfa(dfa: &Dfa<T, A>) -> Self
    where
        T: Eq + Hash + Copy,
        A: Clone,
    {
        let mut nfa = Self::new();
        nfa.insert_dfa(dfa);
        nfa
    }

    pub fn insert_dfa(&mut self, dfa: &Dfa<T, A>)
    where
        T: Eq + Hash + Copy,
        A: Clone,
    {
        let base = self.new_state_many(dfa.states.len());

        for (from, state) in dfa.states.iter().enumerate() {
            for (term, to) in state.transitions.iter() {
                self.insert_transition(
                    StateId::from(from + base),
                    *term,
                    StateId::from(to.as_usize() + base),
                );
            }
        }

        for (i, value) in dfa.accepts.iter() {
            self.set_accept(StateId::from(i.as_usize() + base), value.clone());
        }
    }

    pub fn rev(&self) -> Self
    where
        T: Eq + Hash + Copy,
        A: Clone,
    {
        let mut nfa = Self::new();
        nfa.insert_rev_nfa(self);
        nfa
    }

    fn insert_rev_nfa(&mut self, other: &Self)
    where
        T: Eq + Hash + Copy,
        A: Clone,
    {
        let base = self.new_state_many(other.states.len());

        for (from, state) in other.states.iter().enumerate() {
            for (term, tos) in state.transitions.iter() {
                for to in tos {
                    self.insert_transition(
                        StateId::from(to.as_usize() + base),
                        *term,
                        StateId::from(from + base),
                    );
                }
            }
        }

        for (from, tos) in other.epsilon_transitions.iter() {
            for to in tos {
                self.insert_epsilon_transition(
                    StateId::from(to.as_usize() + base),
                    StateId::from(from.as_usize() + base),
                );
            }
        }

        for (i, value) in other.accepts.iter() {
            self.set_accept(StateId::from(i.as_usize() + base), value.clone());
        }
    }

    /// Creates a new state.
    pub fn new_state(&mut self) -> StateId {
        self.states.push(State::new());
        StateId::from(self.states.len() - 1)
    }

    fn new_state_many(&mut self, count: usize) -> usize {
        let base = self.states.len();
        self.states
            .resize_with(self.states.len() + count, State::new);
        base
    }

    /// Sets accept value of a state.
    pub fn set_accept(&mut self, state: StateId, value: A) {
        self.accepts.insert(state, value);
    }

    /// Creates a terminal transition between `from` and `to`.
    pub fn insert_transition<V: Into<T>>(&mut self, from: StateId, via: V, to: StateId)
    where
        T: Eq + Hash,
    {
        self.states[from.as_usize()]
            .transitions
            .entry(via.into())
            .or_default()
            .insert(to);
    }

    /// Creates an empty/epsilon transition between `from` and `to`.
    pub fn insert_epsilon_transition(&mut self, from: StateId, to: StateId) {
        self.epsilon_transitions.entry(from).or_default().insert(to);
    }

    /// Writes DOT representation of the automaton for debugging purposes.
    ///
    /// # Examples
    ///
    /// ```
    /// # use automata::nfa::Nfa;
    /// # use std::io::BufWriter;
    /// # use std::fs::File;
    /// let writer = BufWriter::new(File::create("a.dot").unwrap());
    ///
    /// let nfa: Nfa<()> = Nfa::new();
    /// // ...
    /// nfa.write_dot(writer).unwrap();
    /// ```
    ///
    /// Then create SVG from it:
    ///
    /// ```sh
    /// dot -Tsvg a.dot > a.svg
    /// ```
    pub fn write_dot<W: Write>(&self, mut writer: W) -> std::io::Result<()>
    where
        T: Debug,
        A: Debug,
    {
        writeln!(writer, "digraph {{")?;
        writeln!(writer, "\trankdir=LR")?;

        writeln!(writer)?;
        writeln!(writer, "\tnode [shape=doublecircle, width=1.5, height=1.5]")?;
        for (i, value) in self.accepts.iter() {
            writeln!(
                writer,
                "\t{} [label={:?}]",
                i.as_usize(),
                format!("{}\n{:?}", i.as_usize(), value)
            )?;
        }
        writeln!(writer)?;

        writeln!(
            writer,
            "\tnode [shape=circle, width=.75, height=.75, fixedsize=true]"
        )?;
        for (from, state) in self.states.iter().enumerate() {
            for (term, tos) in state.transitions.iter() {
                for to in tos {
                    writeln!(
                        writer,
                        "\t{} -> {} [label={:?}]",
                        from,
                        to.as_usize(),
                        *term,
                    )?;
                }
            }
            if let Some(tos) = self.epsilon_transitions.get(&StateId::from(from)) {
                for to in tos {
                    writeln!(writer, "\t{} -> {} [label={:?}]", from, to.0, "ε")?;
                }
            }
        }

        writeln!(writer, "}}")?;
        Ok(())
    }
}

impl<T, A> Default for Nfa<T, A> {
    fn default() -> Self {
        Self::new()
    }
}
