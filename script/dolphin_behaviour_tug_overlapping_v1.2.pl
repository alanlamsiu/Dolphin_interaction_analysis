#!/bin/perl
#Author: ALin
#Purpose: To parse the dolphin alruistic food sharing data and identify overlapping period between tug and other behaviors.
#Usage: perl dolphin_behaviour_tug_overlapping_v1.2.pl [option]
#		-in <String> Input
#		-out <String> Ouput
#		-header <Boolean> Header present (Default: False)
#		-h <Boolean> Help
#Log:
#	v1.2	2021-07 For each tugging event of one dolphin, the "Interaction", "Investigation", "Observation" and "No overlap" interval were classified.



use strict;
use Getopt::Long;
use Statistics::RankCorrelation;
use List::Util qw(min max);

my $in = "";
my $out = "";
my $header = 0;
my $help = 0;


GetOptions(
	'in=s'	=>	\$in,
	'out=s'	=>	\$out,
	'header!'	=>	\$header,
        'h!'    =>      \$help,
);

if($help){
        print_usage();
        exit;
}

unless($in && $out){
	print_usage();
	exit;
}

open(IN, $in) or die "Cannot open $in!\n";
open(OUT, ">$out") or die "Cannot create $out!\n";

my %table  = ();

while(<IN>){
	if($header){
		$header = 0;
		next;
	}
	chomp;
	my $line = $_;
	$line =~ s/"//g;
	my @line = split('\t', $line);
	my $session = $line[0];
	$session =~ s/\"//g;
	$session =~ s/[\.,]/_/g;
	$session =~ s/\s//g;
	unless(exists $table{$session}){
		%{$table{$session}} = ();
	}
	unless(exists $table{$session}{$line[2]}){
		%{$table{$session}{$line[2]}} = ();
	}
		
	unless(exists $table{$session}{$line[2]}{$line[1]}){
		@{$table{$session}{$line[2]}{$line[1]}} = ();
	}
	my @interval = ($line[3], $line[4]);
	push(@{$table{$session}{$line[2]}{$line[1]}}, \@interval);
}
close IN;

print OUT "Session\tTug_event\tTug_dolphin\tTug_duration\tInteraction_dolphin\tInteraction_duration\tInteraction_proportion\tInvestigation_dolphin\tInvestigation_duration\tInvestigation_proportion\tObservation_dolphin\tObservation_duration\tObservation_proportion\tNo_overlap_duration\tNo_overlap_proportion";

foreach my $session (keys %table){
	my $tug_event = 1;
	foreach my $tug_dolphin (keys %{$table{$session}{'Tug'}}){
		foreach my $interval1 (@{$table{$session}{'Tug'}{$tug_dolphin}}){
			my $tug_duration = $interval1->[1] - $interval1->[0];
			my %act = ();
			my %act_dolphin = ();
			@{$act{'All'}} = ();
			@{$act{'Interaction'}} = ();
			%{$act_dolphin{'Interaction'}} = ();
			@{$act{'Investigation'}} = ();
			%{$act_dolphin{'Investigation'}} = ();
			@{$act{'Observation'}} = ();
			%{$act_dolphin{'Observation'}} = ();
			#print "TUG:$tug_dolphin\t$interval1->[0]\t$interval1->[1]\n";
			ACT:foreach my $act (keys %{$table{$session}}){
				DOLPHIN:foreach my $dolphin (keys %{$table{$session}{$act}}){
					if($act eq "Tug"){
						next ACT;
					}
					if($dolphin eq $tug_dolphin){
						next DOLPHIN;
					}
					foreach my $interval2 (@{$table{$session}{$act}{$dolphin}}){
						my $overlap = overlap($interval1, $interval2);
						#print "ACT:$dolphin\t$act\t$interval2->[0]\t$interval2->[1]\t$overlap\n";
						if($overlap eq "in"){
							push(@{$act{'All'}}, $interval2);
							push(@{$act{$act}}, $interval2);
						}
						elsif($overlap eq "out"){
							push(@{$act{'All'}}, $interval1);
							push(@{$act{$act}}, $interval1);
						}
						elsif($overlap eq "left"){
							my @new_interval = ($interval1->[0], $interval2->[1]);
							push(@{$act{'All'}}, \@new_interval);
							push(@{$act{$act}}, \@new_interval);
						}
						elsif($overlap eq "right"){
							my @new_interval = ($interval2->[0], $interval1->[1]);
							push(@{$act{'All'}}, \@new_interval);
							push(@{$act{$act}}, \@new_interval);
						}
						if($overlap){
							unless(exists $act_dolphin{$act}{$dolphin}){
								$act_dolphin{$act}{$dolphin} = 1;
							}
						}
					}
				}
			}
			print OUT "\n$session\t$tug_event\t$tug_dolphin\t$tug_duration";
			my @act_list = ("Interaction", "Investigation", "Observation", "All");
			foreach my $act (@act_list){
				#print "$act\n";
				if(@{$act{$act}}){
					#print "Found\n";
					my @merged_act = merge(\@{$act{$act}});
					my $num_act = @merged_act;
					my $act_duration = 0;
					for(my $i = 0; $i < $num_act; $i++){
						$act_duration += ($merged_act[$i][1] - $merged_act[$i][0]);
					}
					my $act_proportion = $act_duration / $tug_duration;
					if($act eq "All"){
						my $no_overlap_duration = $tug_duration - $act_duration;
						my $no_overlap_proportion = 1 - $act_proportion;
						print OUT "\t$no_overlap_duration\t$no_overlap_proportion";
					}
					else{
						my @act_dolphin = keys(%{$act_dolphin{$act}});
						my $act_dolphin = join(",", @act_dolphin);
						print OUT "\t$act_dolphin\t$act_duration\t$act_proportion";
					}
				}
				else{
					if($act eq "All"){
						print OUT "\t$tug_duration\t1";
					}
					else{
						print OUT "\tNA\t0\t0";
					}
				}
			}
			$tug_event++;
		}
	}
}
close OUT;

sub print_usage{
	print "Usage: perl dolphin_behaviour_tug_overlapping_v1.2.pl [option]\n\t-in <String> Input\n\t-out <String> Output\n\t-header <Boolean>  Header present (Default: False)\n\t-h <Boolean> Help\n";
}

sub overlap{
	my ($temp_interval1, $temp_interval2) = ($_[0], $_[1]);
	if(($temp_interval2->[0] >= $temp_interval1->[0]) && ($temp_interval2->[1] <= $temp_interval1->[1])){
		return "in";
	}
	elsif(($temp_interval2->[0] < $temp_interval1->[0]) && ($temp_interval2->[1] > $temp_interval1->[1])){
		return "out";
	}
	elsif(($temp_interval2->[0] < $temp_interval1->[0]) && ($temp_interval2->[1] >= $temp_interval1->[0]) && ($temp_interval2->[1] <= $temp_interval1->[1])){
		return "left";
	}
	elsif(($temp_interval2->[0] >= $temp_interval1->[0]) && ($temp_interval2->[0] <= $temp_interval1->[1]) && ($temp_interval2->[1] > $temp_interval1->[1])){
		return "right";
	}
	else{
		return 0;
	}
}

sub merge{
	my ($sref,$start) = @_;
	return if (ref($sref) ne 'ARRAY');

	if (!defined $start) {
		if (wantarray) {
			my @tmpsets = map {[@{$_}]} @{$sref};
			$sref = \@tmpsets;
		}
		@{$sref} = sort {$a->[0]<=>$b->[0] || $a->[1]<=>$b->[1]} @{$sref};
		$start = 0;
	}
	my $last = $sref->[$start];
	++$start;

	if (@{$last}){
		for my $ndx ($start .. @{$sref}-1){
			my $cur = $sref->[$ndx];
			next if (!@{$cur});

			if ($cur->[0] >= $last->[0] && $cur->[0] <= $last->[1] ){
				$last->[1] = $cur->[1] if ($cur->[1] > $last->[1]);
				@{$cur} = ();
			}
			else{
				last;
			}
		}
	}
	merge($sref, $start) if ( $start < @{$sref});
	if(wantarray){
		return sort {$a->[0] <=> $b->[0]} map {@{$_} ? $_ : () } @{$sref};
	}
}

