#!/usr/bin/env python3
"""Snapshot the production suite and generate an isolated packed variant."""
import hashlib
import json
import argparse
from pathlib import Path
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]


def replace_once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def prepare(alignment='blocks'):
    files = list(ROOT.glob('*.bend')) + list((ROOT / 'lib').glob('*.bend'))
    files += [ROOT / 'run.py'] + list((ROOT / 'tests').rglob('*'))
    files = [p for p in files if p.is_file() and '__pycache__' not in p.parts]
    hashes = {}
    for p in files:
        relative = p.relative_to(ROOT)
        hashes[str(relative)] = hashlib.sha256(p.read_bytes()).hexdigest()
        for variant in ('baseline', 'packed'):
            out = HERE / variant / relative
            out.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(p, out)
    (HERE / 'source_hashes.json').write_text(json.dumps(hashes, indent=2) + '\n')
    for name in ('packing.bend', 'alignment.bend'):
        source = 'alignment_cursor.bend' if name == 'alignment.bend' and alignment == 'cursor' else name
        shutil.copyfile(HERE / source, HERE / 'packed/lib' / name)

    path = HERE / 'packed/lib/common.bend'
    text = path.read_text()
    text = replace_once(text, 'import Base', 'import Base\nimport ./packing.bend as P\nimport ./alignment.bend as A')
    text = replace_once(text, 'type Record is Data:', 'type Record is Type:')
    text = replace_once(text, 'bases: String, width: U32}', 'bases: P.Sequence, width: U32}')
    start = text.index('law record_copy:')
    end = text.index('law records_copy_loop:', start)
    text = text[:start] + '''def record_copy(item: Record) -> Record & Record:
  match item:
    case Record{+index, +label, bases, +width}:
      apply(P.Sequence & P.Sequence, Record & Record,
        \\{Tuple: a => b => (Record{index, label, a, width}, Record{index, label, b, width})},
        P.copy(bases))

''' + text[end:]
    start = text.index('law alignment_initial:')
    end = text.index('law similarity_both:', start)
    text = text[:start] + '''def sequence_copy(sequence: P.Sequence) -> P.Sequence & P.Sequence:
  P.copy(sequence)

def sequence_reverse(sequence: P.Sequence, +length: U32) -> P.Sequence:
  P.pack(reverse_complement(P.unpack(sequence), ""), length)

def sequence_text(sequence: P.Sequence) -> String:
  P.unpack(sequence)

def alignment_identity(left: P.Sequence, right: P.Sequence, left_size: U32,
                       right_size: U32, shorter: Bool) -> U32:
  A.identity(left, right, left_size, right_size, shorter)

''' + text[end:]
    start = text.index('law similarity_both:')
    end = text.index('# Fasta', start)
    region = text[start:end].replace('String', 'P.Sequence').replace('string_copy(', 'sequence_copy(')
    region = region.replace('reverse_complement(r2, "")', 'sequence_reverse(r2, rn)')
    text = text[:start] + region + text[end:]
    text = replace_once(text, 'Record{size, label, string_reverse(bases, ""), length}',
                        'Record{size, label, P.pack(string_reverse(bases, ""), length), length}')
    text = replace_once(text, 'fasta_wrap(bases, 0, "")', 'fasta_wrap(P.unpack(bases), 0, "")')
    text = replace_once(text, 'law fasta_read:\n  for alphabet:', 'law fasta_read:\n  for +alphabet:')
    # This experiment is deliberately DNA/RNA-only; never silently recode the
    # baseline's undocumented direct-IO protein alphabet into four-bit DNA.
    text = replace_once(text, 'result_unwrap(Dataset, fasta_parse(text, alphabet))',
                        '''branch(IO(Dataset), U32.is_eq(alphabet, 1), \\{
      True: result_unwrap(Dataset, fasta_parse(text, alphabet))
      False: IO.die(Dataset, 2, "packed experiment supports DNA/RNA only")
    })''')
    path.write_text(text)

    # Preserve CD-HIT's exact ASCII 3-mer hash and filter decisions. Decode only
    # for its existing filter; its expensive alignment consumes packed words.
    path = HERE / 'packed/cd_hit.bend'
    text = path.read_text().replace('import Base', 'import Base\nimport ./lib/packing.bend as P', 1)
    start = text.index('law word_filter:')
    text = text[:start] + text[start:].replace('String', 'P.Sequence').replace('C.string_copy(', 'C.sequence_copy(')
    text = text.replace('words_count(left,', 'words_count(C.sequence_text(left),')
    text = text.replace('words_count(right,', 'words_count(C.sequence_text(right),')
    text = text.replace('C.reverse_complement(r2, "")', 'C.sequence_reverse(r2, right_size)')
    path.write_text(text)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--alignment', choices=('blocks', 'cursor'), default='blocks')
    prepare(parser.parse_args().alignment)
