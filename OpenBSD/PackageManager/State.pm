# Copyright (c) 2016 Landry Breuil <landry@openbsd.org>
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

package OpenBSD::PackageManager::PkgAdd::State;
our @ISA=(qw(OpenBSD::PackageManager::State OpenBSD::PkgAdd::State OpenBSD::State));
use OpenBSD::Paths;

sub new
{
	my($class, $v) = @_;
	my $self = $class->SUPER::new('mgr');
	$self->SUPER::init();
	$self->{name} ="pkg_mgr";
	$self->{view} = $v;
	return $self;
}

sub handle_options
{
	my ($self,$really,$update) = @_;
	# check PkgAdd::handle_options & friends
	$self->{interactive} = 1;
	$self->{destdir} = '';
	$self->{localbase} = OpenBSD::Paths->localbase;
	$self->{not} = $main::not = !$really;
	$self->{quick} = 2 if ($self->{not});
	$self->{newupdates} = $update;
	$self->{allow_replacing} = $update;
	$self->{update} = $update;
	$self->{wantntogo} = 1;
}

package OpenBSD::PackageManager::PkgDelete::State;
our @ISA=(qw(OpenBSD::PackageManager::State OpenBSD::PkgDelete::State OpenBSD::State));
use OpenBSD::Paths;

sub new
{
	my($class, $v) = @_;
	my $self = $class->SUPER::new('mgr');
	$self->SUPER::init();
	$self->{name} ="pkg_mgr";
	$self->{view} = $v;
	return $self;
}

sub handle_options
{
	my ($self,$really) = @_;
	# check PkgAdd::handle_options & friends
	$self->{interactive} = 1;
	$self->{destdir} = '';
	$self->{localbase} = OpenBSD::Paths->localbase;
	$self->{not} = $main::not = !$really;
	$self->{quick} = 2 if ($self->{not});
	$self->{wantntogo} = 1;
}

package OpenBSD::PackageManager::State;

sub dump
{
	my $self = shift;
	$self->{view}->dump();
}

sub log
{
	my $self = shift;
	return $self->{view}->log(@_);
}

sub set_context
{
	my $self = shift;
	$self->{view}->set_context(@_);
}

sub confirm
{
	my $self = shift;
	return $self->{view}->confirm(@_);
}

sub ask_list
{
	my $self = shift;
	return $self->{view}->ask_list(@_);
}

sub choose_location
{
	my $self = shift;
	return $self->{view}->choose_location(@_);
}

sub check_root
{
	# not implemented as we don't force the user to run as root
}

sub say
{
	my $self = shift;
	$self->{view}->say(@_);
}

sub fatal
{
	my $self = shift;
	$self->{view}->fatal(@_);
}

sub f
{
	my $self = shift;
	$self->{view}->f(@_);
}

sub errsay
{
	my $self = shift;
	return $self->{view}->errsay(@_);
}

sub print
{
	my $self = shift;
	return $self->{view}->print(@_);
}

sub errprint
{
	my $self = shift;
	return $self->{view}->errprint(@_);
}

sub progress
{
	my $self = shift;
	return $self->{view}->progress();
}

1;
