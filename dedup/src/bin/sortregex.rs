#![feature(iter_intersperse)]
#![feature(default_free_fn)]

use std::collections::btree_map::Entry;
use std::default::default;
use std::io::*;
use std::fs::*;

use lazy_static::lazy_static;
use regex::*;
use structopt::StructOpt;

#[derive(StructOpt, Debug)]
struct Opt {
    input_path: String,
    output_path: String,
    regex: Regex
}

fn main() {
    let opt = Opt::from_args();

    let mut before = Vec::<String>::with_capacity(1000000);
    let mut block = Vec::<String>::with_capacity(1000000);
    let mut after = Vec::<String>::with_capacity(1000000);

    let lines = get_lines(&opt.input_path);
    
    for line in lines {
        if opt.regex.is_match(&line) {
            block.push(line)
        }
        else if block.len() == 0 {
            before.push(line)
        }
        else {
            after.push(line)
        }
    }

    let mut sort_tree = SortNode { data: None, kids: default() };
    for i in block.iter() {
        let mut curr = &mut sort_tree;
        for seg in i.split('/').map(Segment::new) {
            curr = match curr.kids.entry(seg) {
                Entry::Occupied(e) => e.into_mut(),
                Entry::Vacant(v) => v.insert(SortNode{data: None, kids: default()})
            }
        }
        curr.data = Some(i.into())
    }
    
    block.clear();

    fill_from_sortnode(&mut block, &mut sort_tree);

    let outfile_ub = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&opt.output_path)
        .unwrap();
    let mut outfile = BufWriter::new(outfile_ub);
    let write_iter = before.iter()
        .chain(block.iter())
        .chain(after.iter());
    for i in write_iter {
        write!(outfile, "{}\n", i).unwrap();
    }
}

fn get_lines(filename: &str) -> impl Iterator<Item=String> {
    let unbuf_reader = File::open(filename).unwrap();
    let reader = BufReader::new(unbuf_reader);

    reader.lines().map(|i| i.unwrap())
}

fn fill_from_sortnode(dest: &mut Vec<String>, src: &mut SortNode) {
    if let Some(d) = src.data.take() {
        dest.push(d)
    }
    for (_, i) in src.kids.iter_mut() {
        fill_from_sortnode(dest, i);
    }
    src.kids.clear()
}

#[derive(Debug)]
struct SortNode {
    data: Option<String>,
    kids: std::collections::BTreeMap<Segment, SortNode>
}

#[derive(PartialEq, Eq, PartialOrd, Ord, Clone, Debug)]
struct Segment(Option<u128>, String, Option<u128>);
impl Segment {
    fn new(text: &str) -> Segment {
        lazy_static! {
            static ref RE: Regex = Regex::new(r"^([0-9]*)(.*?)([0-9]*)$").unwrap();
        };

        let m = RE.captures(text).unwrap();
        let ld = parse_num(&m[1]);
        let t = String::from(&m[2]);
        let rd = parse_num(&m[3]);
        Segment(ld, t, rd)
    }
}

fn parse_num(text: &str) -> Option<u128> {
    if text.len() == 0 { return None; }
    Some(u128::from_str_radix(text, 10).unwrap())
}