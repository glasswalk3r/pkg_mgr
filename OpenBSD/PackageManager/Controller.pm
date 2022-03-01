# Copyright (c) 2008, 2009 Landry Breuil <landry@openbsd.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

use strict;
use warnings;
package OpenBSD::PackageManager::Controller;
use Term::ReadKey;
use OpenBSD::PackageName;
use OpenBSD::PackageManager::Pkg;
use Data::Dumper;

sub new
{
	my($class, $m, $x) = @_;
	my $self = bless {model=>$m}, $class;
	return $self;
}

sub pkg
{
	my $self = shift;
	return $self->{pkg} //= OpenBSD::PackageManager::Pkg->new($self->{view});
}

sub prepare_changes
{
	my ($self) = @_;
	$self->{to_install} = [];
	$self->{to_remove} = [];
	$self->{to_update} = [];
	foreach (keys %{$self->{candidates}}) {
		next unless defined $self->{candidates}{$_};
		if ($self->{candidates}{$_} eq "+") {
			push @{$self->{to_install}}, OpenBSD::PackageName::splitstem($self->{model}->get_pkgname_for_port($_));
		} elsif ($self->{candidates}{$_} eq "-") {
			push @{$self->{to_remove}}, OpenBSD::PackageName::splitstem($self->{model}->get_pkgname_for_port($_));
		} elsif ($self->{candidates}{$_} eq "*") {
			push @{$self->{to_update}}, OpenBSD::PackageName::splitstem($self->{model}->get_pkgname_for_port($_));
		}
	}
	return @{$self->{to_install}} + @{$self->{to_remove}} + @{$self->{to_update}};
}

sub apply_changes
{
	my ($self, $really) = @_;
	my $r = 0;
	if (@{$self->{to_install}}) {
		$r = $self->pkg->install($really, 0, @{$self->{to_install}});
		return $r if $r;
	}

	if (@{$self->{to_update}}) {
		$r = $self->pkg->install($really, 1, @{$self->{to_update}});
		return $r if $r;
	}

	if (@{$self->{to_remove}}) {
		$r = $self->pkg->remove($really, @{$self->{to_remove}});
	}
	return $r;
}

sub finish_changes
{
	my $self = shift;
	$self->{model}->update_installed;
	$self->{candidates} = {};
}

sub update_all
{
	my ($self, $really) = @_;
	return $self->pkg->install($really,1,());
}

sub port_select_changed
{
	my ($self, $id, $add) = @_;
	my $inst = $self->{model}->pkg_is_installed($id);
	$self->{candidates}{$id} = $add ? ($inst ? "*" : "+") : ($inst ? "-" : undef);
}

sub enter_category
{
	my ($self, $cat) = @_;

	my @t = @{$self->{model}->get_ports_for_category($cat)};
	my $rh = $self->{model}->get_allports;
	my %h;

	if ($cat eq 0) {
		%h = %{$rh};
	} else {
		$h{$_} = $rh->{$_} foreach (@t);
	}

	my @values = sort { $h{$a}->{fullpkgname} cmp $h{$b}->{fullpkgname} } keys %h;
	my @values_installed;

	if ($cat eq -1 or $cat eq -2) {
		@values_installed = (0..$#values);
		my $s = @t;
		$s .= $cat eq -1 ? " ports installed" : " ports orphaned (installed and nothings depends on them)";
		$self->{view}->set_ports_listbox_title($s);
	} else {
		for (my $i=0 ; $i <= $#values ; $i++) {
			push @values_installed, $i if $self->{model}->pkg_is_installed($values[$i]);
		}
		my $catname = $self->{model}->get_category_name($cat);
		$self->{view}->set_ports_listbox_title("$catname, ".@values." ports in category (".@values_installed." installed)");
	}

	$self->{view}->fill_ports_listbox(\@values, \%h);
	$self->{view}->set_ports_listbox_selection(\@values_installed);
	# needed to avoid remnants of previous simulations
	$self->{candidates} = {};
	$self->{view}->focus_portslist();
}


sub enter_port
{
	my ($self, $port) = @_;
	$self->{view}->set_ports_descr_title("Information for ".$self->{model}->get_pkgname_for_port($port));
	$self->{view}->fill_port_descr($self->{model}->get_info_for_port($port), $self->{model}->pkg_is_installed($port));
}

sub search_ports
{
	my ($self, $req) = @_;
	# needed to avoid remnants of previous simulations
	$self->{candidates} = {};
	my $rh = $self->{model}->get_allports;
	my @t = @{$self->{model}->get_ports_matching_keyword($req)};

	my %h;
	$h{$_} = $rh->{$_} foreach (@t);
	# sort keys
	my @values = sort { $h{$a}->{fullpkgname} cmp $h{$b}->{fullpkgname} } keys %h;

	my @values_installed;
	for (my $i=0 ; $i <= $#values ; $i++) {
		push @values_installed, $i if ($self->{model}->pkg_is_installed($values[$i]));
	}

	$self->{view}->set_ports_listbox_title(@t." ports match keyword \"$req\" (".@values_installed." installed)");
	$self->{view}->fill_ports_listbox(\@values, \%h);
	$self->{view}->set_ports_listbox_selection(\@values_installed);
	$self->{view}->focus_portslist();
}
1;
