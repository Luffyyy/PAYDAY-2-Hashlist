use std::io::*;
use std::fs::*;

fn main() {
    let mut lines = Vec::<String>::with_capacity(1000000);

    let mut args = std::env::args().skip(1);
    let outname = match args.next() {
        Some(f) => f,
        None => {
            eprintln!("Usage: dedup outfile existing_hashlist [additions...]");
            eprintln!("existing_hashlist will not be sorted, the additions will");
            std::process::exit(1);
        }
    };

    let first_filename = match args.next() {
        Some(f) => f,
        None => return
    };

    lines.extend(get_lines(&first_filename));

    let first_new = lines.len();

    for newf in args {
        lines.extend(get_lines(&newf));
    }

    if lines.len() > first_new {
        (&mut lines[first_new..]).sort();
    }

    let mut seen = std::collections::HashSet::<&str>::with_capacity(lines.len());
    let outfile_ub = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(&outname)
        .unwrap();
    let mut outfile = BufWriter::new(outfile_ub);
    for i in lines.iter() {
        if seen.insert(i) {
            write!(outfile, "{}\n", i).unwrap();
        }
    }

}

fn get_lines(filename: &str) -> impl Iterator<Item=String> {
    let unbuf_reader = File::open(filename).unwrap();
    let reader = BufReader::new(unbuf_reader);

    reader.lines().map(|i| i.unwrap())
}
