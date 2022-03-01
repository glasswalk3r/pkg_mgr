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

our $dbg;
sub debug {
	return unless $ENV{'DEBUG'};
	my $t = time;
	open ($dbg, '>out.log') unless defined $dbg;
	*STDERR = *$dbg;
	print $dbg "$t:@_\n";
}

package OpenBSD::PackageManager::CursesView;
#our @ISA=(qw(OpenBSD::PackageManager::View));
use Curses::UI;
use Curses;
use Carp;
use Text::Wrap;
use List::Util qw(min max);
$Text::Wrap::columns = 72;

sub new
{
	my($class, $m) = @_;
	my $self = bless {}, $class;
	$self->{name} ="pkg_mgr";
	$self->{model} = $m;
	return $self;
}

sub show_msg
{
	my $self = shift;
	$self->{wid}{help_textviewer}->text(shift);
	$self->{wid}{help_textviewer}->draw();
}

sub focus_categories
{
	my $self = shift;
	$self->show_msg("[space/enter] select\t[q] quit\n[u] update all\t\t[s] search");
	$self->{wid}{categories_listbox}->clear_selection();
	$self->{wid}{categories_listbox}->focus();
}

sub focus_portslist
{
	my ($self) = @_;

	$self->show_msg("[space] select/unselect\t[enter/right] details\t\t[left] back\t\t[q] quit\n".
		"[a] apply changes\t[s] simulate changes\t\t[/] find");
	$self->{wid}{ports_win}->focus;
}

sub focus_portdescr
{
	my $self = shift;
	$self->show_msg("[left] back\t [q] quit");
	$self->{wid}{port_textviewer}->focus;
}

sub show_category
{
	my $self = shift;
	my $cat = $self->{wid}{categories_listbox}->get_active_value();
	my $catid = $self->{wid}{categories_listbox}->labels()->{$cat};
	$self->{wid}{cui}->status("Getting ports for category $catid");
	$self->{ctrl}->enter_category($cat);
}

sub progress
{
	my $self = shift;
	return $self->{progressmeter} //= OpenBSD::PackageManager::CursesProgressMeter->new($self);
}

sub fill_ports_listbox
{
	# args: \@values,\%ports
	my ($self, $values, $ports) = @_;
	$self->{wid}{ports_listbox}->values($values);
	# unroll \%ports and fill a %labels
	my %labels;
	# padding : pkgname -- spaces -- comment
	foreach (keys %$ports) {
#		my $pkgname = $self->{model}->get_pkgname_for_path($ports->{$_}->{fullpkgpath});
		my $pkgname = $ports->{$_}->{fullpkgname};
		$labels{$_} = $pkgname . " " x (45 - length($pkgname)) . $ports->{$_}->{comment};
		$labels{$_} = "<reverse>".$labels{$_}."</reverse>" if $self->{model}->pkg_is_installed($_);
	}
	$self->{wid}{ports_listbox}->labels(\%labels);
}

sub set_ports_listbox_selection
{
	# args: \@indexes
	my ($self, $indexes) = @_;
	$self->{wid}{ports_listbox}->set_selection(@{$indexes});
}

sub set_ports_listbox_title
{
	# args: $title
	my ($self, $title) = @_;
	$self->{wid}{ports_win}->title($title);
}

sub set_ports_descr_title
{
	# args: $title
	my ($self, $title) = @_;
	$self->{wid}{port_textviewer}->title($title);
}

sub port_entered
{
	my $self = shift;
	my $lb = shift;
	my $port = $lb->get_active_value();
	$self->{ctrl}->enter_port($port);
}

sub fill_port_descr
{
	my ($self, $portinfo, $installed) = @_;
	unless (defined $portinfo) {
		$self->{wid}{port_textviewer}->text("not found in sqlports");
		$self->show_msg("[left] back\t [q] quit");
		$self->{wid}{port_textviewer}->focus;
		return;
	}
	my $s = "Package name: $portinfo->{fullpkgname}";
	$s .= " (Installed, takes ".$portinfo->{size}.")" if defined $portinfo->{size};
	$s .= "\n\n".$portinfo->{comment}."\n\nMaintainer: ".$portinfo->{maintainer};
	$s .= "\nWWW: ".$portinfo->{homepage} if defined $portinfo->{homepage};
	$s .= "\n". "-" x 72;
	#tosee use text_wrap
	$s .= "\n".wrap('','', "Used by: ".$portinfo->{used_by}) if defined $portinfo->{used_by};
	$s .= "\n".wrap('','', "Library dependencies: ".$portinfo->{lib_depends}) if defined $portinfo->{lib_depends};
	$s .= "\n".wrap('','', "Runtime dependencies: ".$portinfo->{run_depends}) if defined $portinfo->{run_depends};
	$s .= "\n\n\n".$portinfo->{descr};
	$self->{wid}{port_textviewer}->text($s);
	$self->focus_portdescr();
}

sub port_select_changed
{
	my $self = shift;
	my $lb = $self->{wid}{ports_listbox};
	my $cur = $lb->get_active_value;
	# eq needed for exact match, grep is greedy otherwise
	my $add = grep $_ eq $cur, $lb->get;
	$self->{ctrl}->port_select_changed($cur, $add);
	# focus next XXX can have a weird behaviour
	$lb->option_next;
#	$self->{wid}{ports_win}->focus;
}

sub show_searchbox
{
	my $self = shift;
	my $req = $self->{wid}{cui}->question("Enter search term (will match package name and comment):");
	return unless defined $req;
	$self->{wid}{cui}->status("Searching ports for keyword \"$req\"");
	$self->{ctrl}->search_ports($req);
}

sub apply_changes
{
	my ($self, $really) = @_;
	my $yes = 1;
	my $nb = $self->{ctrl}->prepare_changes();
	if ($really && $<) {
		$self->{wid}{cui}->error("Not running as root, only doing a simulation");
		$really = 0;
	}
	unless ($nb) {
		$self->{wid}{cui}->error(-title => "Wtf ?", -message => "No packages to install/remove ??");
		$self->focus_portslist();
		return;
	}
	if ($really) {
		$yes = $self->{wid}{cui}->dialog(
			-message => "Ready to apply changes on $nb packages ?",
			-buttons => ['yes','no'],
			-values  => [1,0]);
	}
	if ($yes) {
		my $r = $self->{ctrl}->apply_changes($really);
#		todo : status() ?
		if ($r == 0) {
 			if ($really) {
				$self->{wid}{cui}->status("Updating installed/orphaned package list");
				$self->{ctrl}->finish_changes();
				$self->{ctrl}->enter_category(-1);
			}
		} else {
			$self->{wid}{cui}->error(
				-title => "Something failed..",
				-message => "previous command returned $r");
		}
	}
	# back to previous
	$self->focus_portslist();
}
sub update_all
{
	my $self = shift;
	my $yes = 1;
	my $really = 1;
	if ($<) {
		$self->{wid}{cui}->error("Not running as root, only doing a simulation");
		$really = 0;
	}
	if ($really) {
		my $yes = $self->{wid}{cui}->dialog(
			-message => "Ready to update all packages ?",
			-buttons => ['yes','no'],
			-values  => [1,0]);
	}
	if ($yes) {
		my $r = $self->{ctrl}->update_all($really);
#		todo : status() ?
		if ($r == 0) {
			$self->{wid}{cui}->status("Updating installed/orphaned package list");
			$self->{ctrl}->finish_changes();
			$self->{ctrl}->enter_category(-1);
		} else {
			$self->{wid}{cui}->error(
				-title => "Something failed..",
				-message => "previous command returned $r");
		}
	}
	# back to previous
	$self->focus_portslist();
}

# OpenBSD::State methods
# overriden from OpenBSD::Error
sub log
{
	my $self = shift;
# needed because of $state->log->dump calls
	return $self if (@_ == 0);
# context_messages is a hash with pkgname as key containing arrays of strings for pkg/MESSAGE content
	push(@{$self->{context_messages}->{$self->{current_context}}}, join('', $self->f(@_)));
}

# overriden from OpenBSD::Error
# called in the end of a pkg operation
# to dump context_messages containing MESSAGE
# add eventual error messages
# require confirmation from the user
sub dump
{
	#XXX check if errmessages is used in pkg_add's dump() someday
	my $self = shift;
	main::debug("dump");
	# keep track on how many message lines we have
	my $nl = 2;
	my @longest_lines;
	for my $pkg (sort keys %{$self->{context_messages}}) {
		my $msgs = $self->{context_messages}->{$pkg};
#		print "message for $pkg is @$msgs\n";
		if (@$msgs > 0) {
			$self->{delayed_messages} .= "--- $pkg -------------------\n";
			$self->{delayed_messages} .= join ("\n", @$msgs)."\n\n";
			$nl += 3 + @$msgs;
			push @longest_lines, max (map { length $_} @$msgs);
		}
	}
	if (!$self->{delayed_messages}) {
		$self->{context_messages} = {};
		return;
	}
	my $dialog = $self->{wid}{main_win}->add(
		'msg_dialog',
		'Window',
		-ipad => 1,
		-width => 8 + max (72, min(100, max(@longest_lines))), #8 for borders around TextViewer
		-border => 1,
		-centered => 1,
		-height => 6 + min ($nl,25),
		-title => 'PkgTools MESSAGES');

	$dialog->add (
		'message',
		'TextViewer',
		-focusable => 1,
		-border => 1,
		-height => min ($nl,25),
		-vscrollbar => 1,
		-wrapping => 1,
		-text => $self->{delayed_messages});

	my $b = $dialog->add(
		'buttons', 'Buttonbox',
		-buttonalignment => 'right',
		-y => -1);

	$b->set_routine( 'press-button', sub { 
		my $this = shift;
		$this->parent->loose_focus();
	});
	$b->focus();
	$dialog->modalfocus();

	$self->{wid}{main_win}->delete('msg_dialog');
	$self->{wid}{cui}->root->focus(undef, 1);

	# now we can ditch old messages
	$self->{delayed_messages} = "";
	$self->{context_messages} = {};
}

# overriden from OpenBSD::Error
sub set_context
{
	my $self = shift;
	my $pkgname = shift;
	if (!defined $self->{context_messages}->{$pkgname}) {
		$self->{context_messages}->{$pkgname} = [];
	}
	$self->{current_context} = $pkgname;
	main::debug("set_context:$pkgname");
}

# overriden from OpenBSD::Interactive
# ask for confirmation (y/n/a)
sub confirm
{
	my ($self, $prompt, $default) = @_;
	my $result;
	main::debug("confirm0:$prompt");
	if (defined $self->{messages_to_confirm}) {
		$prompt = "@{$self->{messages_to_confirm}}$prompt";
		undef @{$self->{messages_to_confirm}};
	}
	main::debug("confirm:$prompt");
	if ($self->{always_confirm}) {
		return 1;
	}
	# XXX handle default selected button
	$result = $self->{wid}{cui}->dialog(
		-message => $prompt,
		-buttons => ['yes','no',{ -label => '< always >', -shortcut => 'a'}],
		-values  => [1,0,2]);

	if ($result == 2) {
		$self->{always_confirm} = 1;
		return 1;
	}
	return $result;
#XXX	return $default;
}

sub ask_list
{
	my ($self, $prompt, $interactive, @values) = @_;
	# compute needed width/height
	my $longest_line = max (map { length $_} @values);
	my %labels;
	my $i = 0;
	map { $labels{$i} = $_; $i++} @values;
	my $dialog = $self->{wid}{main_win}->add(
		'ask_dialog',
		'Window',
		-ipad => 1,
		-width => max(10 + $longest_line, 40),
		-border => 1,
		-centered => 1,
		-height => 13 + $#values,
		-title => 'Make a choice');

	$dialog->add (
		'message',
		'TextViewer',
		-focusable => 0,
		-height => 2,
		-wrapping => 1,
		-text => $prompt);

	my $radio = $dialog->add(
		'radios',
		'Radiobuttonbox',
		-y => 3,
		-border => 1,
		-height => 3 + $#values,
		-selected => 0,
		-values => [ 0..$#values ],
		-labels => \%labels,
	);

	my $b = $dialog->add(
		'buttons', 'Buttonbox',
		-buttonalignment => 'right',
		-y => -1);

	$b->set_routine( 'press-button', sub { 
		my $this = shift;
		$this->parent->loose_focus();
	});
	$b->focus();
	$dialog->modalfocus();

	my $r = $radio->get();
	# get return code
	$self->{wid}{main_win}->delete('ask_dialog');
	$self->{wid}{cui}->root->focus(undef, 1);
	# return the selected pkgname
	return $labels{$r};
}

# called when multiple packages/flavors can match
#supposed to return a value within $list, not an index
sub choose_location
{
	#$list is an array of PackageLocation
	my ($self, $name, $list, $is_quirks) = @_;
	if (@$list == 0) {
		$self->errsay("Can't find #1", $name) unless $is_quirks;
		return undef;
	} elsif (@$list == 1) {
		return $list->[0];
	}

	my %h = map {($_->name, $_)} @$list;
	$h{'<None>'} = undef;
	# real implem in ask_list
	my $r = $self->ask_list("Alternatives for $name", $self->{interactive},  sort keys %h);
	return $h{$r};
}

# copied from OpenBSD/State.pm, formats parameters/placeholders
sub f
{
	my $self = shift;
	if (@_ == 0) {
		return undef;
	}
	my ($fmt, @l) = @_;
	# make it so that #0 is #
	unshift(@l, '#');
	$fmt =~ s,\#(\d+),($l[$1] // "<Undefined #$1>"),ge;
	return $fmt;
}

sub fatal
{
	my $self = shift;
	main::debug("curses:fatal:@_");
	croak "fatal!";
}

sub errprint
{
	my $self = shift;
	main::debug("curses:errprint:@_");
}

sub print
{
	my $self = shift;
	main::debug("curses:print:@_");
}

sub say
{
	my $self = shift;
	main::debug("Curses->say:".$self->f(@_));
	# Catch package deletion with pkg depending on it messages
	# TODO: catch error messages
	if ("@_" =~ /Can't/) {
		push @{$self->{messages_to_confirm}}, join('',$self->f(@_))."\n";
	} else {
		#XXX use f() ?
		$self->progress->next($self->f(@_));
	}
}

sub system
{
	my $self = shift;
	$self->{ctrl}->pkg->{install}->{state}->system(@_);
}

sub errsay
{
	my $self = shift;
	main::debug("Curses->errsay:".$self->f(@_));
	# if msg related to pkg update @execs
	if ("@_" =~ /(can't delete.*without|New|Old|\+ |\- \|.*\@exec)/) {
		push @{$self->{messages_to_confirm}}, join('',$self->f(@_))."\n"
	} else {
		push(@{$self->{context_messages}->{'errors'}}, join('', $self->f(@_)));
	}
}

sub start
{
	my $self = shift;
	$self->gui_init() unless defined shift;
}

sub gui_init
{
	my $self = shift;
	$self->{wid}{cui} = new Curses::UI(
		-clear_on_exit => 1,
#		-debug => 1,
		-color_support => 1);
	$self->{wid}{main_win} = $self->{wid}{cui}->add(
		'main_win', 'Window',
		-title => $self->{name},
		-titlereverse => 0,
		-border => 1);

	$self->{wid}{categories_win} = $self->{wid}{main_win}->add(
		'categories_win', 'Window',
		-padbottom => 2,
		-titlereverse => 0,
		-title => "categories",
		-border => 1);

	my $v = $self->{model}->get_categories;
	$self->{wid}{categories_listbox} = $self->{wid}{categories_win}->add(
		'categories_listbox', 'Listbox',
		-values => [sort { $v->{$a} cmp $v->{$b} } keys %$v],
		-labels => $v,
		-onchange => sub { $self->show_category });

	$self->{wid}{ports_win} = $self->{wid}{main_win}->add(
		'ports_win', 'Window',
		-padbottom => 2,
		-titlereverse => 0,
		-border => 1);

	$self->{wid}{ports_listbox} = $self->{wid}{ports_win}->add(
		'ports_listbox', 'Listbox',
		-onchange => sub { $self->port_select_changed },
		-values => [], # needed because otherwise first item
		-labels => {}, # is selected upon first fill
		-multi => 1);

	$self->{wid}{help_textviewer} = $self->{wid}{main_win}->add(
		'help_textviewer', 'TextViewer',
		-padtop => ($self->{wid}{main_win}->height - 4),
		-text => "Welcome to ".$self->{name}."\n");

	$self->{wid}{port_textviewer} = $self->{wid}{main_win}->add(
		'portviewer', 'TextViewer',
		-padbottom => 2,
#		-htmltext => 1,
		-titlereverse => 0,
		-border => 1);

	# set keybindings
	$self->{wid}{ports_listbox}->set_binding( sub { $self->focus_categories }, KEY_LEFT());
	$self->{wid}{ports_listbox}->set_binding( sub { $self->port_entered(shift) }, (KEY_RIGHT(), KEY_ENTER()));
	$self->{wid}{ports_listbox}->set_binding( sub { $self->apply_changes(1) }, "a");
	$self->{wid}{ports_listbox}->set_binding( sub { $self->apply_changes(0) }, "s");
	$self->{wid}{port_textviewer}->set_binding( sub { $self->focus_portslist }, KEY_LEFT());
	$self->{wid}{categories_listbox}->set_binding( sub { $self->show_category }, KEY_RIGHT());
	$self->{wid}{categories_listbox}->set_binding( sub { $self->show_searchbox }, "s");
	$self->{wid}{categories_listbox}->set_binding( sub { $self->update_all }, "u");
	$self->{wid}{cui}->set_binding( sub { exit}, "q");
	$self->focus_categories;
	$self->{wid}{cui}->mainloop();
}

# used to override the methods from OpenBSD::ProgressMeter
package OpenBSD::PackageManager::CursesProgressMeter;
use OpenBSD::ProgressMeter::Term;
our @ISA=(qw(OpenBSD::ProgressMeter::Real));

sub new
{
	my $class = shift;
	my $self = bless {}, $class;
	$self->{view} = shift;
	$self->{state} = $self->{view}->{ctrl}->pkg->{install}->{state};
	main::debug("CursesProgressMeter: new");
	$self->setup;
	return $self;
}

sub setup
{
	my $self = shift;
	# called normally with -x and -m
	main::debug("progress:setup");
	$self->{dialog} = $self->{view}->{wid}{main_win}->add(
		'progressdialog', 'Dialog::Progress',
		-max => 100,
		-title => 'Work in progress...',
		);
}

sub set_title
{
	my ($self, $title) = @_;
	main::debug("progress:set_title:$title");
	$self->{dialog}->title($title);
}

sub set_header
{
	my ($self, $header) = @_;
	main::debug("progress:set_header:$header");
	$self->{dialog}->message($header);
	$self->{dialog}->draw();
}

# update percentage
sub show
{
	my ($self, $current, $total) = @_;
	$self->{dialog}->pos(100*$current/$total);
	main::debug("progress:show:$current/$total");
	$self->{dialog}->draw();
}

sub message
{
	my ($self, $message) = @_;
	$self->{dialog}->message($message) unless ($message eq "reading plist");
	main::debug("progress:message:$message");
}

sub clear
{
	my $self = shift;
	main::debug("progress:clear");
#	sleep (1);
#	$self->{view}->{wid}{main_win}->delete('progressdialog');
}

# called after a package is installed to move on to the next
sub next
{
	my $self = shift;
	main::debug("progress:next:@_");
	$self->{dialog}->message(@_);
	$self->{dialog}->draw();
}
1;
