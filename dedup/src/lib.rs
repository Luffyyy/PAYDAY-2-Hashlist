use std::collections::{BTreeMap, btree_map::Entry, btree_map::Iter as BTreeIter};

use lazy_static::lazy_static;
use regex::*;
use unicase::UniCase;

#[derive(Debug, Default)]
pub struct SortNode<'s> {
    data: Option<&'s str>,
    kids: BTreeMap<Segment<'s>, SortNode<'s>>
}
impl<'s> SortNode<'s> {
    pub fn insert(&mut self, data: &'s str) {
        let mut curr = self;
        for seg in data.split('/').map(Segment::new) {
            curr = match curr.kids.entry(seg) {
                Entry::Occupied(e) => e.into_mut(),
                Entry::Vacant(v) => v.insert(SortNode{data: None, kids: Default::default()})
            }
        }
        curr.data = Some(data);
    }

    pub fn iter<'b>(&'b self) -> SortNodeDepthTraverser<'s, 'b> {
        SortNodeDepthTraverser::new(&self)
    }

    pub fn is_empty(&self) -> bool {
        self.kids.is_empty()
    }
}

pub struct SortNodeDepthTraverser<'s, 'b> {
    stack: Vec<(Option<&'s str>, BTreeIter<'b, Segment<'s>, SortNode<'s>>)>
}
impl<'s, 'b> SortNodeDepthTraverser<'s, 'b> {
    fn new(node: &'b SortNode<'s>) -> Self {
        Self {
            stack: vec![ (node.data, node.kids.iter()) ]
        }
    }

    fn step(&mut self) -> (bool, Option<&'s str>) {
        if let Some(curr) = self.stack.last_mut() {
            if let Some(s) = curr.0.take() {
                (true, Some(s))
            }
            else if let Some((_, child_node)) = curr.1.next() {
                self.stack.push((child_node.data, child_node.kids.iter()));
                (true, None)
            }
            else {
                self.stack.pop();
                (true, None)
            }
        }
        else {
            (false, None)
        }
    }
}

impl<'s, 'b> Iterator for SortNodeDepthTraverser<'s, 'b> {
    type Item = &'s str;
    fn next(&mut self) -> Option<Self::Item> {
        loop {
            match self.step() {
                (true, Some(s)) => return Some(s),
                (true, None) => (),
                (false, _) => return None
            }
        }
    }
}

#[derive(PartialEq, Eq, PartialOrd, Ord, Clone, Copy, Debug)]
pub struct Segment<'s>(Option<u32>, UniCase<&'s str>, Option<u32>, &'s str);
impl<'s> Segment<'s> {
    pub fn new(text: &'s str) -> Self {
        lazy_static! {
            static ref RE: Regex = Regex::new(r"^([0-9]{0,9})(.*?)([0-9]{0,9})$").unwrap();
        };

        let m = RE.captures(text).unwrap();
        let ld = parse_num32(&m[1]);
        let t = m.get(2).unwrap().as_str();
        let rd = parse_num32(&m[3]);
        Segment(ld, UniCase::new(t), rd, t)
    }
}

fn parse_num32(text: &str) -> Option<u32> {
    if text.len() == 0 { return None; }
    Some(u32::from_str_radix(text, 10).unwrap())
}