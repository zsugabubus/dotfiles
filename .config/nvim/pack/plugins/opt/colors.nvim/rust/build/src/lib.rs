use std::fs::File;
use std::io::prelude::*;
use std::io::{BufReader, BufWriter};
use std::{env, path::Path};

use automata::regex::{Flags, Regex};
use automata::{dfa::Dfa, nfa::Nfa};

#[derive(Debug, Clone, PartialEq, Copy, Hash)]
pub enum Action {
    Named(u8, u8, u8),
    Xrrggbb,
    Xrgb,
    XXrrggbb,
    XXrgb,
    HslFn,
    HslaFn,
    HwbFn,
    LabFn,
    LchFn,
    OklchFn,
    OklabFn,
    RgbFn,
    RgbaFn,
    Color,
    BrightColor,
    Colour,
}

pub fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:warning=MESSAGE");

    let out_dir = env::var("OUT_DIR").unwrap();
    let path = Path::new(&out_dir).join("generated.rs");
    let mut writer = BufWriter::new(File::create(path).unwrap());

    generate(&mut writer);
}

fn get_named_colors() -> Vec<(String, u32)> {
    ["data/named.csv", "data/tailwind.csv"]
        .iter()
        .flat_map(|file| {
            println!("cargo:rerun-if-changed={file}");

            BufReader::new(File::open(file).unwrap())
                .lines()
                .map(|line| {
                    let line = line.unwrap();
                    let (name, s) = line.split_once(',').expect("comma");
                    let s = s.strip_prefix('#').expect("#");
                    let color = u32::from_str_radix(s, 16).expect("hex color");
                    (name.to_string(), color)
                })
        })
        .collect()
}

fn generate(mut writer: impl Write) {
    let mut nfa = Nfa::new();
    let start = nfa.new_state();

    let mut re = Regex::new(&mut nfa);
    let flags = {
        let mut flags = Flags::new();
        flags.caseless(true);
        flags
    };

    let named = get_named_colors();

    writeln!(writer, "#[cfg(test)]").unwrap();
    writeln!(
        writer,
        "pub static NAMED_COLORS: [(&str, u32); {}] = [",
        named.len()
    )
    .unwrap();
    for (name, color) in &named {
        writeln!(writer, "({:?}, {}),", name, color).unwrap();
    }
    writeln!(writer, "];").unwrap();

    for (name, color) in named {
        let state = re.insert_literal(start, name, &flags);
        let [_, r, g, b] = color.to_be_bytes();
        re.set_accept(state, Action::Named(r, g, b));
    }

    for (name, action) in [
        ("hsl(", Action::HslFn),
        ("hsla(", Action::HslaFn),
        ("hwb(", Action::HwbFn),
        ("lab(", Action::LabFn),
        ("lch(", Action::LchFn),
        ("oklab(", Action::OklabFn),
        ("oklch(", Action::OklchFn),
        ("rgb(", Action::RgbFn),
        ("rgba(", Action::RgbaFn),
        ("color[0-9]", Action::Color),
        ("brightcolor[0-9]", Action::BrightColor),
        ("colour[0-9]", Action::Colour),
        ("#[0-9a-f]{3}", Action::Xrgb),
        ("#[0-9a-f]{6}", Action::Xrrggbb),
        ("0x[0-9a-f]{3}", Action::XXrgb),
        ("0x[0-9a-f]{6}", Action::XXrrggbb),
    ] {
        let state = re.insert_pattern(start, name, &flags).unwrap();
        re.set_accept(state, action);
    }

    /*
    if false {
        let dot = BufWriter::new(File::create("../../target/a.dot").unwrap());
        // Aho-Cora?
        let mut nfa = Nfa::new();

        let start = nfa.new_state();

        for s in ["aaabc", "abd"] {
            let word_start = nfa.new_state();
            let end = nfa.new_accept_state(s.to_owned());

            let from = s.as_bytes().iter().copied().fold(word_start, |from, via| {
                let to = nfa.new_state();
                nfa.add_epsilon_transition(to, start);
                nfa.insert_transition(from, via, to);
                to
            });
            nfa.add_epsilon_transition(from, end);
            nfa.add_epsilon_transition(start, word_start);
        }
        nfa.write_dot(dot).unwrap();
    }
    */

    let (mut dfa, start) = Dfa::from_nfa(&nfa, start, |_, _| None).unwrap();

    let mut starts = [start];
    dfa.minimize(&mut starts);
    let [start] = starts;

    // let dot = BufWriter::new(File::create("target/a.dot").unwrap());
    // dfa.write_dot(dot).unwrap();

    dfa.write_config(writer, "MyDfa", 256, start).unwrap();

    // println!("{:?}", dfa.collect_terminals(start, Some(3)).len());
    // todo!();
    assert_eq!(dfa.shortest_word_len(start, None).unwrap(), 3);

    const N: usize = 3;
    let mut builder = teddy::TeddyBuilder::<N, teddy::LowNibbleConfig<N>>::new(3, 16, 8);

    let mut v = Vec::new();
    for word in dfa.words_exact(start, 3) {
        v.clear();
        v.extend(word.iter());
        builder.push(&v);
    }
    builder.build();
}
