#!/bin/perl
#Author: ALin
#Purpose: To parse the dolphin behaviour data.
#Usage: perl dolphin_behaviour_parser.pl [option]
#		-in <String> Input
#		-header <Boolean> Header present (Default: False)
#		-h <Boolean> Help


use strict;
use Getopt::Long;
use Statistics::RankCorrelation;
use List::Util qw(min max);

my $in = "";
my $header = 0;
my $help = 0;


GetOptions(
	'in=s'	=>	\$in,
	'header!'	=>	\$header,
        'h!'    =>      \$help,
);

if($help){
        print_usage();
        exit;
}

unless($in){
	print_usage();
	exit;
}

open(IN, $in) or die "Cannot open $in!\n";

my %table  = ();
my %total_bin = ();

while(<IN>){
	if($header){
		$header = 0;
		next;
	}
	chomp;
	my $line = $_;
	$line =~ s/"//g;
	my @line = split('\t', $line);
	if($line[13] eq "POINT"){
		next;
	}
	my $session = $line[0];
	$session =~ s/[\.,]/_/g;
	$session =~ s/\s//g;
	my $total_bin = $line[3] * 1000;
	my $id = $line[9] . "_" . $line[10];
	$id =~ s/\s/_/g;
	my $start = $line[14] * 1000;
	my $end = $line[15] * 1000;
	unless(exists $table{$session}){
		%{$table{$session}} = ();
	}
	unless(exists $table{$session}{$id}){
		@{$table{$session}{$id}} = (0) x $total_bin;
	}
	unless(exists $total_bin{$session}){
		$total_bin{$session} = $total_bin;
	}
	for(my $i = ($start - 1); $i < $end; $i++){
		$table{$session}{$id}[$i] = 1;
	}
}
close IN;

foreach my $session (keys %table){
	my $out = $session . "_parsed.txt";
	open(OUT, ">$out") or die "Cannot create $out!\n";
	print OUT "Bin";
	foreach my $id (keys %{$table{$session}}){
		print OUT "\t$id";
	}
	for(my $i = 0; $i < $total_bin{$session}; $i++){
		print OUT "\n$i";
		foreach my $id (keys %{$table{$session}}){
			print OUT "\t$table{$session}{$id}[$i]";
		}
	}
	close OUT;
}

sub print_usage{
	print "Usage: perl dolphin_behaviour_parser.pl [option]\n\t-in <String> Input\n\t-header <Boolean>  Header present (Default: False)\n\t-h <Boolean> Help\n";
}





