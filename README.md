# owssh - OpsWorks SSH Tool

## Description

Script for quickly getting information about all or specific OpsWorks stacks and SSH'ing OpsWorks instances.

## Installation

  $ gem install owssh

## Usage

  $ owssh

This will display help and options for owssh

  $ owssh list

This displays all stacks available

  $ owssh describe

Shows details of instances in all stacks

  $ owssh describe [stack]

Shows details of a specific stack

  $ owssh [stack] [instance]

SSH to a specific instance in a stack

### License

owssh is released under the Apache 2.0 license. See the [LICENSE](LICENSE) file for details.

Specific components of fleet use code derivative from software distributed under other licenses; in those cases the appropriate licenses are stipulated alongside the code.
