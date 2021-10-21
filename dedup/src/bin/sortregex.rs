#![feature(iter_intersperse)]
#![feature(default_free_fn)]

use std::io::*;
use std::fs::*;

use regex::*;
use structopt::StructOpt;

use dedup::SortNode;

#[derive(StructOpt, Debug)]
struct Opt {
    input_path: String,
    output_path: String,
    regex: Regex
}

fn main() {
    let opt = Opt::from_args();

    let input = get_string(&opt.input_path);
    let mut before = Vec::<&str>::with_capacity(1000000);
    let mut block = SortNode::default();
    let mut after = Vec::<&str>::with_capacity(1000000);

    for line in input.lines() {
        if opt.regex.is_match(line) {
            block.insert(line)
        }
        else if !block.is_empty() {
            before.push(line)
        }
        else {
            after.push(line)
        }
    }

    let outfile_ub = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&opt.output_path)
        .unwrap();
    let mut outfile = BufWriter::new(outfile_ub);
    let write_iter = before.into_iter()
        .chain(block.iter())
        .chain(after.into_iter());
    for i in write_iter {
        write!(outfile, "{}\n", i).unwrap();
    }
}

fn get_string(filename: &str) -> String {
    std::fs::read_to_string(filename).unwrap()
}