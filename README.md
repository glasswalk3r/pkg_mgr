# pkg_mgr

This project is a fork from the original pkg_mgr project developed by Landry
Breuil (landry at openbsd dot org) and currently hosted at
https://rhaalovely.net/pkg_mgr/.

`pkg_mgr` is a user-friendly tool written in Perl which allows you to manage
installed packages, browse available packages by categories, and finally
install/uninstall/update packages.

It has its roots in pkg_select, and takes some ideas too from FreeBSD's
sysinstall.

## State of the project

The project is it's initial state, basically a copy from the original files.

## Roadmap

* Create a Perl module from the project, so it can be installed directly from
CPAN.
* Add unit testing, to allow any refactoring that comes up. This might also
help solving the bugs mentioned by Landry.
* Release to CPAN.
* Check if it is possible to have the application officially packaged again to
the OpenBSD core.

There is not intention to port this program to GTK or any type of GUI. This
project will stick to ncurses (or anything that can run in a shell).

## Features

- browse categories
- browse ports by categories
- show information about ports
- select multiple ports to install/remove
- show installed/orphaned packages, apply or simulate changes.
- search for ports based on `fullpkgname` or comment. Ports-tree is not needed
at the moment.

## OpenBSD packages dependencies

- sqlports-compact
- p5-Curses-UI
- p5-DBD-SQLite

## Debugging

```
$ pkg_add p5-Term-ReadLine-GNU
$ perldoc perldebug
```

in term A:
```
$ tty>/tmp/tty && sleep 10000
```

in term B:
```
$ PERLDB_OPTS=TTY=`cat /tmp/tty` perl -d `which pkg_mgr`
```
