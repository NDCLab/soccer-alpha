# ERP Postprocessing Pipeline

**Author:** Marlene Buch  
**Last Updated:** October 11, 2025

## Overview

Postprocessing pipeline for SocCEr ERP data that processes MADE pipeline outputs and creates condition-specific grand averages, difference waves, and electrode cluster analyses for ERN and Pe components.

## Pipeline Components

### Main Scripts

- **`batch_eeg_postprocessing.m`** - coordinates all postprocessing steps
- **`make_grand_averages.m`** - creates condition-specific grand averages with two-stage averaging
- **`compute_difference_waves.m`** - computes difference waves (error - correct)
- **`find_electrode_clusters.m`** - identifies optimal electrode clusters for ERN and Pe
- **`generate_subject_summary_table.m`** - generates subject-level statistics table
- **`write_processing_report.m`** - creates detailed processing summary reports
- **`print_console_summary.m`** - outputs concise console summaries

### Execution Flags

Set in `batch_eeg_postprocessing.m`:

```matlab
run_grand_averages = true;      % step 1: grand average creation
run_difference_waves = true;    % step 2: difference wave computation
run_electrode_clusters = true;  % step 3: electrode cluster identification
```

Each step runs independently and loads existing same-day results when disabled

## Participant Inclusion Criteria

### Two-Tier Inclusion System

Maximizes data retention while maintaining quality standards for primary and secondary research questions

#### Tier 1: Dataset Inclusion (Primary Hypothesis Codes)

Participants must have ≥10 usable trials in **all four** conditions:

- **Code 102** - social invisible flanker error
- **Code 104** - social invisible non-flanker go
- **Code 202** - nonsocial invisible flanker error
- **Code 204** - nonsocial invisible non-flanker go

**Rationale:** critical for testing primary hypotheses regarding error processing in invisible conditions

**Exclusion:** failing any of these four conditions → full dataset exclusion

#### Tier 2: Condition-Specific Inclusion (Secondary Analysis Codes)

Tier 1 participants included in dataset; secondary analyses use only participants with ≥10 trials per condition:

- **Code 111** - social visible correct
- **Code 112** - social visible flanker error
- **Code 113** - social visible non-flanker error
- **Code 211** - nonsocial visible correct
- **Code 212** - nonsocial visible flanker error
- **Code 213** - nonsocial visible non-flanker error

**Result:** variable sample sizes per secondary condition

### Additional Criteria

- **Minimum overall accuracy** - 60% on visible target trials
- **RT lower bound** - 150 ms (trials < 150 ms excluded)
- **RT outlier removal** - trials > 3 SD from condition mean excluded

### Difference Wave Inclusion

Participants included only if ≥10 trials in **both** component conditions

**Example:** diffWave (112 - 111) requires ≥10 trials in both code 112 and code 111

**Result:** each difference wave has specific sample size based on dual-condition thresholds

### Electrode Cluster Analysis

`find_electrode_clusters.m` fully compatible with variable-N difference waves; operates on averaged data (channels × timepoints) independent of subject count; cluster selection based on maximal deflection across visible condition difference waves

## Output Structure

All outputs saved to: `soccer-alpha/derivatives/YYYY-MM-DD_erp-postprocessing/`

### Directory Organization

```
YYYY-MM-DD_erp-postprocessing/
├── grand_averages/
│   ├── grand_averages.mat                    # all grand averages & metadata
│   ├── grand_averages_log_*.txt              # detailed processing log
│   ├── grandAVG_*.set/.fdt                   # grand average files per code
│   └── individual_averages/
│       └── individualAVG_*.set/.fdt          # individual subject averages
├── difference_waves/
│   ├── difference_waves.mat                  # all difference waves & metadata
│   ├── difference_waves_log_*.txt            # computation log
│   └── diffWave_*.set/.fdt                   # difference wave files
├── electrode_clusters/
│   ├── electrode_clusters.mat                # cluster analysis results
│   └── electrode_clusters_summary.txt        # cluster identification report
├── subject_summary_table_*.txt               # comprehensive subject statistics
├── postprocessing_summary_*.txt              # overall processing report
└── console_log_*.txt                         # complete console output
```

### Key Output Files

**grand_averages.mat** contains:
- `grand_averages` - averaged ERP data per condition
- `included_subjects` - cell array of included subject IDs
- `codes` - behavioral codes processed
- `processing_stats` - detailed trial statistics per subject/condition
- `condition_inclusion` - logical matrix for subject × condition inclusion

**difference_waves.mat** contains:
- `difference_waves` - computed difference waves
- `included_subjects` - subjects included in dataset
- `diff_waves_table` - difference wave computation definitions

**grand_averages_log_*.txt** documents:
- processing parameters
- inclusion summary (total, included, excluded)
- detailed trial statistics for all subjects/conditions
- per-code subject lists
- data dimensions and summary statistics

**difference_waves_log_*.txt** documents:
- processing date and included subjects
- per-difference-wave subject counts and lists
- which subjects contributed to each specific difference wave
- data dimensions

**subject_summary_table_*.txt** provides:
- tab-separated table (one row per subject)
- inclusion status and exclusion reasons
- overall accuracy and trial counts
- RT trimming and outlier removal statistics
- final trial counts per condition
- ready for spreadsheet copy-paste

## Interpreting Results

### Sample Size Reporting

Sample sizes vary by condition due to two-tier inclusion:

- **Primary analyses** (102, 104, 202, 204) - all included participants
- **Secondary analyses** (111-113, 211-213) - variable N per condition (consult logs)
- **Difference waves** - variable N per comparison (consult difference_waves_log)

### Programmatic Access to Inclusion Data

```matlab
% load grand averages
load('grand_averages.mat', 'condition_inclusion', 'codes', 'included_subjects');

% check if subject has sufficient data for code 112
subject_id = 'sub-390002';
code_idx = find(codes == 112);
has_code_112 = condition_inclusion(subject_id)(code_idx);
```

## Quality Control

Pipeline automatically tracks and reports:
- trials excluded (multiple key presses, slow responses)
- trials removed (RT < 150 ms)
- trials removed (outliers > 3 SD per condition)
- final usable trial counts per subject/condition

All exclusions documented in processing logs and summary tables

## Pipeline Validation

Verify correct implementation:

1. check console output for inclusion/exclusion messages with specific reasons
2. verify subject counts in log files match expected values
3. confirm primary codes (102, 104, 202, 204) show identical subject lists
4. verify secondary codes show variable subject counts
5. check difference wave subject counts ≤ minimum of component conditions


*Documentation current as of October 11, 2025. For implementation details, refer to inline code comments in MATLAB scripts*