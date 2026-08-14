# GIM - Godot engine Install Manager

[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](LICENSE)

> A bash script to mange and launch Godot editors on Linux

GIM simplifies the process of managing (downloading/removing) Godot engine versions
and allows you to launch versions from a single place.

## Project

GIM uses [Argbash](https://github.com/matejak/argbash) for CLI argument support.
Install it for your distro or build it locally to start using it with GIM.

## Platform support

Currently, only Linux is supported, and only Archlinux is tested.

## Directory Structure

GIM follows [XDG Base Directory](https://specifications.freedesktop.org/basedir-spec/latest/) conventions:

| Location                          | Purpose                                         |
| --------------------------------- | ----------------------------------------------- |
| `~/.local/share/gim/editors/`     | Your installed editor versions are stored here  |
