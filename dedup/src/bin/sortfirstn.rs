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
    lines: usize
}

fn main() {
    let opt = Opt::from_args();

    let mut input = get_string(&opt.input_path);
    let mut lines: Vec<String> = get_lines(&opt.input_path).collect();

    let (block, rest) = lines.split_at(opt.lines);

    let mut sort_tree = OwningSortNode { data: None, kids: default() };
    for i in block.iter() {
        let mut curr = &mut sort_tree;
        for seg in i.split('/').map(OwnedSegment::new) {
            curr = match curr.kids.entry(seg) {
                Entry::Occupied(e) => e.into_mut(),
                Entry::Vacant(v) => v.insert(OwningSortNode{data: None, kids: default()})
            }
        }
        curr.data = Some(i.into())
    }
    let mut sorted = Vec::<String>::with_capacity(block.len());
    fill_from_sortnode(&mut sorted, &mut sort_tree);
    let outfile_ub = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&opt.output_path)
        .unwrap();
    let mut outfile = BufWriter::new(outfile_ub);
    let write_iter = sorted.iter()
        .chain(rest.iter());
    for i in write_iter {
        write!(outfile, "{}\n", i).unwrap();
    }

}

fn get_string(filename: &str) -> String {
    std::fs::read_to_string(filename).unwrap()
}

fn get_lines(filename: &str) -> impl Iterator<Item=String> {
    let unbuf_reader = File::open(filename).unwrap();
    let reader = BufReader::new(unbuf_reader);

    reader.lines().map(|i| i.unwrap())
}

fn fill_from_sortnode(dest: &mut Vec<String>, src: &mut OwningSortNode) {
    if let Some(d) = src.data.take() {
        dest.push(d)
    }
    for (_, i) in src.kids.iter_mut() {
        fill_from_sortnode(dest, i);
    }
    src.kids.clear()
}

#[derive(Debug)]
struct OwningSortNode {
    data: Option<String>,
    kids: std::collections::BTreeMap<OwnedSegment, OwningSortNode>
}

#[derive(PartialEq, Eq, PartialOrd, Ord, Clone, Debug)]
struct OwnedSegment(Option<u128>, String, Option<u128>, String);
impl OwnedSegment {
    fn new(text: &str) -> OwnedSegment {
        lazy_static! {
            static ref RE: Regex = Regex::new(r"^([0-9]{0,38})(.*?)([0-9]{0,38})$").unwrap();
        };

        let m = RE.captures(text).unwrap();
        let ld = parse_num128(&m[1]);
        let t = m[2].to_lowercase();
        let rd = parse_num128(&m[3]);
        OwnedSegment(ld, t, rd, m[2].into())
    }
}

fn parse_num128(text: &str) -> Option<u128> {
    if text.len() == 0 { return None; }
    Some(u128::from_str_radix(text, 10).unwrap())
}