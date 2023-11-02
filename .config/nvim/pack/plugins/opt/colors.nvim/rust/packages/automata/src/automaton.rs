use std::fmt::Debug;

pub type Terminal = usize;

macro_rules! automaton_impl {
    (
        $vis:vis struct StateId;
    ) => {
        /// State ID.
        #[derive(Clone, Copy, Eq, PartialEq, Ord, PartialOrd, Hash, Debug)]
        #[repr(transparent)]
        $vis struct StateId(u32);

        impl StateId {
            pub fn from(i: usize) -> Self {
                Self(i.try_into().unwrap())
            }

            #[inline]
            pub fn as_usize(&self) -> usize {
                self.0 as usize
            }
        }
    }
}

pub(crate) use automaton_impl;

pub trait Accept: PartialEq + Debug + Clone {}

impl<T> Accept for T where T: PartialEq + Debug + Clone {}
