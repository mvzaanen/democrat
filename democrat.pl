#!/usr/bin/perl -w

# democrat.pl
# Copyright Menno van Zaanen (2005)
# Macquarie University, Australia

use strict;
use vars qw($opt_h $opt_i $opt_o);
use Getopt::Std;

$opt_i ="-"; # default value
$opt_o ="-"; # default value
$opt_h =0; # default value
getopts('hi:o:');

my $usage =
  "Usage: $0 [OPTION]\.\.\.
This program reads in a file with translations (separated by a * on a
line) and finds the best combinations of words from these sentences.

  -i FILE   Name of input file (default: $opt_i)
  -o FILE   Name of output file (default: $opt_o)
  -h        Show this help and exit
";

die $usage if $opt_h;

die $usage if $opt_i eq "";
open(INPUT, "<$opt_i")
  || die "Couldn't open input file: $!\n";

die $usage if $opt_o eq "";
open(OUTPUT, ">$opt_o")
  || die "Couldn't open outputfile: $!\n";

my $chaos_counter=0;
my $total_counter=0;

sub read_sentence_set {
   my @ss;
   my $line;
   while (defined($line=<INPUT>)&&($line=~/\*/)) {
   }
   if (!defined($line)) {
      return ();
   }
   chomp($line);
   push(@ss, $line);
   while (defined($line=<INPUT>)&&($line!~/\*/)) {
      chomp($line);
      push(@ss, $line);
   }
   return @ss;
}

sub min {
   my @list = @{$_[0]};
   my $min = $list[0];
   foreach my $i (@list) {
      if ($i<$min) {
         $min = $i;
      }
   }
   return $min;
}

sub cost {
   my $v1=$_[0];
   my $v2=$_[1];
   if ($v1 eq $v2) {
      return 0; # match
   }
   if ($v1 eq "") {
      return 1; # delete
   }
   if ($v2 eq "") {
      return 1; # insert
   }
   else {
      return 2; # sub
   }
}

sub build_matrix {
   my @s1=@{$_[0]};
   my @s2=@{$_[1]};
   my $len1=scalar(@s1);
   my $len2=scalar(@s2);
   my %mat;

   $mat{0}{0}=0;
   for (my $i=1; $i<=$len1; ++$i) {
      $mat{$i}{0}=$mat{$i-1}{0}+cost($s1[$i-1], "");
   }
   for (my $j=1; $j<=$len2; ++$j) {
      $mat{0}{$j}=$mat{0}{$j-1}+cost("", $s2[$j-1]);
   }
   for (my $i=1; $i<=$len1; ++$i) {
      for (my $j=1; $j<=$len2; ++$j) {
         $mat{$i}{$j}=min([$mat{$i-1}{$j}+cost($s1[$i-1], ""),
                             $mat{$i}{$j-1}+cost("", $s2[$j-1]),
                             $mat{$i-1}{$j-1}+cost($s1[$i-1], $s2[$j-1])]);
      }
   }
   return %mat;
}

sub find_alignment {
   my %mat=%{$_[0]};
   my @s1=@{$_[1]};
   my @s2=@{$_[2]};
   my @res;
   my $i=scalar(@s1);
   my $j=scalar(@s2);
   while (!(($i==0)&&($j==0))) {
      if (($i!=0 and $j!=0)
         and ($mat{$i}{$j}==$mat{$i-1}{$j-1}+cost($s1[$i-1], $s2[$j-1]))) {
         if ($s1[$i-1] eq $s2[$j-1] ) {
            push(@res, "mat");
         }
         else {
            push(@res, "sub");
         }
         --$i;
         --$j;
      }
      elsif (($i!=0)
         and ($mat{$i}{$j}==$mat{$i-1}{$j}+cost($s1[$i-1], ""))) {
         push(@res, "del");
         --$i;
      }
      elsif (($j!=0)
         and ($mat{$i}{$j}==$mat{$i}{$j-1}+cost("", $s2[$j-1]))) {
         push(@res, "ins");
         --$j;
      }
   }
   return @res;
}

sub get_alignment {
   my @s1=split(/\s+/, $_[0]);
   my @s2=split(/\s+/, $_[1]);
   my %matrix=build_matrix(\@s1, \@s2);
#print_matrix(\%matrix, \@s1, \@s2);
   my @align=find_alignment(\%matrix, \@s1, \@s2);
   return @align;
}

sub merge_clusters {
   my %graph=%{$_[0]};
   my $s1_ctr=$_[1];
   my $s2_ctr=$_[2];
   my $w1_ctr=$_[3];
   my $w2_ctr=$_[4];
   my $c1_ctr=$graph{$s1_ctr}{$w1_ctr};
   my $c2_ctr=$graph{$s2_ctr}{$w2_ctr};
   if ($c1_ctr==$c2_ctr) {
      return %graph;
   }
   foreach my $pair (@{$graph{"cluster"}{$c2_ctr}}) {
      my @vals=@{$pair};
      $graph{$vals[0]}{$vals[1]}=$c1_ctr;
      push(@{$graph{"cluster"}{$c1_ctr}}, $pair);
   }
   delete $graph{"cluster"}{$c2_ctr};
   return %graph;
}

sub handle_pair {
   my $s1_ctr=$_[0];
   my $s2_ctr=$_[1];
   my %graph=%{$_[2]};
   my @align=@{$_[3]};
   my $w1_ctr=0;
   my $w2_ctr=0;
   while (my $op=pop(@align)) {
      if ($op eq "mat") {
         %graph=merge_clusters(\%graph, $s1_ctr, $s2_ctr, $w1_ctr, $w2_ctr);
         $w1_ctr++;
         $w2_ctr++;
      }
      elsif ($op eq "sub") {
         $w1_ctr++;
         $w2_ctr++;
      }
      elsif ($op eq "del") {
         $w1_ctr++;
      }
      elsif ($op eq "ins") {
         $w2_ctr++;
      }
   }
   return %graph;
}

sub handle_set {
   my @set=@{$_[0]};
   my %graph=%{$_[1]};
   for (my $i=0; $i<scalar(@set); ++$i) {
      for (my $j=($i+1); $j<scalar(@set); ++$j) {
         my @align=get_alignment($set[$i], $set[$j]);
#my @s1=split(/\s+/, $set[$i]);
#my @s2=split(/\s+/, $set[$j]);
#print_alignment(\@align, \@s1, \@s2);
#print "($i, $j) before...\n";
         %graph=handle_pair($i, $j, \%graph, \@align);
      }
   }
   return %graph;
}

sub dijkstra_search {
   my %graph=%{$_[0]};
   my @sentences=@{$_[1]};
	my %visited;
   for (my $s_ctr=0; $s_ctr<scalar(@sentences); $s_ctr++) {
      my @tmp=split(/\s+/, $sentences[$s_ctr]);
      $sentences[$s_ctr]=\@tmp;
   }
   my %options; # possible continuing paths
   foreach my $s_ctr (keys %graph) {
      if (defined($graph{$s_ctr}{0})&&($s_ctr ne "cluster")) {
			if (!$visited{$graph{$s_ctr}{0}}) {
         	my $cluster=$graph{"cluster"}{$graph{$s_ctr}{0}};
         	$options{$graph{$s_ctr}{0}}=scalar(@{$cluster});
			}
      }
   }
   my @res;
   while (scalar(keys %options)!=0) {
      my $best_cluster=-1;
      my $score=-1;
		my $option_counter=0;
      foreach my $test_cluster (keys %options) {
         if ($options{$test_cluster}==$score) {
				$option_counter++;
			}
			if ($options{$test_cluster}>$score) {
				$option_counter=0;
			}
         if ($options{$test_cluster}>=$score) {
            $score=$options{$test_cluster};
            $best_cluster=$test_cluster;

         }
      }

		if ($option_counter>0) {
			$chaos_counter++;
		}
		$total_counter++;
      my @cluster=@{$graph{"cluster"}{$best_cluster}};
      my @pair;
      @pair=@{$cluster[0]};
      push(@res, $sentences[$pair[0]][$pair[1]]);
      $visited{$best_cluster}=1;
      %options=();
      foreach my $pos_option (@{$graph{"cluster"}{$best_cluster}}) {
         if (defined($graph{$pos_option->[0]}{$pos_option->[1]+1})) {
            my $next=$graph{$pos_option->[0]}{$pos_option->[1]+1};
				if (!$visited{$next}) {
               $options{$next}=scalar(@{$graph{"cluster"}{$next}});
            }
         }
      }
   }
   return join(" ",@res);
}

sub greedy_search {
   my %graph=%{$_[0]};
   my @sentences=@{$_[1]};
	my %visited;
   for (my $s_ctr=0; $s_ctr<scalar(@sentences); $s_ctr++) {
      my @tmp=split(/\s+/, $sentences[$s_ctr]);
      $sentences[$s_ctr]=\@tmp;
   }
   my %options; # possible continuing paths
   foreach my $s_ctr (keys %graph) {
      if (defined($graph{$s_ctr}{0})&&($s_ctr ne "cluster")) {
			if (!$visited{$graph{$s_ctr}{0}}) {
         	my $cluster=$graph{"cluster"}{$graph{$s_ctr}{0}};
         	$options{$graph{$s_ctr}{0}}=scalar(@{$cluster});
			}
      }
   }
   my @res;
   while (scalar(keys %options)!=0) {
      my $best_cluster=-1;
      my $score=-1;
		my $option_counter=0;
      foreach my $test_cluster (keys %options) {
         if ($options{$test_cluster}==$score) {
				$option_counter++;
			}
			if ($options{$test_cluster}>$score) {
				$option_counter=0;
			}
         if ($options{$test_cluster}>=$score) {
            $score=$options{$test_cluster};
            $best_cluster=$test_cluster;

         }
      }

		if ($option_counter>0) {
			$chaos_counter++;
		}
		$total_counter++;
      my @cluster=@{$graph{"cluster"}{$best_cluster}};
      my @pair;
      @pair=@{$cluster[0]};
      push(@res, $sentences[$pair[0]][$pair[1]]);
      $visited{$best_cluster}=1;
      %options=();
      foreach my $pos_option (@{$graph{"cluster"}{$best_cluster}}) {
         if (defined($graph{$pos_option->[0]}{$pos_option->[1]+1})) {
            my $next=$graph{$pos_option->[0]}{$pos_option->[1]+1};
				if (!$visited{$next}) {
               $options{$next}=scalar(@{$graph{"cluster"}{$next}});
            }
         }
      }
   }
   return join(" ",@res);
}

sub insert_sentence_set {
   my @sentences=@{$_[0]};
   my %graph;
   my $cluster=0;
   for (my $s_ctr=0; $s_ctr<scalar(@sentences); $s_ctr++) {
      my @words=split(/\s+/, $sentences[$s_ctr]);
      for (my $w_ctr=0; $w_ctr<scalar(@words); ++$w_ctr) {
         $graph{"cluster"}{$cluster}=[[$s_ctr, $w_ctr]];
         $graph{$s_ctr}{$w_ctr}=$cluster++;
      }
   }
   return %graph;
}

my $nr_sentences=0;
my @sentence_set;
while (@sentence_set=read_sentence_set()) {
	$nr_sentences++;
   if (scalar(@sentence_set)==1) {
      print OUTPUT "$sentence_set[0]\n";
      print OUTPUT "*\n";
      next;
   }
   my %graph=insert_sentence_set(\@sentence_set);
   %graph=handle_set(\@sentence_set, \%graph);
	my $result;
   $result=greedy_search(\%graph, \@sentence_set);
   print OUTPUT "$result\n";
   print OUTPUT "*\n";
}
close(INPUT);
close(OUTPUT);

# print summary
print "Summary\n";
print "======================================================\n";
print "filename:                       $opt_i\n";
print "\# of sentences:                 $nr_sentences\n";
print "\# of random choices:            $chaos_counter\n";
print "total \# of choices:             $total_counter\n";
print "======================================================\n";


### SUPPORT

sub print_matrix {
   my %mat=%{$_[0]};
   my @s1=@{$_[1]};
   my @s2=@{$_[2]};
   print "    ";
   foreach my $w (@s2) {
      print "    $w"
   }
   print "\n";
   for (my $i = 0; $i <= scalar(@s1); ++$i) {
      if ($i!=0) {
         print $s1[$i-1];
      }
      else {
         print " ";
      }
      for (my $j = 0; $j <= scalar(@s2); ++$j) {
         print "  $mat{$i}{$j}  "
      }
      print "\n"
   }
   print "\n"
}

sub print_alignment {
   my @align=@{$_[0]};
   my @s1=@{$_[1]};
   my @s2=@{$_[2]};
   my $op;
   my $counter=0;
   my @align_cpy=@align;
   while ($op=pop(@align_cpy)) {
      if (($op eq "mat") or ($op eq "sub")) {
         print $s1[$counter]."   ";
         ++$counter;
      }
      elsif ($op eq "del") {
         print $s1[$counter]."   ";
         ++$counter;
      }
      elsif ($op eq "ins") {
         print "-----   ";
      }
   }
   print "\n";
   @align_cpy=@align;
   $counter=0;
   while ($op=pop(@align_cpy)) {
      if (($op eq "mat") or ($op eq "sub")) {
         print $s2[$counter]."   ";
         ++$counter;
      }
      elsif ($op eq "del") {
         print "-----   ";
      }
      elsif ($op eq "ins") {
         print $s2[$counter]."   ";
         ++$counter;
      }
   }
   print "\n";
   @align_cpy=@align;
   while ($op=pop(@align_cpy)) {
      print "$op      ";
   }
   print "\n";
}

sub print_graph {
   my %graph=%{$_[0]};
   foreach my $k (sort keys %graph) {
      if ($k eq "cluster") {
         foreach my $l (sort keys %{$graph{$k}}) {
            print "cluster $l: \n";
            foreach my $vals (@{$graph{$k}{$l}}) {
               print "$vals->[0],$vals->[1]:";
            }
            print "\n";
         }
      }
      else {
         foreach my $l (sort keys %{$graph{$k}}) {
            print "$k: $l: $graph{$k}{$l}\n";
         }
      }
   }
}
