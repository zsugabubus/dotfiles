use std::collections::{HashMap, HashSet};
use std::fmt::Debug;
use std::io::Write;
use std::iter::Iterator;

use crate::automaton::*;
use crate::dfa::Dfa;

automaton_impl! { pub struct StateId; }

#[derive(Debug)]
pub(crate) struct State {
    pub(crate) transitions: HashMap<Terminal, HashSet<StateId>>,
}

impl State {
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
pub struct Nfa<A>
where
    A: Accept,
{
    pub(crate) states: Vec<State>,
    pub(crate) epsilon_transitions: HashMap<StateId, HashSet<StateId>>,
    pub(crate) accepts: HashMap<StateId, A>,
}

impl<A> Nfa<A>
where
    A: Accept,
{
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
    pub fn from_dfa(dfa: &Dfa<A>) -> Self {
        let mut nfa = Self::new();
        nfa.extend_from_dfa(dfa);
        nfa
    }

    fn extend_from_dfa(&mut self, src: &Dfa<A>) {
        let base = self.new_state_many(src.states.len());

        for (from_id, from) in src.states.iter().enumerate() {
            for (term, to) in from.transitions.iter() {
                self.insert_transition(
                    StateId::from(from_id + base),
                    *term,
                    StateId::from(to.as_usize() + base),
                );
            }
        }

        for (state_id, value) in src.accepts.iter() {
            self.set_accept(StateId::from(state_id.as_usize() + base), value.clone());
        }
    }

    pub fn rev(&self) -> Self {
        let mut nfa = Self::new();
        nfa.extend_from_rev_nfa(self);
        nfa
    }

    fn extend_from_rev_nfa(&mut self, src: &Self) {
        let base = self.new_state_many(src.states.len());

        for (from_id, from) in src.states.iter().enumerate() {
            for (term, tos) in from.transitions.iter() {
                for to in tos {
                    self.insert_transition(
                        StateId::from(to.as_usize() + base),
                        *term,
                        StateId::from(from_id + base),
                    );
                }
            }
        }

        for (from_id, tos) in src.epsilon_transitions.iter() {
            for to in tos {
                self.insert_epsilon_transition(
                    StateId::from(to.as_usize() + base),
                    StateId::from(from_id.as_usize() + base),
                );
            }
        }

        for (state_id, value) in src.accepts.iter() {
            self.set_accept(StateId::from(state_id.as_usize() + base), value.clone());
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
    pub fn insert_transition<T: Into<Terminal>>(&mut self, from: StateId, via: T, to: StateId) {
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
    pub fn write_dot<W: Write>(&self, mut writer: W) -> std::io::Result<()> {
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
            for (term, tos) in from.transitions.iter() {
                for to in tos {
                    writeln!(
                        writer,
                        "\t{} -> {} [label={:?}]",
                        from_id,
                        to.0,
                        (*term as u8 as char).to_string()
                    )?;
                }
            }
            if let Some(eps_to) = self.epsilon_transitions.get(&StateId::from(from_id)) {
                for to in eps_to {
                    writeln!(writer, "\t{} -> {} [label={:?}]", from_id, to.0, "ε")?;
                }
            }
        }

        writeln!(writer, "}}")?;
        Ok(())
    }
}

impl<A> Default for Nfa<A>
where
    A: Accept,
{
    fn default() -> Self {
        Self::new()
    }
}
