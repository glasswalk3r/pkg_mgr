# Copyright (c) 2009 Landry Breuil <landry@openbsd.org>
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

use warnings;
use strict;

package OpenBSD::PackageManager::Pkg;
use OpenBSD::PackageManager::Pkg::Add;
use OpenBSD::PackageManager::Pkg::Delete;

sub new
{
	my $class = shift;
	my $view = shift;
	my $self = {};
	bless ($self, $class);
	$self->{install} = OpenBSD::PackageManager::Pkg::Add->new($view);
	$self->{remove} = OpenBSD::PackageManager::Pkg::Delete->new($view);
	return $self;
}

sub install
{
	main::debug("pkg::install:".@_);
	my $self = shift;
	my $really = shift; # -n
	my $update = shift; # -u
	return $self->{install}->installpkg($really, $update, @_);
}

sub remove
{
	main::debug("pkg::remove:".@_);
	my $self = shift;
	my $really = shift;
	return $self->{remove}->removepkg($really, @_);
}
1;
