#!/usr/bin/env perl
=pod
  Unit Tests for GNU Datamash - perform simple calculation on input data

   Copyright (C) 2013,2014 Assaf Gordon <assafgordon@gmail.com>

   This file is part of GNU Datamash.

   GNU Datamash is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   GNU Datamash is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNU Datamash.  If not, see <http://www.gnu.org/licenses/>.

   Written by Assaf Gordon.
=cut
use strict;
use warnings;

# Until a better way comes along to auto-use Coreutils Perl modules
# as in the coreutils' autotools system.
use Coreutils;
use CuSkip;
use CuTmpdir qw(datamash);

(my $program_name = $0) =~ s|.*/||;
my $prog = 'datamash';

## Portability hack
## Check if the system's sort supports stable sorting ('-s').
## If it doesn't - skip some tests
my $rc = system("sort -s < /dev/null > /dev/null 2>/dev/null");
die "testing framework failure: failed to execute sort -s"
  if ( ($rc == -1) || ($rc & 127) );
my $sort_exit_code = ($rc >> 8);
my $have_stable_sort = ($sort_exit_code==0);


# TODO: add localization tests with "grouping"
# Turn off localization of executable's output.
@ENV{qw(LANGUAGE LANG LC_ALL)} = ('C') x 3;

# note: '5' appears twice
my $in1 = join("\n", qw/1 2 3 4 5 6 7 5 8 9 10/) . "\n";

# Mix of spaces and tabs
my $in2 = "1 2\t 3\n" .
          "4\t5 6\n";
my $in_minmax = join("\n", qw/5 90 -7e2 3 200 0.1e-3 42/) . "\n";

# Lots of whitespace
my $in3 = "1 \t  2\t\t\t3\t\t\n" .
          "4\t\t\t5   6\n";

my $in_g1=<<'EOF';
A 100
A 10
A 50
A 35
EOF

my $in_g2=<<'EOF';
A 100
A 10
A 50
A 35
B 66
B 77
B 55
EOF
my $in_g2_tab = $in_g2;
$in_g2_tab =~ s/ /\t/gms;

my $in_g3=<<'EOF';
A 3 W
A 5 W
A 7 W
A 11 X
A 13 X
B 17 Y
B 19 Z
C 23 Z
EOF

my $in_g4=<<'EOF';
A 5
K 6
P 2
EOF

my $in_hdr1=<<'EOF';
x y z
A 1 10
A 2 10
A 3 10
A 4 10
A 4 10
B 5 10
B 6 20
B 7 30
C 8 11
C 9 22
C 1 33
C 2 44
EOF

# Same data, different field separator
my $in_hdr2=<<'EOF';
x:y:z
A:3:W
A:5:W
A:7:W
A:11:X
A:13:X
B:17:Y
B:19:Z
C:23:Z
EOF

my $in_cnt_uniq1=<<'EOF';
x y
A 1
A 2
A 1
A 2
A 1
A 2
B 1
B 2
B 1
B 2
B 1
B 2
EOF

# When using whitespace, the second column is 1,2,3.
# When using Tab, the second column is 10,20,30.
my $in_tab1=<<"EOF";
A 1\t10
B 2\t20
C 3\t30
EOF

# When using whitespace, this input has fours columns.
# When using Tab, this input has three columns.
# The lines are unsorted. When sorted by the second column,
# The output will depend on whether using whitespace or TAB.
my $in_sort1=<<"EOF";
! A\tx\t1
@ B\tk\t2
# D\tj\t3
@ B\tx\t5
# C\tj\t4
^ C\tg\t6
EOF

# This (sorted) input will return different results based on case-sensitivity
my $in_case_sorted=<<'EOF';
a X 1
a x 3
A X 2
A x 5
b Y 4
B Y 6
EOF
#
# This (unsorted) input will return different results based on case-sensitivity
my $in_case_unsorted=<<'EOF';
a X 1
A X 2
a x 3
b Y 4
A x 5
B Y 6
EOF

## NUL as end-of-line character
my $in_nul1="A 1\x00A 2\x00B 3\x00B 4\x00";

## Invalid numeric input
my $in_invalid_num1=<<'EOF';
A 1
A 2
B 3a
B 4
EOF

my $in_precision1=<<'EOF';
0.3
3e10
EOF

my $in_precision2=<<'EOF';
0.3
3e14
EOF

my $in_large_buffer1 =
"A 1\n" .
"A " . "FooBar" x 512 . "\n" .
"A " . "FooBar" x 1024 . "\n" .
"A 2\n" .
"B 3\n" .
"B " . "FooBar" x 1024 . "\n" .
"B " . "FooBar" x 512 . "\n" .
"B 4\n";

my $in_large_buffer2 =
"A " . "FooBar" x 100 . "\n" .
"A " . "FooBar" x 200 . "\n" .
"B " . "FooBar" x 300 . "\n" .
"B " . "FooBar" x 400 . "\n" ;

my $out_large_buffer_first =
"A " . "FooBar" x 100 . "\n" .
"B " . "FooBar" x 300 . "\n" ;

my $out_large_buffer_last =
"A " . "FooBar" x 200 . "\n" .
"B " . "FooBar" x 400 . "\n" ;


my @Tests =
(
  # Basic tests, single field, single group, default everything
  ['b1', 'count 1' ,    {IN_PIPE=>$in1},  {OUT => "11\n"}],
  ['b2', 'sum 1',       {IN_PIPE=>$in1},  {OUT => "60\n"}],
  ['b3', 'min 1',       {IN_PIPE=>$in1},  {OUT => "1\n"}],
  ['b4', 'max 1',       {IN_PIPE=>$in1},  {OUT => "10\n"}],
  ['b5', 'absmin 1',    {IN_PIPE=>$in1},  {OUT => "1\n"}],
  ['b6', 'absmax 1',    {IN_PIPE=>$in1},  {OUT => "10\n"}],
  ['b8', 'median 1',    {IN_PIPE=>$in1},  {OUT => "5\n"}],
  ['b9', 'mode 1',      {IN_PIPE=>$in1},  {OUT => "5\n"}],
  ['b10', 'antimode 1', {IN_PIPE=>$in1},  {OUT => "1\n"}],
  ['b11', 'unique 1',   {IN_PIPE=>$in1},  {OUT => "1,10,2,3,4,5,6,7,8,9\n"}],
  ['b13', 'collapse 1', {IN_PIPE=>$in1},  {OUT => "1,2,3,4,5,6,7,5,8,9,10\n"}],

  # on a different architecture, would printf(%Lg) print something else?
  # Use OUT_SUBST to trim output to 1.3 digits
  ['b14', 'mean 1',     {IN_PIPE=>$in1},  {OUT => "5.454\n"},
	  {OUT_SUBST=>'s/^(\d\.\d{3}).*/\1/'}],
  ['b15', 'pstdev 1',   {IN_PIPE=>$in1},  {OUT => "2.742\n"},
	  {OUT_SUBST=>'s/^(\d\.\d{3}).*/\1/'}],
  ['b16', 'sstdev 1',   {IN_PIPE=>$in1},  {OUT => "2.876\n"},
	  {OUT_SUBST=>'s/^(\d\.\d{3}).*/\1/'}],
  ['b17', 'pvar 1',     {IN_PIPE=>$in1},  {OUT => "7.520\n"},
	  {OUT_SUBST=>'s/^(\d\.\d{3}).*/\1/'}],
  ['b18', 'svar 1',     {IN_PIPE=>$in1},  {OUT => "8.272\n"},
	  {OUT_SUBST=>'s/^(\d\.\d{3}).*/\1/'}],
  ['b19', 'countunique 1', {IN_PIPE=>$in1}, {OUT => "10\n"}],
  ['b20', 'first 1',    {IN_PIPE=>$in1},  {OUT => "1\n"}],
  ['b21', 'last 1',     {IN_PIPE=>$in1},  {OUT => "10\n"}],
  # This test just ensures the 'rand' operation is functioning.
  # It does not verify randomness (see datamash-rand.sh test for that).
  ['b22', 'rand 1',     {IN_PIPE=>$in1},  {OUT => "\n"},
	  {OUT_SUBST=>'s/[0-9]+//'}],



  ## Some error checkings
  ['e1',  'sum',  {IN_PIPE=>""}, {EXIT=>1},
	  {ERR=>"$prog: missing field number after operation 'sum'\n"}],
  ['e2',  'foobar',  {IN_PIPE=>""}, {EXIT=>1},
	  {ERR=>"$prog: invalid operation 'foobar'\n"}],
  ['e3',  '',  {IN_PIPE=>""}, {EXIT=>1},
	  {ERR=>"$prog: missing operation specifiers\n" .
		  "Try '$prog --help' for more information.\n"}],
  ['e4',  'sum 1' ,  {IN_PIPE=>"a\n"}, {EXIT=>1},
	  {ERR=>"$prog: invalid numeric input in line 1 field 1: 'a'\n"}],
  ['e5',  '-g 4, sum 1' ,  {IN_PIPE=>"a\n"}, {EXIT=>1},
	  {ERR=>"$prog: invalid field value for grouping ''\n"}],
  ['e6',  '-g 4,x sum 1' ,  {IN_PIPE=>"a\n"}, {EXIT=>1},
	  {ERR=>"$prog: invalid field value for grouping 'x'\n"}],
  ['e7',  '-g ,x sum 1' ,  {IN_PIPE=>"a\n"}, {EXIT=>1},
	  {ERR=>"$prog: invalid field value for grouping ',x'\n"}],
  ['e8',  '-g 1,0 sum 1' ,  {IN_PIPE=>"a\n"}, {EXIT=>1},
	  {ERR=>"$prog: invalid field value (zero) for grouping\n"}],
  ['e9',  '-g 1X0 sum 1' ,  {IN_PIPE=>"a\n"}, {EXIT=>1},
	  {ERR=>"$prog: invalid grouping parameter 'X0'\n"}],
  ['e10',  '-g 1 -t XX sum 1' ,  {IN_PIPE=>"a\n"}, {EXIT=>1},
	  {ERR=>"$prog: the delimiter must be a single character\n"}],
  ['e11',  '--foobar' ,  {IN_PIPE=>"a\n"}, {EXIT=>1},
	  {ERR=>"$prog: unrecognized option foobar\n" .
                "Try '$prog --help' for more information.\n"},
          # This ERR_SUBST is needed because on some systems (e.g. OpenBSD),
          # The error message from 'getopt_long' is slightly different than GNU libc's.
          {ERR_SUBST=>'s/(unknown|unrecognized) option.*(foobar).*/unrecognized option $2/'}],
  ['e12',  '-t" " -H unique 4' ,  {IN_PIPE=>$in_hdr1}, {EXIT=>1},
	  {ERR=>"$prog: not enough input fields (field 4 requested, input has only 3 fields)\n"}],
  ['e13',  'sum 6' ,  {IN_PIPE=>$in_g3}, {EXIT=>1},
	  {ERR=>"$prog: invalid numeric input in line 1 field 6: ''\n"}],
  ['e14',  '--header-in -t: sum 6' ,  {IN_PIPE=>$in_hdr2}, {EXIT=>1},
	  {ERR=>"$prog: invalid numeric input in line 2 field 6: ''\n"}],
  ['e15',  'sum foo' ,  {IN_PIPE=>"a"}, {EXIT=>1},
	  {ERR=>"$prog: invalid column 'foo' for operation 'sum'\n"}],
  ['e16',  '-t" " sum 2' ,  {IN_PIPE=>$in_invalid_num1}, {EXIT=>1},
	  {ERR=>"$prog: invalid numeric input in line 3 field 2: '3a'\n"}],

  # No newline at the end of the lines
  ['nl1', 'sum 1', {IN_PIPE=>"99"}, {OUT=>"99\n"}],
  ['nl2', 'sum 1', {IN_PIPE=>"1\n99"}, {OUT=>"100\n"}],

  # empty input = empty output, regardless of options
  [ 'emp1', 'count 1', {IN_PIPE=>""}, {OUT=>""}],
  [ 'emp2', '--full count 2', {IN_PIPE=>""},{OUT=>""}],
  [ 'emp3', '--header-in count 2', {IN_PIPE=>""},{OUT=>""}],
  [ 'emp4', '--header-out count 2', {IN_PIPE=>""},{OUT=>""}],
  [ 'emp5', '--full --header-in count 2', {IN_PIPE=>""},{OUT=>""}],
  [ 'emp6', '--full --header-out count 2', {IN_PIPE=>""},{OUT=>""}],
  [ 'emp7', '--full --header-in --header-out count 2', {IN_PIPE=>""},{OUT=>""}],
  [ 'emp8', '-g3,4 --full --header-in --header-out count 2', {IN_PIPE=>""},{OUT=>""}],
  [ 'emp9', '-g3 count 2', {IN_PIPE=>""},{OUT=>""}],


  ## Field extraction
  ['f1', '-W sum 1', {IN_PIPE=>$in2}, {OUT=>"5\n"}],
  ['f2', '-W sum 2', {IN_PIPE=>$in2}, {OUT=>"7\n"}],
  ['f3', '-W sum 3', {IN_PIPE=>$in2}, {OUT=>"9\n"}],
  ['f4', '-W sum 3 sum 1', {IN_PIPE=>$in2}, {OUT=>"9\t5\n"}],
  ['f5', '-t: sum 4', {IN_PIPE=>"11:12::13:14"}, {OUT=>"13\n"}],
  # collase non-last field (followed by whitespace, not new-line)
  ['f6', '-t" " unique 1', {IN_PIPE=>$in_g2}, {OUT=>"A,B\n"}],
  ['f7', 'unique 1', {IN_PIPE=>$in_g2_tab}, {OUT=>"A,B\n"}],
  # Differences between TAB (detail), Space, and whitespace delimiters
  ['f8', 'collapse 1', {IN_PIPE=>$in2}, {OUT=>"1 2,4\n"}],
  ['f9', 'collapse 2', {IN_PIPE=>$in2}, {OUT=>" 3,5 6\n"}],
  ['f10', '-t" " collapse 1', {IN_PIPE=>$in2}, {OUT=>"1,4\t5\n"}],
  ['f11', '-t" " collapse 2', {IN_PIPE=>$in2}, {OUT=>"2\t,6\n"}],
  ['f12', '-W collapse 1', {IN_PIPE=>$in2}, {OUT=>"1,4\n"}],
  ['f13', '-W collapse 2', {IN_PIPE=>$in2}, {OUT=>"2,5\n"}],
  ['f14', '-W collapse 3', {IN_PIPE=>$in2}, {OUT=>"3,6\n"}],
  ['f15', '-W collapse 1', {IN_PIPE=>$in3}, {OUT=>"1,4\n"}],
  ['f16', '-W collapse 2', {IN_PIPE=>$in3}, {OUT=>"2,5\n"}],
  ['f17', '-W collapse 3', {IN_PIPE=>$in3}, {OUT=>"3,6\n"}],


  # Test Absolute min/max
  ['mm1', 'min 1', {IN_PIPE=>$in_minmax}, {OUT=>"-700\n"}],
  ['mm2', 'max 1', {IN_PIPE=>$in_minmax}, {OUT=>"200\n"}],
  ['mm3', 'absmin 1', {IN_PIPE=>$in_minmax}, {OUT=>"0.0001\n"}],
  ['mm4', 'absmax 1', {IN_PIPE=>$in_minmax}, {OUT=>"-700\n"}],

  #
  # Test Grouping
  #

  # Single group (key in column 1)
  ['g1.1', '-t" " -g1 sum 2',    {IN_PIPE=>$in_g1}, {OUT=>"A 195\n"}],
  ['g2.1', '-t" " -g1 median 2', {IN_PIPE=>$in_g1}, {OUT=>"A 42.5\n"}],
  ['g3.1', '-t" " -g1 collapse 2', {IN_PIPE=>$in_g1}, {OUT=>"A 100,10,50,35\n"}],

  # 3 groups, single line per group, custom delimiter
  ['g7.1', '-g2 -t= mode 1', {IN_PIPE=>"1=A\n2=B\n3=C\n"},
     {OUT=>"A=1\nB=2\nC=3\n"}],

  # Multiple keys (from different columns)
  ['g8.1',     '-t" " -g1,3 sum 2', {IN_PIPE=>$in_g3},
     {OUT=>"A W 15\nA X 24\nB Y 17\nB Z 19\nC Z 23\n"}],


  # --full option - without grouping, returns the first line
  ['fl1', '-t" " --full sum 2', {IN_PIPE=>$in_g3},
     {OUT=>"A 3 W 98\n"}],
  # --full with grouping - print entire line of each group
  ['fl2', '-t" " --full -g3 sum 2', {IN_PIPE=>$in_g3},
     {OUT=>"A 3 W 15\nA 11 X 24\nB 17 Y 17\nB 19 Z 42\n"}],

  # count on non-numeric fields
  ['cnt1', '-t" " -g 1 count 1', {IN_PIPE=>$in_g2},
     {OUT=>"A 4\nB 3\n"}],

  # Input Header
  ['hdr1', '-t" " -g 1 --header-in count 2',{IN_PIPE=>$in_hdr1},
     {OUT=>"A 5\nB 3\nC 4\n"}],

  # Input and output header
  ['hdr2', '-t" " -g 1 --header-in --header-out count 2',{IN_PIPE=>$in_hdr1},
     {OUT=>"GroupBy(x) count(y)\nA 5\nB 3\nC 4\n"}],

  # Input and output header, with full line
  ['hdr3', '-t" " -g 1 --full --header-in --header-out count 2',{IN_PIPE=>$in_hdr1},
     {OUT=>"x y z count(y)\nA 1 10 5\nB 5 10 3\nC 8 11 4\n"}],

  # Output Header
  ['hdr4', '-t" " -g 1 --header-out count 2', {IN_PIPE=>$in_g3},
     {OUT=>"GroupBy(field-1) count(field-2)\nA 5\nB 2\nC 1\n"}],

  # Output Header with --full
  ['hdr5', '-t" " -g 1 --full --header-out count 2', {IN_PIPE=>$in_g3},
     {OUT=>"field-1 field-2 field-3 count(field-2)\nA 3 W 5\nB 17 Y 2\nC 23 Z 1\n"}],

  # Header without grouping
  ['hdr6', '-t" " --header-out count 2', {IN_PIPE=>$in_g3},
     {OUT=>"count(field-2)\n8\n"}],

  # Output Header, multiple ops
  ['hdr7', '-t" " -g 1 --header-out count 2 unique 3', {IN_PIPE=>$in_g3},
     {OUT=>"GroupBy(field-1) count(field-2) unique(field-3)\nA 5 W,X\nB 2 Y,Z\nC 1 Z\n"}],

  # Headers, non white-space separator
  ['hdr8', '-g 1 -H -t: count 2 unique 3', {IN_PIPE=>$in_hdr2},
     {OUT=>"GroupBy(x):count(y):unique(z)\nA:5:W,X\nB:2:Y,Z\nC:1:Z\n"}],

  # Headers, non white-space separator, 3 operations
  ['hdr9', '-g 1 -H -t: count 2 unique 3 sum 2', {IN_PIPE=>$in_hdr2},
     {OUT=>"GroupBy(x):count(y):unique(z):sum(y)\nA:5:W,X:39\nB:2:Y,Z:36\nC:1:Z:23\n"}],


  # Test single line per group
  ['sl1', '-t" " -g 1 mean 2', {IN_PIPE=>$in_g4},
     {OUT=>"A 5\nK 6\nP 2\n"}],
  ['sl2', '-t" " --full -g 1 mean 2', {IN_PIPE=>$in_g4},
     {OUT=>"A 5 5\nK 6 6\nP 2 2\n"}],

  # Test countunique operation
  ['cuq1', '-t" " -g 1 countunique 3', {IN_PIPE=>$in_g3},
     {OUT=>"A 2\nB 2\nC 1\n"}],
  ['cuq2', '-t" " -g 1 countunique 2', {IN_PIPE=>$in_g4},
     {OUT=>"A 1\nK 1\nP 1\n"}],
  ['cuq3', '-t" " --header-in -g 1 countunique 2', {IN_PIPE=>$in_cnt_uniq1},
     {OUT=>"A 2\nB 2\n"}],

  # Test Tab vs White-space field separator
  ['tab1', "sum 2", {IN_PIPE=>$in_tab1}, {OUT=>"60\n"}],
  ['tab2', '-W sum 2',         {IN_PIPE=>$in_tab1}, {OUT=>"6\n"}],

  # Test Auto-Sorting
  # With default separator (White-space), the second column is A,B,C,D
  ['sort1', '-W -s -g 2 unique 3', {IN_PIPE=>$in_sort1},
     {OUT=>"A\tx\nB\tk,x\nC\tg,j\nD\tj\n"}],
  # With TAB separator, the second column is g,j,k,x
  ['sort2', '-s -g 2 unique 3', {IN_PIPE=>$in_sort1},
     {OUT=>"g\t6\nj\t3,4\nk\t2\nx\t1,5\n"}],
  # Control check: if we do not sort, the some groups will appear twice
  # because the input is not sorted.
  ['sort3', '-g 2 unique 3', {IN_PIPE=>$in_sort1},
     {OUT=>"x\t1\nk\t2\nj\t3\nx\t5\nj\t4\ng\t6\n"}],


  # Test Case-sensitivity, on sorted input (no 'sort' piping)
  # on both grouping and string operations
  ['case1', '-t" " -g 1 sum 3', {IN_PIPE=>$in_case_sorted},
     {OUT=>"a 4\nA 7\nb 4\nB 6\n"}],
  ['case2', '-t" " -i -g 1 sum 3', {IN_PIPE=>$in_case_sorted},
     {OUT=>"a 11\nb 10\n"}],
  ['case3', '-t" " -g 1 unique 2', {IN_PIPE=>$in_case_sorted},
     {OUT=>"a X,x\nA X,x\nb Y\nB Y\n"}],
  ['case4', '-t" " -i -g 1 unique 2', {IN_PIPE=>$in_case_sorted},
     {OUT=>"a X\nb Y\n"}],

  # Test Case-sensitivity, on non-sorted input (with 'sort' piping)
  # on both grouping and string operations.
  ['case5', '-t" " -s -g 1 sum 3', {IN_PIPE=>$in_case_unsorted},
     {OUT=>"A 7\nB 6\na 4\nb 4\n"}],
  ['case6', '-t" " -s -g 1 unique 2', {IN_PIPE=>$in_case_unsorted},
     {OUT=>"A X,x\nB Y\na X,x\nb Y\n"}],

  ## Test nul-terminated lines
  ['nul1', '-t" " -z -g 1 sum 2', {IN_PIPE=>$in_nul1},
     {OUT=>"A 3\x00B 7\x00"}],
  ['nul2', '-t" " --zero-terminated -g 1 sum 2', {IN_PIPE=>$in_nul1},
     {OUT=>"A 3\x00B 7\x00"}],

  # Test --help (but don't verify the output)
  ['help1', '--help',     {IN_PIPE=>""},  {OUT => ""},
	  {OUT_SUBST=>'s/^.*//gms'}],
  ['ver1', '--version',     {IN_PIPE=>""},  {OUT => ""},
	  {OUT_SUBST=>'s/^.*//gms'}],

  # Test output precision (number of digits) for numerical operations.
  # The current precision is 14 digits (hard-coded).
  ['prcs1', 'sum 1', {IN_PIPE=>"1e1"},  {OUT => "10\n"}],
  ['prcs2', 'sum 1', {IN_PIPE=>"1e7"},  {OUT => "10000000\n"}],
  ['prcs3', 'sum 1', {IN_PIPE=>"1e9"},  {OUT => "1000000000\n"}],
  ['prcs4', 'sum 1', {IN_PIPE=>"1.8e12"},  {OUT => "1800000000000\n"}],
  ['prcs5', 'sum 1', {IN_PIPE=>"1.234e13"},  {OUT => "12340000000000\n"}],
  ['prcs6', 'sum 1', {IN_PIPE=>"1.234e14"},  {OUT => "1.234e+14\n"}],
  ['prcs7', 'sum 1', {IN_PIPE=>"-1.8e12"},  {OUT => "-1800000000000\n"}],
  ['prcs8', 'sum 1', {IN_PIPE=>"-1.234e13"},  {OUT => "-12340000000000\n"}],
  ['prcs9', 'sum 1', {IN_PIPE=>"-1.234e14"},  {OUT => "-1.234e+14\n"}],
  ['prcs10', 'sum 1', {IN_PIPE=>$in_precision1},  {OUT => "30000000000.3\n"}],
  ['prcs11', 'sum 1', {IN_PIPE=>$in_precision2},  {OUT => "3e+14\n"}],

  # Test first,last operations (and 'field_op_replace_string()')
  ['fst1',   '-t" " first 2', {IN_PIPE=>$in_g1}, {OUT=>"100\n"}],
  ['fst2',   '-t" " -g 1 first 2', {IN_PIPE=>$in_g1}, {OUT=>"A 100\n"}],
  ['fst3',   '-t" " -g 1 first 2', {IN_PIPE=>$in_g2}, {OUT=>"A 100\nB 66\n"}],
  ['fst4',   '-t" " -g 1 first 2', {IN_PIPE=>$in_g4}, {OUT=>"A 5\nK 6\nP 2\n"}],
  ['fst5',   '-t" " -g 1 first 2', {IN_PIPE=>$in_large_buffer1},
            {OUT=>"A 1\nB 3\n"}],
  ['fst6',   '-t" " -g 1 first 2', {IN_PIPE=>$in_large_buffer2},
            {OUT=>$out_large_buffer_first}],

  ['lst1',   '-t" " last 2', {IN_PIPE=>$in_g1}, {OUT=>"35\n"}],
  ['lst2',   '-t" " -g 1 last 2', {IN_PIPE=>$in_g1}, {OUT=>"A 35\n"}],
  ['lst3',   '-t" " -g 1 last 2', {IN_PIPE=>$in_g2}, {OUT=>"A 35\nB 55\n"}],
  ['lst4',   '-t" " -g 1 last 2', {IN_PIPE=>$in_g4}, {OUT=>"A 5\nK 6\nP 2\n"}],
  ['lst5',   '-t" " -g 1 last 2', {IN_PIPE=>$in_large_buffer1},
            {OUT=>"A 2\nB 4\n"}],
  ['lst6',   '-t" " -g 1 last 2', {IN_PIPE=>$in_large_buffer2},
            {OUT=>$out_large_buffer_last}],
);

if ($have_stable_sort) {
  push @Tests, (
    # last with sort, test the 'stable' sort
    ['lst7',   '-t" " --sort -g 1 last 3',  {IN_PIPE=>$in_case_unsorted},
       {OUT=>"A 5\nB 6\na 3\nb 4\n"}],
    ['lst8',   '-t" " --sort -i -g 1 last 3',  {IN_PIPE=>$in_case_unsorted},
       {OUT=>"a 5\nb 6\n"}],
    # First with sort, test the 'stable' sort
    ['fst7',   '-t" " --sort -g 1 first 3',  {IN_PIPE=>$in_case_unsorted},
       {OUT=>"A 2\nB 6\na 1\nb 4\n"}],
    ['fst8',   '-t" " --sort -i -g 1 first 3',  {IN_PIPE=>$in_case_unsorted},
       {OUT=>"a 1\nb 4\n"}],
    # NOTE: 'sort' is used with '-s' (stable sort),
    #       so with case-insensitive sort, the first appearing letter is
    #       reported (the lowercase a/b in case7 & case8).
    ['case7', '-t" " -s -i -g 1 sum 3', {IN_PIPE=>$in_case_unsorted},
       {OUT=>"a 11\nb 10\n"}],
    ['case8', '-t" " -s -i -g 1 unique 2', {IN_PIPE=>$in_case_unsorted},
       {OUT=>"a X\nb Y\n"}],
 );
}

my $save_temps = $ENV{SAVE_TEMPS};
my $verbose = $ENV{VERBOSE};

my $fail = run_tests ($program_name, $prog, \@Tests, $save_temps, $verbose);
exit $fail;