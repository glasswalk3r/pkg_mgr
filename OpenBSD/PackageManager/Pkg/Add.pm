# Copyright (c) 2009-2010 Landry Breuil <landry@openbsd.org>
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

package OpenBSD::PackageManager::Pkg::Add;
use OpenBSD::PkgAdd;
our @ISA=(qw(OpenBSD::PkgAdd));
use OpenBSD::PackageManager::State;

sub new
{
	my $class = shift;
	my $self = {view => shift};
	bless ($self, $class);
	$self->{state} = OpenBSD::PackageManager::PkgAdd::State->new($self->{view});
	return $self;
}

# entrypoint
sub installpkg
{
my $self  = shift;
my $really = shift; # -n
my $update = shift; # -u
my $state = $self->{state};
$state->{bad} = 0;
@ARGV = @_;
$state->handle_options($really, $update);
$state->progress->set_title($really ? ($update ? "Updating.." : "Installing..") :  ($update ? "Simulating update.." : "Simulating installation.."));
local $SIG{'INFO'} = sub { $state->status->print($state); };
$self->framework($state);
return $state->{bad} != 0;
}

1;
