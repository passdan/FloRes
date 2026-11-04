#!/usr/bin/env python3
"""
Normalise an AMR analytic matrix to gene length and sequencing depth (RPKM).

    normalised = (reads * 1e9) / (depth_for_sample * gene_length_bp)

Gene lengths come from a two-column table of MEGARes accession and length in bp.

Sequencing depth is chosen with --depth_basis:

  classified  Column sum of the Kraken analytic matrix. Because
              kraken2_long_to_wide_update.py records reads assigned *directly*
              to each taxon, this sum is the total of classified reads and does
              not double count across taxonomic ranks. This is the default and
              reproduces the original kraken_norm.r behaviour.

  total       The Total column of kraken_unclassifieds.csv, i.e. classified plus
              unclassified reads. Closer to conventional RPKM, but values are not
              comparable with runs normalised on the classified basis.

Behaviour inherited from the original R script:
  - Kraken columns whose name contains "Undetermined" are dropped.
  - Zero counts are dropped before normalisation and written back as 0.
  - Genes absent from the lengths table are dropped (inner join).
  - Samples with no depth value are dropped (inner join).
"""

import argparse
import sys

import pandas as pd

DEPTH_CHOICES = ('classified', 'total')


def parse_args(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('-i', '--input', required=True,
                        help='AMR analytic matrix CSV (genes as rows, samples as columns)')
    parser.add_argument('-k', '--kraken', required=True,
                        help='Kraken analytic matrix CSV')
    parser.add_argument('-l', '--lengths', required=True,
                        help='Tab-separated gene lengths table with columns gene_accession and bp')
    parser.add_argument('-o', '--output', required=True,
                        help='Output CSV path for the normalised matrix')
    parser.add_argument('-b', '--depth_basis', default='classified', choices=DEPTH_CHOICES,
                        help='Denominator for normalisation (default: classified)')
    parser.add_argument('-u', '--unclassifieds', default=None,
                        help='kraken_unclassifieds.csv, required when --depth_basis total')
    args = parser.parse_args(argv)
    if args.depth_basis == 'total' and not args.unclassifieds:
        parser.error('--depth_basis total requires --unclassifieds')
    return args


def read_matrix(path, label):
    """Read a count matrix with the first column as the row index."""
    matrix = pd.read_csv(path, index_col=0)
    if matrix.empty:
        sys.exit(f"ERROR: {label} matrix '{path}' contains no data rows.")
    return matrix.apply(pd.to_numeric, errors='coerce').fillna(0.0)


def classified_depth(kraken_path):
    """Total classified reads per sample, from the Kraken analytic matrix."""
    kraken = read_matrix(kraken_path, 'Kraken')
    kraken = kraken.loc[:, ~kraken.columns.str.contains('Undetermined', case=False)]
    return kraken.sum(axis=0)


def total_depth(unclassifieds_path):
    """Total reads per sample, classified plus unclassified."""
    table = pd.read_csv(unclassifieds_path)
    required = {'SampleID', 'Total'}
    missing = required - set(table.columns)
    if missing:
        sys.exit(f"ERROR: '{unclassifieds_path}' is missing column(s): "
                 f"{', '.join(sorted(missing))}")
    table = table[~table['SampleID'].astype(str).str.contains('Undetermined', case=False)]
    depth = pd.to_numeric(table.set_index('SampleID')['Total'], errors='coerce').fillna(0.0)
    return depth.groupby(level=0).sum()


def read_lengths(path):
    lengths = pd.read_csv(path, sep='\t')
    missing = {'gene_accession', 'bp'} - set(lengths.columns)
    if missing:
        sys.exit(f"ERROR: lengths table '{path}' is missing column(s): "
                 f"{', '.join(sorted(missing))}")
    lengths = lengths[['gene_accession', 'bp']].copy()
    lengths['bp'] = pd.to_numeric(lengths['bp'], errors='coerce')
    return lengths[lengths['bp'] > 0].drop_duplicates(subset='gene_accession')


def main(argv=None):
    args = parse_args(argv)

    amr = read_matrix(args.input, 'AMR')
    lengths = read_lengths(args.lengths)

    if args.depth_basis == 'total':
        depth = total_depth(args.unclassifieds)
    else:
        depth = classified_depth(args.kraken)

    zero_depth = depth[depth <= 0]
    if not zero_depth.empty:
        print(f"WARNING: dropping sample(s) with zero depth: "
              f"{', '.join(map(str, zero_depth.index))}", file=sys.stderr)
    depth = depth[depth > 0]
    if depth.empty:
        sys.exit(f"ERROR: no samples have a non-zero '{args.depth_basis}' depth; "
                 "cannot normalise.")

    known = set(depth.index)
    sample_order = [c for c in amr.columns if c in known]
    dropped = [c for c in amr.columns if c not in known]
    if dropped:
        print(f"WARNING: {len(dropped)} sample(s) in the count matrix have no depth value "
              f"and were dropped: {', '.join(dropped)}", file=sys.stderr)
    if not sample_order:
        sys.exit("ERROR: no samples are shared between the count matrix and the depth source. "
                 "Check that sample names match.")

    long = (amr[sample_order]
            .rename_axis('tax')
            .reset_index()
            .melt(id_vars='tax', var_name='Sample', value_name='reads'))
    long = long[long['reads'] != 0]

    # MEGARes accession is the first field of the pipe-delimited header
    long['gene_accession'] = long['tax'].str.split('|').str[0]

    genes_before = long['gene_accession'].nunique()
    long = long.merge(lengths, on='gene_accession', how='inner')
    genes_after = long['gene_accession'].nunique()
    if genes_after < genes_before:
        print(f"WARNING: {genes_before - genes_after} gene accession(s) were not found in "
              f"'{args.lengths}' and were dropped.", file=sys.stderr)

    long['depth'] = long['Sample'].map(depth)
    long['normalised_reads'] = (long['reads'] * 1e9) / (long['depth'] * long['bp'])

    output = (long.pivot_table(index='tax', columns='Sample',
                               values='normalised_reads', aggfunc='sum')
              .reindex(columns=sample_order)
              .fillna(0.0)
              .rename_axis('gene_accession')
              .rename_axis(None, axis=1)
              .sort_index())

    output.to_csv(args.output)
    print(f"Wrote {output.shape[0]} genes x {output.shape[1]} samples to {args.output} "
          f"(depth basis: {args.depth_basis})")


if __name__ == '__main__':
    main()
